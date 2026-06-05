defmodule ExperimentHub.Experiments.Timeline do
  @moduledoc """
  Experiment timeline events (FR-150).
  Tracks key events throughout experiment lifecycle.
  """

  alias ExperimentHub.AuditLog

  @doc """
  Get the timeline for an experiment.
  Returns a chronological list of events.
  """
  def get_timeline(experiment_id) do
    AuditLog.list_for_resource("experiment", experiment_id, limit: 100)
    |> Enum.map(&format_timeline_event/1)
    |> Enum.sort_by(& &1.timestamp, {:asc, DateTime})
  end

  defp format_timeline_event(log) do
    %{
      id: log.id,
      type: log.action,
      timestamp: log.inserted_at,
      actor: %{
        id: log.actor_id,
        type: log.actor_type
      },
      details: log.changes,
      reason: log.reason
    }
  end
end
