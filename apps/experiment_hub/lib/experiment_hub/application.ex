defmodule ExperimentHub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ExperimentHub.Repo,
        ExperimentHub.Redis
      ] ++ maybe_oban_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExperimentHub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_oban_children do
    if Application.get_env(:experiment_hub, :start_oban, true) do
      [ExperimentHub.ObanConfig]
    else
      []
    end
  end
end
