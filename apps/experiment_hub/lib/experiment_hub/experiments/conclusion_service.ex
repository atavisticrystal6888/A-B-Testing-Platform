defmodule ExperimentHub.Experiments.ConclusionService do
  @moduledoc """
  Service for concluding experiments with winner selection and data archival (FR-065/FR-067).
  """

  alias ExperimentHub.{AuditLog, Repo}
  alias ExperimentHub.Experiments.Experiment

  import Ecto.Query

  @doc """
  Conclude an experiment with optional winner variant.
  """
  def conclude(experiment_id, opts \\ []) do
    winner_variant_id = opts[:winner_variant_id]
    conclusion_reason = opts[:conclusion_reason] || "manual"
    actor_id = opts[:actor_id]

    Repo.transaction(fn ->
      experiment = Repo.get!(Experiment, experiment_id) |> Repo.preload(:variants)

      with {:ok, experiment} <- validate_conclusion(experiment, winner_variant_id),
           {:ok, experiment} <-
             apply_conclusion(experiment, winner_variant_id, conclusion_reason),
           {:ok, _log} <-
             log_conclusion(experiment, winner_variant_id, conclusion_reason, actor_id) do
        experiment
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp validate_conclusion(experiment, winner_variant_id) do
    cond do
      experiment.status not in ["running", "paused"] ->
        {:error, :invalid_state}

      winner_variant_id && !Enum.any?(experiment.variants, &(&1.id == winner_variant_id)) ->
        {:error, :invalid_winner}

      true ->
        {:ok, experiment}
    end
  end

  defp apply_conclusion(experiment, winner_variant_id, conclusion_reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    experiment
    |> Ecto.Changeset.change(%{
      status: "concluded",
      ended_at: now,
      concluded_at: now,
      winner_variant_id: winner_variant_id,
      conclusion_reason: conclusion_reason,
      conclusion_decision: "ship_variant"
    })
    |> Repo.update()
  end

  defp log_conclusion(experiment, winner_variant_id, conclusion_reason, actor_id) do
    winner_name =
      if winner_variant_id do
        experiment.variants
        |> Enum.find(&(&1.id == winner_variant_id))
        |> case do
          nil -> nil
          v -> v.name
        end
      end

    AuditLog.log_experiment_change(experiment, "concluded",
      actor_id: actor_id,
      actor_type: if(actor_id, do: "user", else: "system"),
      reason: conclusion_reason,
      changes: %{
        status: %{from: "running", to: "concluded"},
        winner_variant_id: winner_variant_id,
        winner_variant_name: winner_name,
        conclusion_reason: conclusion_reason
      }
    )
  end

  @doc """
  Auto-conclude experiments that have reached their maximum duration.
  Called by scheduler/Oban worker.
  """
  def auto_conclude_expired do
    now = DateTime.utc_now()

    from(e in Experiment,
      where: e.status == "running",
      where: not is_nil(e.max_duration_days),
      where: fragment("? + (? || ' days')::interval < ?", e.started_at, e.max_duration_days, ^now)
    )
    |> Repo.all()
    |> Enum.map(fn experiment ->
      conclude(experiment.id, conclusion_reason: "auto_max_duration")
    end)
  end
end
