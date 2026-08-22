defmodule ExperimentHub.Workers.AnalysisWorkerTest do
  use ExperimentHub.DataCase, async: false

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Metrics
  alias ExperimentHub.Repo
  alias ExperimentHub.Workers.AnalysisWorker

  defp insert_assignment(tenant, experiment, variant, assigned_at) do
    {:ok, assignment} =
      %Assignment{}
      |> Assignment.changeset(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => "user-#{System.unique_integer([:positive])}",
        "assigned_at" => DateTime.truncate(assigned_at, :second)
      })
      |> Repo.insert()

    assignment
  end

  # Experiment.changeset/2 (used by experiment_fixture) doesn't cast
  # started_at -- it's only ever set via the start-experiment transition.
  # Set it directly here to exercise the since-started_at window logic.
  defp with_started_at(experiment, started_at) do
    experiment
    |> Ecto.Changeset.change(started_at: started_at)
    |> Repo.update!()
  end

  describe "exposure_rate_per_day/1" do
    test "counts only assignments inside the trailing 7-day window for an older experiment" do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)

      experiment =
        experiment_fixture(%{tenant: tenant, status: "running"})
        |> with_started_at(
          DateTime.utc_now()
          |> DateTime.add(-30, :day)
          |> DateTime.truncate(:second)
        )

      variant = variant_fixture(%{experiment: experiment, tenant: tenant})

      now = DateTime.utc_now()
      # Inside the 7-day window.
      for days_ago <- [1, 3, 6] do
        insert_assignment(tenant, experiment, variant, DateTime.add(now, -days_ago, :day))
      end

      # Outside the window -- must not be counted.
      insert_assignment(tenant, experiment, variant, DateTime.add(now, -10, :day))

      rate = AnalysisWorker.exposure_rate_per_day(experiment)

      assert_in_delta rate, 3 / 7, 0.01
    end

    test "uses the shorter since-started_at window for a young experiment" do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)

      started_at = DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)

      experiment =
        experiment_fixture(%{tenant: tenant, status: "running"})
        |> with_started_at(started_at)

      variant = variant_fixture(%{experiment: experiment, tenant: tenant})

      insert_assignment(tenant, experiment, variant, DateTime.add(started_at, 3600, :second))
      insert_assignment(tenant, experiment, variant, DateTime.add(started_at, 7200, :second))

      rate = AnalysisWorker.exposure_rate_per_day(experiment)

      # ~2 assignments over a ~2-day window, not diluted by the full 7 days.
      assert_in_delta rate, 2 / 2.0, 0.1
    end

    test "returns 0.0 when there are no assignments yet" do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)

      experiment =
        experiment_fixture(%{tenant: tenant, status: "running"})
        |> with_started_at(DateTime.utc_now() |> DateTime.truncate(:second))

      assert AnalysisWorker.exposure_rate_per_day(experiment) == 0.0
    end
  end

  describe "build_analysis_request/3" do
    test "sends the computed exposure_rate_per_day in the request config" do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)

      experiment =
        experiment_fixture(%{tenant: tenant, status: "running"})
        |> with_started_at(
          DateTime.utc_now()
          |> DateTime.add(-30, :day)
          |> DateTime.truncate(:second)
        )

      variant = variant_fixture(%{experiment: experiment, tenant: tenant})
      experiment = Repo.preload(experiment, :variants)

      now = DateTime.utc_now()

      for days_ago <- [1, 2] do
        insert_assignment(tenant, experiment, variant, DateTime.add(now, -days_ago, :day))
      end

      metrics = Metrics.list_experiment_metrics(experiment.id)
      request = AnalysisWorker.build_analysis_request(experiment, tenant.id, metrics)

      assert %{config: %{exposure_rate_per_day: rate}} = request
      assert_in_delta rate, 2 / 7, 0.01
    end

    test "sends variant_count so the engine can scale exposure_rate_per_day for multi-arm experiments" do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)

      experiment = experiment_fixture(%{tenant: tenant, status: "running"})
      variant_fixture(%{experiment: experiment, tenant: tenant, key: "control", is_control: true})
      variant_fixture(%{experiment: experiment, tenant: tenant, key: "b", is_control: false})
      variant_fixture(%{experiment: experiment, tenant: tenant, key: "c", is_control: false})

      experiment = Repo.preload(experiment, :variants)
      metrics = Metrics.list_experiment_metrics(experiment.id)
      request = AnalysisWorker.build_analysis_request(experiment, tenant.id, metrics)

      assert %{config: %{variant_count: 3}} = request
    end
  end

  # Every put_tenant_id/1 caller must clear it deterministically once its
  # unit of work ends, including when it raises -- see the matching pair of
  # tests in guardrail_worker_test.exs (which also proves the successful-job
  # path without touching a real network dependency) and the mechanism-level
  # proof in repo_test.exs's "with_tenant/2" tests.
  test "tenant context is cleared even when perform/1 raises" do
    tenant = tenant_fixture()

    # A malformed experiment_id (not a valid UUID) makes Repo.get/2 raise
    # Ecto.Query.CastError deep inside perform/1's `with_tenant/2` fun,
    # before any HTTP call to the statistical engine is attempted.
    assert_raise Ecto.Query.CastError, fn ->
      AnalysisWorker.perform(%Oban.Job{
        args: %{"experiment_id" => "not-a-valid-uuid", "tenant_id" => tenant.id}
      })
    end

    refute Repo.current_tenant_id()

    assert {:error, %Postgrex.Error{postgres: %{message: message}}} =
             Repo.query("SELECT current_setting('app.current_tenant_id')::uuid", [])

    assert message =~ "invalid input syntax for type uuid"
  end
end
