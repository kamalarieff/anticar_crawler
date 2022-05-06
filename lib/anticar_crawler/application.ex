defmodule AnticarCrawler.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      AnticarCrawler.Repo,
      # Start the Telemetry supervisor
      AnticarCrawlerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: AnticarCrawler.PubSub},
      # Start the Endpoint (http/https)
      AnticarCrawlerWeb.Endpoint,
      # Start a worker by calling: AnticarCrawler.Worker.start_link(arg)
      # {AnticarCrawler.Worker, arg}
      PostState,
      CommentState,
      Reddit.Processor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AnticarCrawler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AnticarCrawlerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
