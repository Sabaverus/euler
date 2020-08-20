defmodule Euler.Services.Inn.History do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  @derive  {Jason.Encoder, only: [:inn, :result, :time]}

  schema "inn_check_history" do
    field :inn, :string
    field :ip_address, :string
    field :result, :boolean
    field :time, :utc_datetime_usec
  end

  @doc false
  def changeset(history, attrs) do
    history
    |> cast(attrs, [:ip_address, :time, :inn, :result])
    |> validate_required([:ip_address, :time, :inn, :result])
  end

  def inn(query, inn) do
    where(query, [entry], entry.inn == ^inn)
  end

  def count(query, limit \\ 10) do
    limit(query, ^limit)
  end

  def order_desc(query) do
    order_by(query, desc: :time)
  end

  def push(%__MODULE__{} = history) do
    Euler.Repo.insert(history)
  end
end
