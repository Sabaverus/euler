defmodule Euler.BlockList do
  @moduledoc """
  Модуль реализующий список заблокированных адресов
  Основная концепция заключается в том, что модуль выступает в роли
  master сервера для контроля списка заблокированных адресов в хранилище Redis

  Флаг о том, что IP адрес заблокирован является его наличие в локальном хранилище по ключу строкового представления IP адреса

  ### Использование модуля
  #### Добавление в список блокировки `ban/2`

      iex> Euler.BlockList.ban("1.1.1.1", DateTime.utc_now() |> DateTime.add(60 * 60, :second))
      :ok

  Принцип работы:
    * Устанавливается флаг блокировки в посредством сохранения адреса в локальный хешмап `state.list`
    * IP адрес и unix время окончания блокировки отправляется в хранилище Redis
    * Отправляется оповещение в pubsub топик Redis о том, что адрес был добавлен
    * Запускается локальный таймер на оповещение того, что блокировка закончилась

  #### Проверка блокировки адреса `banned?/1`

      iex> Euler.BlockList.ban("1.1.1.1", DateTime.utc_now() |> DateTime.add(60 * 60, :second))
      :ok
      iex> Euler.BlockList.banned?("1.1.1.1")
      true

  Принцип работы:
    * В хранилище стейта проверяется бит адреса на == 1

  #### Удаление блокировки адреса `remove/1`

      iex> Euler.BlockList.remove("1.1.1.1")
      :ok

  Принцип работы:
    * В стейте процесса даляется из хранилища IP адрес
    * Из Redis удаляется IP адрес из хранилища
    * Отправляется оповещение в pubsub топик Redis о том, что адрес был разблокирован
    * Отменяются локальные таймеры на оповещение того, что блокировка закончилась

  TODO: Make supervisor tree over this server and redix/redix.pubsub server
  """

  @redis_server :redix
  @pubsub :redix_pubsub

  @service_channel "ban_list"
  @ip_list "ban_list"

  use GenServer

  @type state :: %{
          # Redis connection
          connection: pid | atom,
          # Redis pubsub
          pubsub: pid,
          # local storage as hashmap
          list: map()
        }

  def init(_args) do
    {:ok, storage} = Redix.command(@redis_server, ["ZRANGE", @ip_list, 0, -1])

    {:ok, pubsub} = Redix.PubSub.start_link()
    Redix.PubSub.subscribe(pubsub, @service_channel)

    time_now_unix = DateTime.utc_now() |> DateTime.to_unix()

    state =
      %{}
      |> Map.put(:timers, %{})
      |> Map.put(:connection, @redis_server)
      |> Map.put(:pubsub, @pubsub)
      |> Map.put(:list, %{})

    # Loading in state records from redis
    initializated =
      Enum.reduce(storage, state, fn json, state ->
        el = decode_ban_entry(json)

        # Remove old entries
        if el.time < time_now_unix do
          redis_remove(@redis_server, json)
          state
        else
          {_, new_state} = ban_ip(el.ip, el.time, state)
          new_state
        end
      end)

    {:ok, initializated}
  end

  def start_link(_args) do
    GenServer.start_link(
      __MODULE__,
      [],
      name: __MODULE__
    )
  end

  @spec ban({integer, integer, integer, integer} | String.t(), DateTime.t()) :: :ok
  @doc """
    Accepts IPv4 address as tuple and time_to as DateTime

    Push given IP to Redis banned ip collection

        iex> Euler.BlockList.ban({127, 0, 0, 1}, DateTime.utc_now() |> DateTime.add(30, :second))
        :ok

        iex> Euler.BlockList.ban("127.0.0.1", DateTime.utc_now() |> DateTime.add(30, :second))
        :ok
  """
  def ban(ip, time_to) do
    GenServer.cast(__MODULE__, {:ban, ip, time_to})
  end

  @spec banned?(String.t()) :: boolean
  @doc """
    Checks for flag IP banned or not

        iex> Euler.BlockList.banned?("127.0.0.1")
        false
  """
  def banned?(ip) do
    GenServer.call(__MODULE__, {:check_ip, ip})
  end

  @spec remove(String.t()) :: :ok
  @doc """
  Adds async task to remove fiven IP address from banned list

      iex> Euler.BlockList.remove("127.0.0.1")
      :ok
  """
  def remove(ip) do
    GenServer.cast(__MODULE__, {:remove, ip})
  end

  @spec list(Keyword.t()) :: []
  @doc """
  Returns actual banned list from redis storage

      iex> Euler.BlockList.list()
      []

  Can accept parameters `:from` and `:to` to define left and right border of range selection
  """
  def list(args \\ []) do
    GenServer.call(__MODULE__, {:list, args})
  end

  ####################

  def handle_call({:list, args}, _from, state) do
    from = Keyword.get(args, :from, 0)
    to = Keyword.get(args, :to, -1)

    {:ok, redis_list} = Redix.command(state.connection, ["ZRANGE", @ip_list, from, to])

    list =
      redis_list
      |> Enum.reduce([], fn el, acc ->
        [decode_ban_entry(el) | acc]
      end)
      |> Enum.reverse()

    {:reply, list, state}
  end

  def handle_call({:check_ip, ip_raw}, _from, state) do
    {:reply, Map.has_key?(state.list, ip_raw), state}
  end

  # TODO non tuple pattern matching
  def handle_cast({:ban, ip, time_to}, state) do
    {ip_address, new_state} = ban_ip(ip, time_to, state)

    # TODO Catch errors
    {:ok, _} =
      redis_add(
        state.connection,
        # Score
        IP.Address.to_integer(ip_address),
        %{ip: IP.Address.to_string(ip_address), time: DateTime.to_unix(time_to)}
      )

    {:noreply, new_state}
  end

  def handle_cast({:remove, ip_raw}, state) do
    {ip, new_state} = remove_ban(ip_raw, state)

    redis_remove(
      state.connection,
      IP.Address.to_integer(ip),
      IP.Address.to_string(ip)
    )

    {:noreply, new_state}
  end

  def handle_info({:remove, ip_raw}, state) do
    {ip, new_state} = remove_ban(ip_raw, state)

    redis_remove(
      state.connection,
      IP.Address.to_integer(ip),
      IP.Address.to_string(ip)
    )

    {:noreply, new_state}
  end

  def handle_info(
        {:redix_pubsub, _from, _ref, :message, %{channel: @service_channel, payload: payload}},
        state
      ) do
    {:noreply, handle_sub(decode_ban_entry(payload), state)}
  end

  def handle_info(_, state) do
    # TODO log unexpected messages
    {:noreply, state}
  end

  ################################

  defp ban_ip({p1, p2, p3, p4}, time_to, state) do
    {:ok, ip} = IP.Address.from_binary(<<p1, p2, p3, p4>>)
    ban_ip(ip, time_to, state)
  end

  defp ban_ip(ip_raw, time_to, state) when is_binary(ip_raw) do
    {:ok, ip} = IP.Address.from_string(ip_raw)
    ban_ip(ip, time_to, state)
  end

  defp ban_ip(%IP.Address{} = ip, time_to, state) when is_integer(time_to) do
    {:ok, time} = DateTime.from_unix(time_to)
    ban_ip(ip, time, state)
  end

  # TODO ban request of exising IP address adds as new entry. Update existing entry?
  defp ban_ip(%IP.Address{} = ip, %DateTime{} = time_to, state) do
    ip_numeric = IP.Address.to_integer(ip)
    ip_raw = IP.Address.to_string(ip)

    diff = DateTime.diff(time_to, DateTime.utc_now())

    # Caching ip addredd as banned
    entry =
      Map.get(state.list, ip_raw, %{
        ip_numeric: ip_numeric,
        ip_raw: ip_raw,
        time_to: time_to,
        timer: nil
      })

    # Update timer if exists
    if Map.get(entry, :timer) do
      Process.cancel_timer(Map.get(entry, :timer))
    end

    timer = Process.send_after(__MODULE__, {:remove, ip_raw}, diff * 1000)

    {
      ip,
      # Save list to state
      Map.put(
        state,
        :list,
        # Save entry to list
        Map.put(
          state.list,
          ip_raw,
          # Save timer to entry
          Map.put(entry, :timer, timer)
        )
      )
    }
  end

  defp remove_ban(ip_raw, state) when is_binary(ip_raw) do
    {:ok, ip} = IP.Address.from_string(ip_raw)
    remove_ban(ip, state)
  end

  defp remove_ban(%IP.Address{} = ip, state) do
    ip_raw = IP.Address.to_string(ip)

    new_list =
      if Map.has_key?(state.list, ip_raw) do
        timer =
          Map.get(state.list, ip_raw)
          |> Map.get(:timer)

        if timer do
          Process.cancel_timer(timer)
        end

        Map.delete(state.list, ip_raw)
      else
        state.list
      end

    {
      ip,
      state
      |> Map.put(:list, new_list)
    }
  end

  defp handle_sub(%{type: "added", data: %{ip: ip_raw, time: time_to}}, state) do
    {_ip, new_state} = ban_ip(ip_raw, time_to, state)
    new_state
  end

  defp handle_sub(%{type: "removed", data: %{ip: ip_raw}}, state) do
    {_ip, new_state} = remove_ban(ip_raw, state)
    new_state
  end

  defp handle_sub(_, state) do
    # TODO log unhandled messages from pubsub redix topic
    state
  end

  # Adds given ip address to redis collection and broadcasting this event to all redis-subscribers
  defp redis_add(conn, score, ban_data) do
    Redix.pipeline(
      conn,
      [
        ["ZADD", @ip_list, score, Jason.encode!(ban_data)],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :added, data: ban_data})]
      ]
    )
  end

  defp redis_remove(conn, data) when is_bitstring(data) do
    Redix.pipeline(
      conn,
      [
        ["ZREM", @ip_list, data],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :removed, data: data})]
      ]
    )
  end

  defp redis_remove(conn, score, ip_raw) when is_bitstring(ip_raw) do
    Redix.pipeline(
      conn,
      [
        ["ZREMRANGEBYSCORE", @ip_list, score, score],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :removed, data: %{ip: ip_raw}})]
      ]
    )
  end

  # Returns decoded term of redis ban list entry
  defp decode_ban_entry(entry) when is_bitstring(entry) do
    Jason.decode!(entry, keys: :atoms)
  end
end
