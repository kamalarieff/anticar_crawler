defmodule AnticarCrawler.Repo do
  use Ecto.Repo,
    otp_app: :anticar_crawler,
    adapter: Ecto.Adapters.Postgres
end
