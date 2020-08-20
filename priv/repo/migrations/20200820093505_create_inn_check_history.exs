defmodule Euler.Repo.Migrations.CreateInnCheckHistory do
  use Ecto.Migration

  def change do
    create table(:inn_check_history) do
      add :ip_address, :string
      add :time, :utc_datetime_usec
      add :inn, :string
      add :result, :boolean
    end
  end
end
