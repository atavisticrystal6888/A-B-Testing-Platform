defmodule ExperimentHub.Workers.GuardrailWorker do
  @moduledoc """
  Oban worker that checks guardrail metrics and auto-pauses experiments on breach (FR-095).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias ExperimentHub.{Repo, Experiments, AuditLog}
  alias ExperimentHub.Metrics.GuardrailEvaluator
  alias ExperimentHub.Experiments.Experiment

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"experiment_id" => experiment_id}}) do
    experiment = Repo.get!(Experiment, experiment_id)

    if experiment.status == "running" do
      case GuardrailEvaluator.evaluate(experiment) do
        {:breach, details} ->
          case Experiments.pause_experiment(experiment) do
            {:ok, paused} ->
              AuditLog.log_experiment_change(paused, "guardrail_breach",
                actor_type: "system",
                changes: %{
                  status: %{from: "running", to: "paused"},
                  guardrail_breach: details
                }
              )

              {:ok, :paused}

            {:error, reason} ->
              {:error, reason}
          end

        :ok ->
          :ok
      end
    else
      :ok
    end
  end
end
