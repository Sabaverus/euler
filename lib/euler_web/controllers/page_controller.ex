defmodule EulerWeb.PageController do
  use EulerWeb, :controller

  alias Euler.Services.Inn, as: Inn

  def index(conn, params) do
    history = Inn.checks_history()

    render(conn, "index.html", [params: params, history: history])
  end

  def inn_check(conn, %{inn: inn}) do
    inn = String.trim(inn)

    conn =
      case Inn.validate(inn) do
        {:correct, inn} ->
          put_flash(conn, :info, "ИНН #{Enum.join(inn)} корректный!")

        {:incorrect, inn, message} ->
          put_flash(conn, :info, "ИНН #{inn} некорректный! Причина: #{message}")

        {:invalid, message} ->
          put_flash(conn, :info, "ИНН #{inn} неправильный! Причина: #{message}")
      end

    redirect(conn, to: "/")
  end

  def inn_check(conn, _params) do
    render(conn, "index.html", history: Inn.checks_history())
  end
end
