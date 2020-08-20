defmodule EulerWeb.ServicesChannel do
  use Phoenix.Channel

  def join("services", _message, socket) do
    {:ok, socket}
  end

  def handle_in("services:inn-check", %{"inn" => inn}, socket) do

    time = DateTime.utc_now()

    status = case Euler.Services.Inn.validate(inn) do
      {:valid, _inn} ->
        # Add history
        # Count user request log
        true
      {:invalid, _message} ->
        # Count user request log
        false
    end

    broadcast!(socket, "services:inn-check", %{
      result: %{inn: inn, time: time, status: status}
    })

    {:noreply, socket}
  end
end
