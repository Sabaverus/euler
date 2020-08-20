defmodule EulerWeb.PageController do
  use EulerWeb, :controller

  def index(conn, params) do
    render(conn, "index.html", params: params)
  end

  def inn_check(conn, params) do
    if Map.has_key?(params, "inn") do
      inn = String.trim(Map.get(params, "inn", nil))

      conn =
        case Euler.Services.Inn.validate(inn) do
          {:valid, inn} ->
            put_flash(conn, :info, "ИНН #{Enum.join(inn)} корректный!")

          {:invalid, message} ->
            put_flash(conn, :info, "ИНН #{inn} некорректный! Причина: #{message}")
        end

      redirect(conn, to: "/")
    end

    render(conn, "index.html", params: params)
  end
end
