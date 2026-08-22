defmodule ExperimentHubWeb.TimelineControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.AuditLog
  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Metrics
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

      # "started" is the real action string production writers use (the API
      # controller); see the "records API-driven lifecycle transitions" test
      # below for coverage of that write path itself.
      {:ok, _log} = AuditLog.log_experiment_change(experiment, "started", actor_type: "user")

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/timeline")
      response = json_response(conn, 200)

      lifecycle = response["data"]["lifecycle"]

      assert Enum.any?(lifecycle, fn entry ->
               entry["action"] == "started" and entry["actor_type"] == "user" and
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

    test "records API-driven lifecycle transitions and reflects them, normalized, in order", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      control =
        variant_fixture(
          experiment: experiment,
          tenant: tenant,
          is_control: true,
          traffic_allocation: 5000
        )

      variant_fixture(
        experiment: experiment,
        tenant: tenant,
        is_control: false,
        traffic_allocation: 5000
      )

      {:ok, metric_definition} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "timeline-metric",
          "name" => "Timeline Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "signup"}
        })

      {:ok, _experiment_metric} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric_definition.id,
          "role" => "primary"
        })

      assert json_response(post(conn, "/api/v1/experiments/#{experiment.id}/start"), 200)
      assert json_response(post(conn, "/api/v1/experiments/#{experiment.id}/pause"), 200)
      assert json_response(post(conn, "/api/v1/experiments/#{experiment.id}/resume"), 200)

      assert json_response(
               post(conn, "/api/v1/experiments/#{experiment.id}/conclude", %{
                 "decision" => "ship_variant",
                 "rationale" => "Treatment won.",
                 "winner_variant_id" => control.id
               }),
               200
             )

      response = json_response(get(conn, "/api/v1/experiments/#{experiment.id}/timeline"), 200)

      actions = Enum.map(response["data"]["lifecycle"], & &1["action"])
      assert actions == ["started", "paused", "resumed", "concluded"]

      concluded_entry = Enum.find(response["data"]["lifecycle"], &(&1["action"] == "concluded"))
      assert concluded_entry["actor_type"] == "api_key"
      assert concluded_entry["reason"] == "Treatment won."
    end
  end
end
