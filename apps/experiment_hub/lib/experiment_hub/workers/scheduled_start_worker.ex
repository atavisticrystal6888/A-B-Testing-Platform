defmodule ExperimentHub.Workers.ScheduledStartWorker do
  @moduledoc """
  Oban worker for auto-starting experiments at scheduled_start_at (FR-100).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias ExperimentHub.{Experiments, Repo, AuditLog}
  alias ExperimentHub.Experiments.Experiment
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

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

    :ok
  end
end
