defmodule ExperimentHubWeb.TimelineControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.AuditLog
  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Repo

  setup %{conn: conn} do
    tenant = tenant_fixture()
    api_key = api_key_fixture(tenant: tenant)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-api-key", api_key.raw_key)

    Repo.put_tenant_id(tenant.id)

    %{conn: conn, tenant: tenant}
  end

  describe "GET /api/v1/experiments/:experiment_id/timeline" do
    test "returns lifecycle audit entries and daily exposure counts", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)
      variant = variant_fixture(experiment: experiment, tenant: tenant)

      day1 = ~U[2026-08-01 10:00:00Z]
      day2 = ~U[2026-08-02 09:30:00Z]

      %Assignment{}
      |> Assignment.changeset(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => "user-1",
        "assigned_at" => day1
      })
      |> Repo.insert!()

      %Assignment{}
      |> Assignment.changeset(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => "user-2",
        "assigned_at" => day1
      })
      |> Repo.insert!()

      %Assignment{}
      |> Assignment.changeset(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => "user-3",
        "assigned_at" => day2
      })
      |> Repo.insert!()

      {:ok, _log} = AuditLog.log_experiment_change(experiment, "start", actor_type: "user")

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/timeline")
      response = json_response(conn, 200)

      lifecycle = response["data"]["lifecycle"]

      assert Enum.any?(lifecycle, fn entry ->
               entry["action"] == "start" and entry["actor_type"] == "user" and
                 entry["reason"] == nil
             end)

      daily_exposures = response["data"]["daily_exposures"]
      assert Enum.find(daily_exposures, &(&1["date"] == "2026-08-01"))["count"] == 2
      assert Enum.find(daily_exposures, &(&1["date"] == "2026-08-02"))["count"] == 1
    end

    test "returns 404 for a different tenant's experiment", %{conn: conn} do
      other_tenant = tenant_fixture()
      other_experiment = experiment_fixture(tenant: other_tenant)

      conn = get(conn, "/api/v1/experiments/#{other_experiment.id}/timeline")

      assert json_response(conn, 404)["error"] == "not_found"
    end
  end
end
