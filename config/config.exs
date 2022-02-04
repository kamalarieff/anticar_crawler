# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :anticar_crawler,
  ecto_repos: [AnticarCrawler.Repo]

# Configures the endpoint
config :anticar_crawler, AnticarCrawlerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "84jxBudlf2JLYFuDlyb0gcV0MPPkjy8qNyYzh2/i08N93IbTEXaUkWqMn+8REvbQ",
  render_errors: [view: AnticarCrawlerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: AnticarCrawler.PubSub,
  live_view: [signing_salt: "9Q9YX9Vw"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
