defmodule EulerWeb.ServicesChannel do
  @moduledoc false

  use Phoenix.Channel

  alias Euler.Services.Inn, as: Inn
  alias Euler.Services.Inn.History, as: History

  def join("services", _message, socket) do
    ip_string = get_client_ip(socket)
    Phoenix.PubSub.subscribe(Euler.PubSub, "ip:" <> ip_string)

    {:ok, socket}
  end

  def handle_in("services:inn-check", %{"inn" => inn}, socket) do
    ip_string = get_client_ip(socket)

    status =
      with false <- Euler.IpBan.banned?(ip_string),
           %Inn{} = parsed <- Inn.parse(inn),
           :ok <- Inn.check(parsed) do
        :ok
      else
        true ->
          {:error, :banned}

        error ->
          error
      end

    case status do
      :ok ->
        push_history(socket, inn, ip_string, true)

      {:error, %{type: :incorrect}} ->
        push_history(socket, inn, ip_string, false)

      {:error, :banned} ->
        broadcast!(socket, "services:inn-check", %{
          error: %{message: "Your IP address is blocked"}
        })

      {:error, _error} ->
        false
    end

    {:noreply, socket}
  end

  defp push_history(socket, inn, ip_string, result) do
    spawn(fn ->
      case History.push(inn, ip_string, result) do
        {:ok, %History{time: time}} ->
          broadcast!(socket, "services:inn-check", %{
            result: %{inn: inn, time: time, result: result}
          })

        {:error, _changeset} ->
          # TODO log error
          broadcast!(socket, "services:inn-check", %{
            error: %{message: "Error happened, please try again later"}
          })
      end
    end)
  end

  defp get_client_ip(socket) do
    socket.assigns.connect_info.peer_data.address
    |> :inet.ntoa()
    |> to_string()
  end
end
