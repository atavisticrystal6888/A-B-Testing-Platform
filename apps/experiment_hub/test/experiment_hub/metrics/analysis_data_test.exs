defmodule ExperimentHub.Metrics.AnalysisDataTest do
  use ExperimentHub.DataCase, async: false

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Events.ExperimentEvent
  alias ExperimentHub.Experiments
  alias ExperimentHub.Metrics
  alias ExperimentHub.Metrics.AnalysisData

  defp insert_assignment!(tenant, experiment, variant, user_id) do
    %Assignment{}
    |> Assignment.changeset(%{
      "tenant_id" => tenant.id,
      "experiment_id" => experiment.id,
      "variant_id" => variant.id,
      "user_id" => user_id,
      "assigned_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  defp insert_event!(tenant, experiment, variant, user_id, attrs \\ %{}) do
    %ExperimentEvent{}
    |> ExperimentEvent.changeset(
      Map.merge(
        %{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "variant_id" => variant.id,
          "user_id" => user_id,
          "event_type" => "conversion",
          "event_name" => "checkout_completed",
          "idempotency_key" => "adt-#{user_id}-#{System.unique_integer([:positive])}",
          "timestamp" => DateTime.utc_now() |> DateTime.truncate(:second)
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  setup do
    tenant = tenant_fixture()
    Repo.put_tenant_id(tenant.id)
    experiment = experiment_fixture(%{tenant: tenant})

    control =
      variant_fixture(%{
        experiment: experiment,
        tenant: tenant,
        key: "control",
        is_control: true,
        sort_order: 0
      })

    treatment =
      variant_fixture(%{
        experiment: experiment,
        tenant: tenant,
        key: "treatment",
        is_control: false,
        sort_order: 1
      })

    {:ok, metric} =
      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "checkout_conversion",
        "name" => "Checkout Conversion",
        "metric_type" => "ratio",
        "definition" => %{"event_name" => "checkout_completed"}
      })

    {:ok, _attachment} =
      Metrics.attach_metric(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "metric_definition_id" => metric.id,
        "role" => "primary"
      })

    experiment = Repo.preload(Repo.get!(Experiments.Experiment, experiment.id), :variants)
    [experiment_metric] = Metrics.list_experiment_metrics(experiment.id)

    %{
      tenant: tenant,
      experiment: experiment,
      control: control,
      treatment: treatment,
      experiment_metric: experiment_metric
    }
  end

  test "counts distinct assigned users and distinct converting users per variant", ctx do
    %{tenant: t, experiment: e, control: c, treatment: tr, experiment_metric: em} = ctx

    for i <- 1..3, do: insert_assignment!(t, e, c, "control-user-#{i}")
    for i <- 1..2, do: insert_assignment!(t, e, tr, "treatment-user-#{i}")

    # user 1 converts twice — must count once
    insert_event!(t, e, c, "control-user-1")
    insert_event!(t, e, c, "control-user-1")
    insert_event!(t, e, tr, "treatment-user-1", %{"value" => 50})
    insert_event!(t, e, tr, "treatment-user-2", %{"value" => 30})

    [control_stats, treatment_stats] = AnalysisData.variant_stats(e, em)

    assert control_stats["variant_key"] == "control"
    assert control_stats["sample_size"] == 3
    assert control_stats["conversions"] == 1

    assert treatment_stats["variant_key"] == "treatment"
    assert treatment_stats["sample_size"] == 2
    assert treatment_stats["conversions"] == 2
    assert treatment_stats["sum_value"] == 80.0
    assert treatment_stats["sum_squared_value"] == 50.0 * 50.0 + 30.0 * 30.0
  end

  test "excludes bot events and non-matching event names", ctx do
    %{tenant: t, experiment: e, control: c, experiment_metric: em} = ctx

    insert_assignment!(t, e, c, "user-1")
    insert_event!(t, e, c, "user-1", %{"event_name" => "unrelated_event"})
    insert_event!(t, e, c, "user-1", %{"is_bot" => true})

    [control_stats, _] = AnalysisData.variant_stats(e, em)
    assert control_stats["conversions"] == 0
  end

  test "ignores events from users who were never assigned", ctx do
    %{tenant: t, experiment: e, control: c, experiment_metric: em} = ctx

    insert_assignment!(t, e, c, "assigned-user")
    # a matching conversion from a user with no assignment must not count
    insert_event!(t, e, c, "ghost-user")

    [control_stats, _] = AnalysisData.variant_stats(e, em)
    assert control_stats["sample_size"] == 1
    assert control_stats["conversions"] == 0
  end

  test "returns zeros when nothing is recorded", ctx do
    %{experiment: e, experiment_metric: em} = ctx

    [control_stats, treatment_stats] = AnalysisData.variant_stats(e, em)

    assert control_stats["sample_size"] == 0
    assert control_stats["conversions"] == 0
    assert treatment_stats["sum_value"] == 0.0
  end
end
