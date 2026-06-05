defmodule ExperimentHub.ObanConfig do
  @moduledoc """
  Oban configuration for PostgreSQL-backed job processing.
  """

  def child_spec(_opts) do
    config =
      [repo: ExperimentHub.Repo, queues: [default: 10, events: 20, analysis: 5, notifications: 5]]
      |> Keyword.merge(Application.get_env(:experiment_hub, Oban, []))

    Oban.child_spec(config)
  end
end
