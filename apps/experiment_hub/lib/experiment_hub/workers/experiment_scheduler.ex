defmodule ExperimentHub.Workers.ExperimentScheduler do
  @moduledoc """
  Oban worker for starting/stopping scheduled experiments (FR-100).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias ExperimentHub.{Experiments, Repo, AuditLog}
  alias ExperimentHub.Experiments.Experiment
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "check_scheduled"}}) do
    now = DateTime.utc_now()

    # Start scheduled experiments
    from(e in Experiment,
      where: e.status == "draft",
      where: not is_nil(e.scheduled_start_at),
      where: e.scheduled_start_at <= ^now
    )
    |> Repo.all()
    |> Enum.each(fn experiment ->
      case Experiments.start_experiment(experiment) do
        {:ok, updated} ->
          AuditLog.log_experiment_change(updated, "scheduled_start",
            actor_type: "system",
            changes: %{status: %{from: "draft", to: "running"}}
          )

        {:error, _} ->
          :ok
      end
    end)

    # Stop experiments past end date
    from(e in Experiment,
      where: e.status == "running",
      where: not is_nil(e.scheduled_end_at),
      where: e.scheduled_end_at <= ^now
    )
    |> Repo.all()
    |> Enum.each(fn experiment ->
      case ExperimentHub.Experiments.ConclusionService.conclude(experiment.id,
             conclusion_reason: "scheduled_end"
           ) do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end)

    :ok
  end
end
