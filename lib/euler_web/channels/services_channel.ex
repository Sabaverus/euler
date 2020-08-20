defmodule EulerWeb.ServicesChannel do
  use Phoenix.Channel

  alias Euler.Services.Inn, as: Inn
  alias Euler.Services.Inn.History, as: History

  def join("services", _message, socket) do
    {:ok, socket}
  end

  def handle_in("services:inn-check", %{"inn" => inn}, socket) do

    time = DateTime.utc_now()
    ip_string =
      socket.assigns.connect_info.peer_data.address
      |> :inet.ntoa()
      |> to_string()

    status =
      case Inn.validate(inn) do
        {:correct, inn} ->
          History.push(%History{inn: inn.raw, ip_address: ip_string, time: time, result: true})
          true

        {:incorrect, inn, _error} ->
          History.push(%History{inn: inn, ip_address: ip_string, time: time, result: false})
          false

        {:invalid, _error} ->
          false
      end

    broadcast!(socket, "services:inn-check", %{
      result: %{inn: inn, time: time, result: status}
    })

    {:noreply, socket}
  end
end
