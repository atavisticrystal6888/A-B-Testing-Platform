defmodule ExperimentHub.Workers.GuardrailWorker do
  @moduledoc """
  Oban worker that checks guardrail metrics and auto-pauses experiments on breach (FR-095).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  require Logger

  alias ExperimentHub.{Repo, Experiments, AuditLog, Notifications}
  alias ExperimentHub.Metrics.GuardrailEvaluator
  alias ExperimentHub.Experiments.Experiment

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"experiment_id" => experiment_id, "tenant_id" => tenant_id}}) do
    # The app connects as a superuser, which bypasses FORCE ROW LEVEL
    # SECURITY entirely — without this, queries below aren't blocked, they
    # silently return every tenant's rows instead of just this one's.
    Repo.put_tenant_id(tenant_id)

    case Repo.get(Experiment, experiment_id) do
      nil ->
        Logger.warning("Guardrail worker: experiment #{experiment_id} not found")
        :ok

      experiment ->
        check_experiment(experiment)
    end
  end

  defp check_experiment(%Experiment{status: "running"} = experiment) do
    # check_breaches/1 returns a list of %{metric_id, details} maps (one per
    # breached guardrail), not a bare {:breach, _} | :ok tuple.
    case GuardrailEvaluator.check_breaches(experiment.id) do
      [] ->
        :ok

      breaches ->
        case Experiments.pause_experiment(experiment) do
          {:ok, paused} ->
            AuditLog.log_experiment_change(paused, "guardrail_breach",
              actor_type: "system",
              changes: %{
                status: %{from: "running", to: "paused"},
                guardrail_breaches: breaches
              }
            )

            Notifications.notify_async("guardrail.breach", %{
              "experiment_id" => paused.id,
              "experiment_key" => paused.key,
              "experiment_name" => paused.name,
              "breaches" => breaches
            })

            {:ok, :paused}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp check_experiment(_experiment), do: :ok
end
