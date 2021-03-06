defmodule Euler.Services.Inn.History do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  @derive {Jason.Encoder, only: [:inn, :result, :time]}

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

  def limit_offset(query, offset \\ 10) do
    offset(query, ^offset)
  end

  def order_desc(query) do
    order_by(query, desc: :time)
  end

  @spec push(bitstring(), bitstring(), boolean()) :: {:ok, __MODULE__.t()} | {:error, map()}
  def push(inn, ip, result) do
    time = DateTime.utc_now()

    push(%__MODULE__{
      time: time,
      inn: inn,
      ip_address: ip,
      result: result
    })
  end

  def get(id) do
    Euler.Repo.get(__MODULE__, id)
  end

  def delete(history) do
    Euler.Repo.delete(history)
  end

  def push(%__MODULE__{} = history) do
    Euler.Repo.insert(history)
  end
end
