defmodule ExperimentHub.Exports.JsonExporter do
  @moduledoc """
  JSON export for experiment results (FR-120).
  """

  @doc """
  Export full analysis results as JSON string.
  """
  def export(experiment, results, _opts \\ []) do
    data = %{
      experiment: %{
        id: experiment.id,
        key: experiment.key,
        name: experiment.name,
        status: experiment.status,
        hypothesis: experiment.hypothesis
      },
      results: results,
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, Jason.encode!(data, pretty: true)}
  end
end
