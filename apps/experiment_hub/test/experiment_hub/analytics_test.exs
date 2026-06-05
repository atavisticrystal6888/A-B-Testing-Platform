defmodule ExperimentHub.AnalyticsTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Analytics
  alias ExperimentHub.Assignments.Assignment

  describe "overview/1" do
    test "counts today's assignments using assigned_at" do
      tenant = tenant_fixture()
      experiment = experiment_fixture(tenant: tenant)
      variant = variant_fixture(tenant: tenant, experiment: experiment)
      start_of_today = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

      %Assignment{}
      |> Assignment.changeset(%{
        tenant_id: tenant.id,
        experiment_id: experiment.id,
        variant_id: variant.id,
        user_id: "today-user",
        assigned_at: start_of_today
      })
      |> Repo.insert!()

      %Assignment{}
      |> Assignment.changeset(%{
        tenant_id: tenant.id,
        experiment_id: experiment.id,
        variant_id: variant.id,
        user_id: "yesterday-user",
        assigned_at: DateTime.add(start_of_today, -1, :second)
      })
      |> Repo.insert!()

      overview = Analytics.overview(tenant.id)

      assert overview.assignments.total == 2
      assert overview.assignments.today == 1
    end
  end
end
