defmodule EulerWeb.PanelController do
  use EulerWeb, :controller

  alias Euler.Services.Inn, as: Inn
  alias Euler.Services.Inn.History, as: History
  alias Euler.Users.User, as: User

  def banned(conn, params) do
    user = Map.get(conn.assigns, :current_user)

    if User.is_admin?(user) do
      limit = 20

      {page, offset_page} = get_pagination(params)

      banned_list = Euler.BlockList.list(from: offset_page * limit, to: offset_page + limit)

      render(conn, "banned_list.html", banned_list: banned_list, page: page)
    else
      conn
      |> put_flash(:error, "Not enough permissions to view this page")
      |> redirect(to: "/")
    end
  end

  def checks(conn, params) do
    user = Map.get(conn.assigns, :current_user)

    if User.is_admin?(user) or User.is_operator?(user) do
      {page, offset_page} = get_pagination(params)
      limit = 20
      offset = limit * offset_page

      render(conn, "checks_history.html",
        checks_list: Inn.checks_history(limit: limit, offset: offset),
        page: page
      )
    else
      conn
      |> put_flash(:error, "Not enough permissions to view this page")
      |> redirect(to: "/")
    end
  end

  def inn_history_action(conn, %{"delete" => history_id}) do
    user = Map.get(conn.assigns, :current_user)

    with true <- User.is_operator?(user) or User.is_admin?(user),
         {id, _} <- Integer.parse(history_id),
         entry <- History.get(id) do
      History.delete(entry)

      conn
      |> put_flash(:info, "Record has been deleted")
      |> redirect(to: Routes.panel_path(conn, :checks))
    else
      nil ->
        conn
        |> put_flash(:error, "Record not found")
        |> redirect(to: Routes.panel_path(conn, :checks))

      :error ->
        conn
        |> put_flash(:error, "Invalid parameter")
        |> redirect(to: Routes.panel_path(conn, :checks))

      false ->
        conn
        |> put_flash(:error, "Not enough permissions")
        |> redirect(to: "/")
    end
  end

  def inn_history_action(conn, _params) do
    conn
    |> put_flash(:error, "Undefined action")
    |> redirect(to: Routes.panel_path(conn, :checks))
  end

  @spec allowed_ban_periods :: Keyword.t()
  def allowed_ban_periods() do
    [
      "1 min": 60,
      "5 min": 60 * 5,
      "30 min": 60 * 30,
      "1 hour": 60 * 60,
      "1 day": 60 * 60 * 24
    ]
  end

  def ban_list_action(conn, %{"ban_ip" => ip, "period" => period}) do
    user = Map.get(conn.assigns, :current_user)

    with {period_seconds, _} <- Integer.parse(period),
         true <- User.is_admin?(user) do
      :ok = Euler.BlockList.ban(ip, DateTime.utc_now() |> DateTime.add(period_seconds, :second))

      conn
      |> put_flash(:info, "IP #{ip} was banned")
      |> redirect(to: Routes.panel_path(conn, :banned))
    else
      :error ->
        conn
        |> put_flash(:error, "Invalid parameter")
        |> redirect(to: Routes.panel_path(conn, :checks))

      false ->
        conn
        |> put_flash(:error, "Not enough permissions")
        |> redirect(to: "/")
    end
  end

  def ban_list_action(conn, %{"remove" => ip}) do
    user = Map.get(conn.assigns, :current_user)

    with :ok <- Euler.BlockList.remove(ip),
         true <- User.is_admin?(user) do
      conn
      |> put_flash(:info, "IP #{ip} ban was removed")
      |> redirect(to: Routes.panel_path(conn, :banned))
    else
      false ->
        conn
        |> put_flash(:error, "Not enough permissions")
        |> redirect(to: "/")
    end
  end

  def ban_list_action(conn, _params) do
    conn
    |> put_flash(:error, "Undefined action")
    |> redirect(to: Routes.panel_path(conn, :banned))
  end

  defp get_pagination(params) do
    page =
      case Map.get(params, "page", 0) do
        ps when is_bitstring(ps) ->
          case Integer.parse(ps) do
            {digit, _} -> digit
            :error -> 0
          end

        pn ->
          pn
      end

    offset_page =
      cond do
        page >= 2 ->
          page - 1

        page < 0 ->
          0

        page <= 1 ->
          0
      end

    {page, offset_page}
  end
end
