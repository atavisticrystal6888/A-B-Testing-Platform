defmodule ExperimentHub.Metrics.SegmentsTest do
  use ExperimentHub.DataCase, async: false

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Events.ExperimentEvent
  alias ExperimentHub.Experiments
  alias ExperimentHub.Metrics
  alias ExperimentHub.Metrics.Segments

  defp insert_assignment!(tenant, experiment, variant, user_id, context) do
    %Assignment{}
    |> Assignment.changeset(%{
      "tenant_id" => tenant.id,
      "experiment_id" => experiment.id,
      "variant_id" => variant.id,
      "user_id" => user_id,
      "context" => context
    })
    |> Repo.insert!()
  end

  defp insert_conversion!(tenant, experiment, variant, user_id) do
    %ExperimentEvent{}
    |> ExperimentEvent.changeset(%{
      "tenant_id" => tenant.id,
      "experiment_id" => experiment.id,
      "variant_id" => variant.id,
      "user_id" => user_id,
      "event_type" => "conversion",
      "event_name" => "checkout_completed",
      "idempotency_key" => "seg-#{user_id}-#{System.unique_integer([:positive])}",
      "timestamp" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
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
        traffic_allocation: 5000,
        sort_order: 0
      })

    treatment =
      variant_fixture(%{
        experiment: experiment,
        tenant: tenant,
        key: "treatment",
        is_control: false,
        traffic_allocation: 5000,
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

    {:ok, _} =
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

  test "splits sample sizes and conversions by assignment-time attribute", ctx do
    %{tenant: t, experiment: e, control: c, treatment: tr, experiment_metric: em} = ctx

    insert_assignment!(t, e, c, "us-1", %{"country" => "US"})
    insert_assignment!(t, e, c, "us-2", %{"country" => "US"})
    insert_assignment!(t, e, tr, "us-3", %{"country" => "US"})
    insert_assignment!(t, e, tr, "in-1", %{"country" => "IN"})
    insert_assignment!(t, e, c, "none-1", %{})

    insert_conversion!(t, e, c, "us-1")
    insert_conversion!(t, e, tr, "in-1")

    {:ok, segments} = Segments.breakdown(e, em, "country")

    by_segment = Map.new(segments, &{&1.segment, &1})
    assert Map.keys(by_segment) |> Enum.sort() == ["(unknown)", "IN", "US"]

    us = by_segment["US"]
    us_control = Enum.find(us.variants, &(&1.variant_key == "control"))
    us_treatment = Enum.find(us.variants, &(&1.variant_key == "treatment"))
    assert us_control.sample_size == 2
    assert us_control.conversions == 1
    assert us_control.conversion_rate == 0.5
    assert us_treatment.sample_size == 1
    assert us_treatment.conversions == 0

    india = by_segment["IN"]
    india_treatment = Enum.find(india.variants, &(&1.variant_key == "treatment"))
    assert india_treatment.conversions == 1

    unknown = by_segment["(unknown)"]
    assert unknown.total_sample_size == 1
  end

  test "segments are ordered by total sample size, largest first", ctx do
    %{tenant: t, experiment: e, control: c, experiment_metric: em} = ctx

    insert_assignment!(t, e, c, "b-1", %{"device" => "desktop"})
    insert_assignment!(t, e, c, "a-1", %{"device" => "mobile"})
    insert_assignment!(t, e, c, "a-2", %{"device" => "mobile"})

    {:ok, [first, second]} = Segments.breakdown(e, em, "device")
    assert first.segment == "mobile"
    assert second.segment == "desktop"
  end

  test "rejects malformed attribute names", ctx do
    %{experiment: e, experiment_metric: em} = ctx

    assert {:error, :invalid_attribute} = Segments.breakdown(e, em, "country; DROP TABLE")
    assert {:error, :invalid_attribute} = Segments.breakdown(e, em, "")
  end

  test "assign/2 records the attributes map as assignment context", ctx do
    %{tenant: t, experiment: e} = ctx
    {:ok, running} = start_with_metric(e)

    {:ok, _result} =
      ExperimentHub.Assignments.assign(t.id, %{
        "user_id" => "ctx-user-1",
        "experiment_key" => running.key,
        "attributes" => %{"country" => "US", "device" => "mobile"}
      })

    assignment = Repo.get_by!(Assignment, experiment_id: running.id, user_id: "ctx-user-1")
    assert assignment.context == %{"country" => "US", "device" => "mobile"}
  end

  defp start_with_metric(experiment) do
    Experiments.start_experiment(Repo.get!(Experiments.Experiment, experiment.id))
  end
end
