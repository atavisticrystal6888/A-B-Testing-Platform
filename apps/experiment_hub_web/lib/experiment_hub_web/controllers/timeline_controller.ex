defmodule ExperimentHubWeb.TimelineController do
  @moduledoc """
  Serves experiment timeline data to the dashboard: audit-log lifecycle
  events (create/start/pause/resume/conclude) and daily exposure
  (assignment) counts, for plotting alongside the experiment's run window.
  """
  use ExperimentHubWeb, :controller

  import Ecto.Query

  alias ExperimentHub.AuditLog
  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.{Experiments, Repo}

  # Audit action vocabulary the codebase actually writes: the API controller
  # (ExperimentController) writes past-tense actions ("started", "paused",
  # "resumed", "concluded"); Oban workers (ScheduledStartWorker,
  # ExperimentScheduler) write "scheduled_start" for time-driven starts. The
  # present-tense forms ("start", "pause", ...) are also accepted for
  # safety/back-compat (e.g. hand-seeded fixtures), then normalized below so
  # the dashboard only ever sees one canonical spelling per lifecycle stage.
  #
  # Deliberately no "scheduled_end" entry: ScheduledEndWorker (and
  # ExperimentScheduler's auto-conclude path) call
  # ConclusionService.conclude/2, which already writes its own "concluded"
  # audit row, then separately log a second row tagged "scheduled_end" for
  # the same transition. Mapping both would show two "Concluded" markers on
  # the timeline for one event, so "scheduled_end" is left unmapped and
  # filtered out by the `Enum.filter` below instead of being normalized.
  @normalized_action %{
    "create" => "created",
    "created" => "created",
    "start" => "started",
    "started" => "started",
    "scheduled_start" => "started",
    "pause" => "paused",
    "paused" => "paused",
    "resume" => "resumed",
    "resumed" => "resumed",
    "conclude" => "concluded",
    "concluded" => "concluded"
  }

  @doc """
  GET /api/v1/experiments/:experiment_id/timeline
  """
  def show(conn, %{"experiment_id" => experiment_id}) do
    case Experiments.get_experiment(experiment_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        conn
        |> put_status(200)
        |> json(%{
          data: %{
            lifecycle: lifecycle(experiment),
            daily_exposures: daily_exposures(experiment)
          }
        })
    end
  end

  defp lifecycle(experiment) do
    # Filter to the lifecycle action vocabulary in the query itself, not
    # after Repo.all/1 — otherwise the 1000-row cap below is spent on
    # whatever mix of audit entries a busy experiment has accumulated
    # (metric attach/detach, flag evaluations logged elsewhere, etc.), and a
    # real lifecycle row can be silently pushed out before Enum.filter ever
    # sees it.
    "experiment"
    |> AuditLog.list_for_resource(experiment.id,
      limit: 1000,
      actions: Map.keys(@normalized_action)
    )
    |> Enum.filter(&Map.has_key?(@normalized_action, &1.action))
    |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
    |> Enum.map(fn log ->
      %{
        action: Map.fetch!(@normalized_action, log.action),
        at: DateTime.to_iso8601(log.inserted_at),
        actor_type: log.actor_type,
        reason: log.reason
      }
    end)
  end

  defp daily_exposures(experiment) do
    from(a in Assignment,
      where: a.experiment_id == ^experiment.id,
      group_by: fragment("date(?)", a.assigned_at),
      order_by: fragment("date(?)", a.assigned_at),
      select: %{date: fragment("date(?)", a.assigned_at), count: count(a.id)}
    )
    |> Repo.all()
    |> Enum.map(fn %{date: date, count: count} ->
      %{date: Date.to_iso8601(date), count: count}
    end)
  end
end
