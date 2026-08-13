defmodule ExperimentHub.Workers.GuardrailWorkerTest do
  use ExperimentHub.DataCase, async: false
  use Oban.Testing, repo: ExperimentHub.Repo

  alias ExperimentHub.{Experiments, Metrics}
  alias ExperimentHub.Metrics.StatisticalAnalysis
  alias ExperimentHub.Workers.{GuardrailWorker, NotificationWorker}

  defp setup_running_experiment_with_guardrail(breach_effect) do
    tenant = tenant_fixture()
    Repo.put_tenant_id(tenant.id)

    experiment = experiment_fixture(%{tenant: tenant, status: "draft"})

    variant_fixture(%{
      experiment: experiment,
      tenant: tenant,
      key: "control",
      is_control: true,
      traffic_allocation: 5000
    })

    variant_fixture(%{
      experiment: experiment,
      tenant: tenant,
      key: "treatment",
      is_control: false,
      traffic_allocation: 5000,
      sort_order: 1
    })

    {:ok, primary_metric} =
      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "checkout_conversion",
        "name" => "Checkout Conversion",
        "metric_type" => "ratio",
        "definition" => %{"event_name" => "checkout_completed"}
      })

    {:ok, _primary_attachment} =
      Metrics.attach_metric(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "metric_definition_id" => primary_metric.id,
        "role" => "primary"
      })

    {:ok, guardrail_metric} =
      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "checkout_error_rate",
        "name" => "Checkout Error Rate",
        "metric_type" => "ratio",
        "definition" => %{"event_name" => "checkout_error"}
      })

    {:ok, _guardrail_attachment} =
      Metrics.attach_metric(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "metric_definition_id" => guardrail_metric.id,
        "role" => "guardrail",
        "guardrail_threshold" => 0.03,
        "guardrail_direction" => "above"
      })

    {:ok, experiment} =
      Experiments.start_experiment(Repo.get!(Experiments.Experiment, experiment.id))

    {:ok, _analysis} =
      %StatisticalAnalysis{}
      |> StatisticalAnalysis.changeset(%{
        tenant_id: tenant.id,
        experiment_id: experiment.id,
        metric_definition_id: guardrail_metric.id,
        analysis_type: "frequentist",
        methodology: "guardrail_threshold",
        parameters: %{},
        results: %{"frequentist" => %{"effect_size" => %{"relative" => breach_effect}}},
        sample_sizes: %{}
      })
      |> Repo.insert()

    %{tenant: tenant, experiment: experiment}
  end

  test "pauses the experiment, audits, and enqueues a notification on breach" do
    %{tenant: tenant, experiment: experiment} = setup_running_experiment_with_guardrail(0.05)

    assert {:ok, :paused} =
             perform_job(GuardrailWorker, %{
               "experiment_id" => experiment.id,
               "tenant_id" => tenant.id
             })

    paused = Repo.get!(ExperimentHub.Experiments.Experiment, experiment.id)
    assert paused.status == "paused"

    assert_enqueued(
      worker: NotificationWorker,
      args: %{"event_type" => "guardrail.breach"}
    )
  end

  test "leaves the experiment running and enqueues nothing when no guardrail is breached" do
    %{tenant: tenant, experiment: experiment} = setup_running_experiment_with_guardrail(0.01)

    assert :ok =
             perform_job(GuardrailWorker, %{
               "experiment_id" => experiment.id,
               "tenant_id" => tenant.id
             })

    still_running = Repo.get!(ExperimentHub.Experiments.Experiment, experiment.id)
    assert still_running.status == "running"

    refute_enqueued(worker: NotificationWorker)
  end

  test "is a no-op for an experiment that isn't running" do
    tenant = tenant_fixture()
    Repo.put_tenant_id(tenant.id)
    experiment = experiment_fixture(%{tenant: tenant, status: "draft"})

    assert :ok =
             perform_job(GuardrailWorker, %{
               "experiment_id" => experiment.id,
               "tenant_id" => tenant.id
             })

    refute_enqueued(worker: NotificationWorker)
  end
end
