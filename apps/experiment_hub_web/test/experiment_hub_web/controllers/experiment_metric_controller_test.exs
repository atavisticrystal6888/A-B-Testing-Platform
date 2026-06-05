defmodule ExperimentHubWeb.ExperimentMetricControllerTest do
  use ExperimentHubWeb.ConnCase

  alias ExperimentHub.Repo
  alias ExperimentHub.Metrics

  setup %{conn: conn} do
    tenant = tenant_fixture()
    api_key = api_key_fixture(%{tenant: tenant})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-api-key", api_key.raw_key)

    Repo.put_tenant_id(tenant.id)

    # Create a metric definition and experiment for use in tests
    {:ok, metric_def} =
      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "test-metric",
        "name" => "Test Metric",
        "metric_type" => "count",
        "definition" => %{"event_name" => "test"}
      })

    experiment =
      Repo.insert!(%ExperimentHub.Experiments.Experiment{
        tenant_id: tenant.id,
        key: "test-exp",
        name: "Test Experiment",
        hypothesis: "Test"
      })

    %{
      conn: conn,
      tenant: tenant,
      metric_def: metric_def,
      experiment: experiment
    }
  end

  # T053 - POST /api/v1/experiments/:experiment_id/metrics
  describe "POST /api/v1/experiments/:experiment_id/metrics" do
    test "attaches a metric to an experiment", %{
      conn: conn,
      experiment: experiment,
      metric_def: metric_def
    } do
      params = %{
        "metric_definition_id" => metric_def.id,
        "role" => "primary"
      }

      conn = post(conn, "/api/v1/experiments/#{experiment.id}/metrics", params)
      response = json_response(conn, 201)

      assert response["role"] == "primary"
      assert response["metric_definition_id"] == metric_def.id
      assert response["experiment_id"] == experiment.id
    end

    test "attaches a guardrail metric with threshold", %{
      conn: conn,
      experiment: experiment,
      metric_def: metric_def
    } do
      params = %{
        "metric_definition_id" => metric_def.id,
        "role" => "guardrail",
        "guardrail_threshold" => 0.05,
        "guardrail_direction" => "above"
      }

      conn = post(conn, "/api/v1/experiments/#{experiment.id}/metrics", params)
      response = json_response(conn, 201)

      assert response["role"] == "guardrail"
      assert response["guardrail_direction"] == "above"
    end

    test "returns 422 when adding second primary metric", %{
      conn: conn,
      tenant: tenant,
      experiment: experiment,
      metric_def: metric_def
    } do
      # Attach first primary
      Metrics.attach_metric(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "metric_definition_id" => metric_def.id,
        "role" => "primary"
      })

      # Create a second metric definition
      {:ok, metric_def2} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "second-metric",
          "name" => "Second Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "second"}
        })

      # Try to attach second primary
      params = %{
        "metric_definition_id" => metric_def2.id,
        "role" => "primary"
      }

      conn = post(conn, "/api/v1/experiments/#{experiment.id}/metrics", params)
      assert json_response(conn, 422)["error"] == "primary_metric_exists"
    end
  end

  # T053 - DELETE /api/v1/experiments/:experiment_id/metrics/:id
  describe "DELETE /api/v1/experiments/:experiment_id/metrics/:id" do
    test "detaches a metric from an experiment", %{
      conn: conn,
      tenant: tenant,
      experiment: experiment,
      metric_def: metric_def
    } do
      {:ok, experiment_metric} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric_def.id,
          "role" => "secondary"
        })

      conn = delete(conn, "/api/v1/experiments/#{experiment.id}/metrics/#{experiment_metric.id}")
      assert response(conn, 204)
    end

    test "returns 404 for non-existent experiment metric", %{conn: conn, experiment: experiment} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, "/api/v1/experiments/#{experiment.id}/metrics/#{fake_id}")
      assert json_response(conn, 404)
    end
  end
end
