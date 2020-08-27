defmodule Euler.Users.User do
  @moduledoc false

  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    pow_user_fields()

    field :role, :integer

    timestamps()
  end

  @spec guest :: Euler.Users.User.t()
  def guest() do
    new()
    |> Map.put(:role, 3)
  end

  def new() do
    %__MODULE__{}
  end

  def roles() do
    [
      {1, "Admin", :admin},
      {2, "Operator", :operator},
      {3, "User", :common}
    ]
  end

  def role(%__MODULE__{} = user) do
    roles()
    |> Enum.find({-1, "Undefined", :undefined}, fn {role_id, _, _} ->
      user.role == role_id
    end)
  end

  def is_admin?(user) do
    {_, _, role} = role(user)
    role == :admin
  end

  def is_operator?(user) do
    {_, _, role} = role(user)
    role == :operator
  end
end
