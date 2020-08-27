defmodule EulerWeb.BlockListTest do
  use Euler.DataCase

  alias Euler.BlockList, as: BlockList

  @correct_ip "127.0.0.1"
  # @correct_ip_tuple {127, 0, 0, 1}

  test "ban/2 raw ip" do
    ban_date = DateTime.utc_now() |> DateTime.add(5)
    :ok = BlockList.ban(@correct_ip, ban_date)

    # Existing in BlockList local storage
    assert BlockList.banned?(@correct_ip)

    el =
      BlockList.list()
      |> Enum.find(nil, fn x ->
        x.ip == @correct_ip
      end)

    assert el
    assert el.ip == @correct_ip
    {:ok, date} = DateTime.from_unix(el.time)
    assert DateTime.compare(date, ban_date)
  end
end
