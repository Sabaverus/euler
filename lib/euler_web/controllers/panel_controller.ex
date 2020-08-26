defmodule EulerWeb.PanelController do
  use EulerWeb, :controller

  alias Euler.Services.Inn, as: Inn
  alias Euler.Users.User, as: User

  def banned(conn, params) do

    user = Map.get(conn.assigns, :current_user)
    {_, _, role} = User.role(user)

    unless role == :admin do
      conn
      |> put_flash(:error, "Not enough permissions to view this page")
      |> redirect(to: "/")
    else
      limit = 20

      {page, offset_page} = get_pagination(params)

      banned_list = Euler.IpBan.list(from: offset_page * limit, to: offset_page + limit )

      render(conn, "banned_list.html", banned_list: banned_list, page: page)
    end
  end

  def checks(conn, params) do

    user = Map.get(conn.assigns, :current_user)
    {_, _, role} = User.role(user)

    unless role == :operator or role == :admin do
      conn
      |> put_flash(:error, "Not enough permissions to view this page")
      |> redirect(to: "/")
    else
      {page, offset_page} = get_pagination(params)
      limit = 20
      offset = limit * offset_page

      render(conn, "checks_history.html", checks_list: Inn.checks_history(limit: limit, offset: offset), page: page)
    end
  end

  defp get_pagination(params) do
    page =
      case Map.get(params, "page", 0) do
        ps when is_bitstring(ps) ->
          case Integer.parse(ps) do
            {digit, _} -> digit
            :error -> 0
          end
        pn  ->
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
