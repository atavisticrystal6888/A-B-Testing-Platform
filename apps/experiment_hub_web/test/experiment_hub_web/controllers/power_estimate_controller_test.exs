defmodule ExperimentHubWeb.PowerEstimateControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Repo

  # Matches the `{Req.Test, name}` plug configured for :experiment_hub_web's
  # :stat_engine_req_options in config/test.exs.
  @stub_name ExperimentHubWeb.PowerEstimateController.StatEngine

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

  describe "POST /api/v1/power-estimate" do
    test "happy path returns per-variant/total sample sizes and estimated_days from seeded assignments",
         %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(%{tenant: tenant, status: "running"})
      variant = variant_fixture(%{experiment: experiment, tenant: tenant})

      now = DateTime.utc_now()
      # 3 assignments inside the trailing 7-day window -> rate = 3/7 per day.
      for days_ago <- [1, 2, 3] do
        insert_assignment(tenant, experiment, variant, DateTime.add(now, -days_ago, :day))
      end

      Req.Test.stub(@stub_name, fn conn ->
        Req.Test.json(conn, %{
          "sample_size_per_variant" => 1000,
          "total_sample_size" => 2000,
          "baseline_rate" => 0.05,
          "minimum_detectable_effect" => 0.1,
          "significance_level" => 0.05,
          "power" => 0.8,
          "num_variants" => 2,
          "correction_method" => nil
        })
      end)

      conn =
        post(conn, "/api/v1/power-estimate", %{
          "baseline_rate" => 0.05,
          "mde" => 0.10,
          "significance_level" => 0.05,
          "power" => 0.8,
          "num_variants" => 2
        })

      response = json_response(conn, 200)

      assert response["data"]["sample_size_per_variant"] == 1000
      assert response["data"]["total_sample_size"] == 2000
      assert response["data"]["estimated_days"] == Kernel.ceil(2000 / (3 / 7))
    end

    test "returns estimated_days: null when the tenant has no recent traffic", %{conn: conn} do
      Req.Test.stub(@stub_name, fn conn ->
        Req.Test.json(conn, %{
          "sample_size_per_variant" => 500,
          "total_sample_size" => 1000,
          "baseline_rate" => 0.05,
          "minimum_detectable_effect" => 0.1,
          "significance_level" => 0.05,
          "power" => 0.8,
          "num_variants" => 2,
          "correction_method" => nil
        })
      end)

      conn =
        post(conn, "/api/v1/power-estimate", %{
          "baseline_rate" => 0.05,
          "mde" => 0.10,
          "num_variants" => 2
        })

      response = json_response(conn, 200)

      assert response["data"]["sample_size_per_variant"] == 500
      assert response["data"]["total_sample_size"] == 1000
      assert response["data"]["estimated_days"] == nil
    end

    test "returns 502 when the statistical engine has a server error (5xx)", %{conn: conn} do
      Req.Test.stub(@stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 500, Jason.encode!(%{"detail" => "internal error"}))
      end)

      conn =
        post(conn, "/api/v1/power-estimate", %{
          "baseline_rate" => 0.05,
          "mde" => 0.10,
          "num_variants" => 2
        })

      response = json_response(conn, 502)
      assert response["error"] == "bad_gateway"
    end

    test "returns 422 (not 502) when the engine rejects the input (4xx)", %{conn: conn} do
      # e.g. baseline_rate/mde out of the engine's Pydantic-validated range —
      # this must read as "fix your inputs", not "the engine is down".
      Req.Test.stub(@stub_name, fn conn ->
        Plug.Conn.send_resp(
          conn,
          422,
          Jason.encode!(%{
            "detail" => [
              %{"loc" => ["body", "baseline_rate"], "msg" => "ensure this value is > 0"}
            ]
          })
        )
      end)

      conn =
        post(conn, "/api/v1/power-estimate", %{
          "baseline_rate" => 0,
          "mde" => 0.10,
          "num_variants" => 2
        })

      response = json_response(conn, 422)
      assert response["error"] == "invalid_input"
      refute response["error"] == "bad_gateway"
    end
  end
end
