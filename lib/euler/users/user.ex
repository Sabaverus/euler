defmodule Euler.Users.User do
  @moduledoc false

  defstruct name: nil, role: nil

  def guest() do
    new()
    |> Map.put(:name, "Guest")
    |> Map.put(:role, :guest)
  end

  def new() do
    %__MODULE__{}
  end
end
