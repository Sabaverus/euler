defmodule EulerWeb.PanelController do
  use EulerWeb, :controller

  alias Euler.Services.Inn, as: Inn

  def banned(conn, params) do
    limit = 20

    {page, offset_page} = get_pagination(params)

    banned_list = Euler.IpBan.list(from: offset_page * limit, to: offset_page + limit )

    render(conn, "banned_list.html", banned_list: banned_list, page: page)
  end

  def checks(conn, params) do

    {page, offset_page} = get_pagination(params)
    limit = 20
    offset = limit * offset_page

    render(conn, "checks_history.html", checks_list: Inn.checks_history(limit: limit, offset: offset), page: page)
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
