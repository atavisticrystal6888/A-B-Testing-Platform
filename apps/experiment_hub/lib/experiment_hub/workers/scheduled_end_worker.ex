defmodule ExperimentHub.Workers.ScheduledEndWorker do
  @moduledoc """
  Oban worker for auto-concluding experiments at scheduled_end_at (FR-100).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias ExperimentHub.{Repo, AuditLog}
  alias ExperimentHub.Experiments.{Experiment, ConclusionService}
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    from(e in Experiment,
      where: e.status == "running",
      where: not is_nil(e.scheduled_end_at),
      where: e.scheduled_end_at <= ^now
    )
    |> Repo.all()
    |> Enum.each(fn experiment ->
      case ConclusionService.conclude(experiment.id, conclusion_reason: "scheduled_end") do
        {:ok, concluded} ->
          AuditLog.log_experiment_change(concluded, "scheduled_end",
            actor_type: "system",
            changes: %{status: %{from: "running", to: "concluded"}}
          )

        {:error, _} ->
          :ok
      end
    end)

    :ok
  end
end
