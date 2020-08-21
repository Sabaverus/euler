defmodule EulerWeb.PageController do
  use EulerWeb, :controller

  alias Euler.Services.Inn, as: Inn
  alias Euler.Services.Inn.History, as: History

  def index(conn, params) do
    history = Inn.checks_history()

    render(conn, "index.html", params: params, history: history)
  end

  def inn_check(conn, %{inn: inn}) do
    ip_string =
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()

    status =
      with parsed <- Inn.parse(inn),
           :ok <- Inn.check(parsed) do
        :ok
      else
        error -> error
      end

    conn =
      case status do
        :ok ->
          case History.push(inn, ip_string, true) do
            {:ok, _history} ->
              put_flash(conn, :info, "ИНН #{inn} корректный!")

            {:error, _changeset} ->
              put_flash(conn, :info, "Ошибка сервера")
          end

        {:error, %{type: :incorrect}} ->
          case History.push(inn, ip_string, false) do
            {:ok, _history} ->
              put_flash(conn, :info, "ИНН #{inn} некорректный!")

            {:error, _changeset} ->
              put_flash(conn, :info, "Ошибка сервера")
          end

        {:error, %{type: :invalid, message: message}} ->
          put_flash(conn, :info, "ИНН #{inn} неправильный! Причина: #{message}")
      end

    redirect(conn, to: "/")
  end

  def inn_check(conn, _params) do
    render(conn, "index.html", history: Inn.checks_history())
  end
end
