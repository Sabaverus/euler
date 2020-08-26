defmodule Euler.Users.User do
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
      {1, "Администратор", :admin},
      {2, "Оператор", :operator},
      {3, "Пользователь", :common}
    ]
  end

  def role(%__MODULE__{} = user) do
    roles()
    |> Enum.find({-1, "Undefined", :undefined}, fn {role_id, _, _} ->
      user.role == role_id
    end)
  end
end
