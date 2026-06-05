defmodule ExperimentHubWeb.MetricDefinitionControllerTest do
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

    %{conn: conn, tenant: tenant}
  end

  # T052 - POST /api/v1/metric-definitions
  describe "POST /api/v1/metric-definitions" do
    test "creates a metric definition", %{conn: conn} do
      params = %{
        "key" => "checkout-conversion",
        "name" => "Checkout Conversion Rate",
        "metric_type" => "count",
        "definition" => %{
          "event_name" => "checkout_completed",
          "event_type" => "conversion"
        }
      }

      conn = post(conn, "/api/v1/metric-definitions", params)
      response = json_response(conn, 201)

      assert response["key"] == "checkout-conversion"
      assert response["name"] == "Checkout Conversion Rate"
      assert response["metric_type"] == "count"
      assert response["definition"]["event_name"] == "checkout_completed"
    end

    test "returns 422 for invalid metric_type", %{conn: conn} do
      params = %{
        "key" => "bad-metric",
        "name" => "Bad Metric",
        "metric_type" => "invalid_type",
        "definition" => %{}
      }

      conn = post(conn, "/api/v1/metric-definitions", params)
      assert json_response(conn, 422)
    end

    test "returns 422 for duplicate key", %{conn: conn} do
      params = %{
        "key" => "dup-metric",
        "name" => "Dup Metric",
        "metric_type" => "count",
        "definition" => %{"event_name" => "test"}
      }

      post(conn, "/api/v1/metric-definitions", params)
      conn = post(conn, "/api/v1/metric-definitions", params)

      assert json_response(conn, 422)
    end
  end

  describe "GET /api/v1/metric-definitions" do
    test "lists metric definitions", %{conn: conn, tenant: tenant} do
      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "metric-a",
        "name" => "Metric A",
        "metric_type" => "count",
        "definition" => %{"event_name" => "a"}
      })

      Metrics.create_metric_definition(%{
        "tenant_id" => tenant.id,
        "key" => "metric-b",
        "name" => "Metric B",
        "metric_type" => "sum",
        "definition" => %{"event_name" => "b"}
      })

      conn = get(conn, "/api/v1/metric-definitions")
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
    end
  end

  describe "GET /api/v1/metric-definitions/:id" do
    test "shows a metric definition", %{conn: conn, tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "show-metric",
          "name" => "Show Metric",
          "metric_type" => "ratio",
          "definition" => %{"numerator" => "clicks", "denominator" => "views"}
        })

      conn = get(conn, "/api/v1/metric-definitions/#{metric_def.id}")
      response = json_response(conn, 200)

      assert response["key"] == "show-metric"
      assert response["metric_type"] == "ratio"
    end

    test "returns 404 for non-existent metric", %{conn: conn} do
      conn = get(conn, "/api/v1/metric-definitions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/metric-definitions/:id" do
    test "updates a metric definition", %{conn: conn, tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "update-metric",
          "name" => "Update Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      conn =
        put(conn, "/api/v1/metric-definitions/#{metric_def.id}", %{
          "name" => "Updated Name"
        })

      response = json_response(conn, 200)
      assert response["name"] == "Updated Name"
    end
  end

  describe "DELETE /api/v1/metric-definitions/:id" do
    test "deletes a metric definition not attached to experiments", %{conn: conn, tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "delete-metric",
          "name" => "Delete Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      conn = delete(conn, "/api/v1/metric-definitions/#{metric_def.id}")
      assert response(conn, 204)
    end

    test "returns 422 when deleting metric attached to experiment", %{conn: conn, tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "in-use-metric",
          "name" => "In Use Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      experiment =
        Repo.insert!(%ExperimentHub.Experiments.Experiment{
          tenant_id: tenant.id,
          key: "exp-for-metric",
          name: "Exp For Metric",
          hypothesis: "Test"
        })

      Metrics.attach_metric(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "metric_definition_id" => metric_def.id,
        "role" => "primary"
      })

      conn = delete(conn, "/api/v1/metric-definitions/#{metric_def.id}")
      assert json_response(conn, 422)["error"] == "metric_in_use"
    end
  end
end
