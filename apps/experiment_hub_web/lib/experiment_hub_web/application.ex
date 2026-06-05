defmodule ExperimentHubWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExperimentHubWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:experiment_hub_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExperimentHubWeb.PubSub},
      # Start a worker by calling: ExperimentHubWeb.Worker.start_link(arg)
      # {ExperimentHubWeb.Worker, arg},
      # Start to serve requests, typically the last entry
      ExperimentHubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExperimentHubWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExperimentHubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
