defmodule Euler.IpBan do
  @moduledoc """
  Модуль реализующий список заблокированных адресов
  Основная концепция заключается в том, что модуль выступает в роли
  master сервера для контроля списка заблокированных адресов в хранилище Redis

  Флаг о том, что IP адрес заблокирован хранится битом в Bitset размерностью 256^4

  ### Использование модуля
  #### Добавление в список блокировки `ban/2`

      iex> Euler.IpBan.ban("1.1.1.1", DateTime.utc_now() |> DateTime.add(1, :hour))
      :ok

  Принцип работы:
    * Устанавливается флаг блокировки в стейте процесса посредством выставления
      бита адреса на 1
    * IP адрес и unix время окончания блокировки отправляется в хранилище Redis
    * Отправляется оповещение в pubsub топик Redis о том, что адрес был добавлен
    * Запускается локальный таймер на оповещение того, что блокировка закончилась

  #### Проверка блокировки адреса `banned?/1`

      iex> Euler.IpBan.ban("1.1.1.1", DateTime.utc_now() |> DateTime.add(1, :hour))
      :ok
      iex> Euler.IpBan.banned?("1.1.1.1")
      true

  Принцип работы:
    * В хранилище стейта проверяется бит адреса на == 1

  #### Удаление блокировки адреса `remove/1`

      iex> Euler.IpBan.remove("1.1.1.1")
      :ok

  Принцип работы:
    * В стейте процесса устанавливается бит адреса на 0
    * Из Redis удаляется IP адрес из хранилища
    * Отправляется оповещение в pubsub топик Redis о том, что адрес был разблокирован
    * Отменяются локальные таймеры на оповещение того, что блокировка закончилась

  """

  #
  @redis_server :redix
  @pubsub :redix_pubsub

  @service_channel "ban_list"
  @ip_list "ban_list"

  @max_ip_count 4_294_967_296
  @timer_period 600

  use GenServer

  @type state :: %{
    connection: pid | atom, # Redis connection
    pubsub: pid, # Redis pubsub
    list: Bitset.t() # local storage of banned ip's presented as bitset
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
      |> Map.put(:list, Bitset.new(@max_ip_count))

    # Загружается список забаненых адресов
    initializated =
      Enum.reduce(storage, state, fn json, state ->
        el = Jason.decode!(json, keys: :atoms)
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

  @spec ban({integer, integer, integer, integer}, DateTime.t) :: :ok
  @doc """
    Accepts IPv4 address as tuple and time_to as DateTime

    Push given IP to Redis banned ip collection

    iex> Euler.IpBan.ban({127,0,0,1}, DateTime.utc_now() |> DateTime.add(30, :second))
    :ok
  """
  def ban(ip, time_to) do
    GenServer.cast(__MODULE__, {:ban, ip, time_to})
  end

  @spec banned?(String.t()) :: boolean
  @doc """
    Checks for flag IP banned or not

        iex> Euler.IpBan.banned?("127.0.0.1")
        false
  """
  def banned?(ip) do
    GenServer.call(__MODULE__, {:check_ip, ip})
  end

  @spec remove(String.t()) :: any
  def remove(ip) do
    GenServer.cast(__MODULE__, {:remove, ip})
  end

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
        [Jason.decode!(el, keys: :atoms) | acc]
      end)
      |> Enum.reverse()

    {:reply, list, state}
  end

  def handle_call({:check_ip, ip_raw}, _from, state) do
    {:ok, ip} = IP.Address.from_string(ip_raw)
    ip_numeric = IP.Address.to_integer(ip)

    {:reply, is_address_banned?(state.list, ip_numeric), state}
  end

  # TODO non tuple pattern matching
  def handle_cast({:ban, ip, time_to}, state) do

    {ip_address, new_state} = ban_ip(ip, time_to, state)
    {:ok, _} =
      redis_add(
        state.connection,
        IP.Address.to_integer(ip_address), # Score
        Jason.encode!(%{ip: IP.Address.to_string(ip_address), time: DateTime.to_unix(time_to)})
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

  def handle_info({:redix_pubsub, _from, _ref, :message, %{channel: @service_channel, payload: payload}}, state) do
    {:noreply, handle_sub(Jason.decode!(payload, keys: :atoms), state)}
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
  defp ban_ip(%IP.Address{} = ip, %DateTime{} = time_to, state) do

    ip_numeric = IP.Address.to_integer(ip)
    ip_raw = IP.Address.to_string(ip)

    diff = DateTime.diff(time_to, DateTime.utc_now())

    # Caching ip addredd as banned
    new_list = Bitset.set(state.list, ip_numeric)

    # If remaining time is smaller what timer_period start timer
    new_timers =
      if diff <= @timer_period do
        # Update timer if exists
        if Map.has_key?(state.timers, ip_numeric) do
          Process.cancel_timer(Map.get(state.timers, ip_numeric))
        end
        Map.put(state.timers, ip_numeric, Process.send_after(__MODULE__, {:remove, ip_raw}, diff * 1000))
      else
        state.timers
      end

    {
      ip,
      state
      |> Map.put(:timers, new_timers)
      |> Map.put(:list, new_list)
    }
  end

  defp remove_ban(ip_raw, state) when is_binary(ip_raw) do
    {:ok, ip} = IP.Address.from_string(ip_raw)
    remove_ban(ip, state)
  end
  defp remove_ban(%IP.Address{} = ip, state) do

    ip_numeric = IP.Address.to_integer(ip)

    new_timers =
      if Map.has_key?(state.timers, ip_numeric) do
        Process.cancel_timer(Map.get(state.timers, ip_numeric))
        Map.delete(state.timers, ip_numeric)
      else
        state.timers
      end

    new_list = Bitset.set(state.list, ip_numeric, 0)

    {
      ip,
      state
      |> Map.put(:timers, new_timers)
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
    state
  end

  # Adds given ip address to redis collection and broadcasting this event to all redis-subscribers
  defp redis_add(conn, score, ip) do
    Redix.pipeline(
      conn,
      [
        ["ZADD", @ip_list, score, ip],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :added, data: ip})]
      ]
    )
  end

  defp redis_remove(conn, data) do
    Redix.pipeline(
      conn,
      [
        ["ZREM", @ip_list, data],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :removed, data: data})]
      ]
    )
  end

  defp redis_remove(conn, score, ip_raw) do
    Redix.pipeline(
      conn,
      [
        ["ZREMRANGEBYSCORE", @ip_list, score, score],
        ["PUBLISH", @ip_list, Jason.encode!(%{type: :removed, data: %{ip: ip_raw}})]
      ]
    )
  end

  # Копия функции test? из модуля Bitset с исправленной проверкой бита
  defp is_address_banned?(%{data: data}, pos) do
    <<_prefix::size(pos), bit::size(1), _rest::bits>> = data
    bit == 1
  end
end
