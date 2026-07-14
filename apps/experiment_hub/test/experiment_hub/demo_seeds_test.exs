defmodule ExperimentHub.DemoSeedsTest do
  use ExperimentHub.DataCase, async: false

  import Ecto.Query

  alias ExperimentHub.{Analytics, DemoSeeds, FeatureFlags, Repo, Tenants}
  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.AuditLog
  alias ExperimentHub.Events.ExperimentEvent
  alias ExperimentHub.Experiments.{ExclusionGroup, Experiment}
  alias ExperimentHub.FeatureFlags.Flag
  alias ExperimentHub.Metrics.{ExperimentResultDaily, MetricDefinition, StatisticalAnalysis}

  test "seeds an idempotent workspace with demo data across core product surfaces" do
    first = DemoSeeds.seed!()
    second = DemoSeeds.seed!()

    assert first.tenant.id == second.tenant.id
    assert first.experiments.checkout.id == second.experiments.checkout.id
    assert first.experiments.search.status == "concluded"
    assert second.experiments.checkout.status == "running"
    assert second.experiments.pricing.status == "paused"
    assert second.experiments.onboarding.status == "draft"

    assert {:ok, admin} =
             Tenants.authenticate_user(first.tenant.slug, "admin@local.dev", first.admin_password)

    assert admin.id == second.admin.id
    assert {:ok, _api_key} = Tenants.verify_api_key(second.api_key.raw_key)
    assert {:ok, true} = FeatureFlags.evaluate(first.tenant.id, "search_in_stock_boost", %{})
    assert {:ok, false} = FeatureFlags.evaluate(first.tenant.id, "guided_onboarding", %{})

    Repo.put_tenant_id(first.tenant.id)

    assert Repo.aggregate(from(experiment in Experiment), :count) == 4
    assert Repo.aggregate(from(metric in MetricDefinition), :count) == 3
    assert Repo.aggregate(from(flag in Flag), :count) == 3
    assert Repo.aggregate(from(group in ExclusionGroup), :count) == 1
    assert Repo.aggregate(from(assignment in Assignment), :count) == 54
    assert Repo.aggregate(from(event in ExperimentEvent), :count) == 84
    assert Repo.aggregate(from(result in ExperimentResultDaily), :count) >= 12
    assert Repo.aggregate(from(analysis in StatisticalAnalysis), :count) == 4
    assert Repo.aggregate(from(log in AuditLog), :count) == 3

    overview = Analytics.overview(first.tenant.id)
    assert overview.experiments == %{total: 4, draft: 1, running: 1, paused: 1, concluded: 1}
    assert overview.feature_flags == %{total: 3, enabled: 2, disabled: 1}
    assert overview.assignments.total == 54
  after
    Repo.clear_tenant_id()
  end
end
