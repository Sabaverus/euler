defmodule Euler.Repo do
  use Ecto.Repo,
    otp_app: :euler,
    adapter: Ecto.Adapters.Postgres
end
