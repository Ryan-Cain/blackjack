defmodule Blackjack.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlackjackWeb.Telemetry,
      Blackjack.Repo,
      {DNSCluster, query: Application.get_env(:blackjack, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Blackjack.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Blackjack.Finch},
      # Start a worker by calling: Blackjack.Worker.start_link(arg)
      # {Blackjack.Worker, arg},
      # Start to serve requests, typically the last entry
      BlackjackWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blackjack.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BlackjackWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
