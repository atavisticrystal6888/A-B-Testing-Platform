defmodule ExperimentHubWeb.ResultsControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.{Metrics, Repo}
  alias ExperimentHub.Metrics.StatisticalAnalysis

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

  describe "GET /api/v1/experiments/:experiment_id/results" do
    test "returns a pending payload when no analysis exists", %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/results")
      response = json_response(conn, 200)

      assert response["experiment_id"] == experiment.id
      assert response["overall_status"] == "pending"
      assert response["has_sufficient_data"] == false
      assert response["guardrail_breaches"] == []
      assert response["metrics"] == []
    end

    test "returns persisted analysis results when available", %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, metric_definition} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "signup_conversion",
          "name" => "Signup Conversion",
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

      %StatisticalAnalysis{}
      |> StatisticalAnalysis.changeset(%{
        tenant_id: tenant.id,
        experiment_id: experiment.id,
        metric_definition_id: metric_definition.id,
        analysis_type: "frequentist",
        methodology: "z_test_proportions",
        parameters: %{"significance_level" => 0.05},
        results: %{
          "test_method" => "z_test_proportions",
          "p_value" => 0.031,
          "confidence_level" => 0.95,
          "confidence_interval" => %{
            "lower" => 0.01,
            "upper" => 0.05,
            "point_estimate" => 0.03
          },
          "effect_size" => %{
            "absolute" => 0.03,
            "relative" => 0.2
          },
          "power_achieved" => 0.81,
          "is_significant" => true
        },
        sample_sizes: %{"control" => 1000, "treatment" => 1000},
        is_significant: true
      })
      |> Repo.insert!()

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/results")
      response = json_response(conn, 200)

      assert response["experiment_id"] == experiment.id
      assert response["overall_status"] == "sufficient_data"
      assert response["has_sufficient_data"] == true

      assert [metric] = response["metrics"]
      assert metric["metric_key"] == "signup_conversion"
      assert metric["role"] == "primary"
      assert metric["frequentist"]["p_value"] == 0.031
      assert Enum.map(metric["variants"], & &1["sample_size"]) == [1000, 1000]
    end

    test "returns fully persisted metric payloads with insufficient-data status", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, metric_definition} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "checkout_conversion",
          "name" => "Checkout Conversion",
          "metric_type" => "count",
          "definition" => %{"event_name" => "checkout_completed"}
        })

      {:ok, _experiment_metric} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric_definition.id,
          "role" => "primary"
        })

      %StatisticalAnalysis{}
      |> StatisticalAnalysis.changeset(%{
        tenant_id: tenant.id,
        experiment_id: experiment.id,
        metric_definition_id: metric_definition.id,
        analysis_type: "frequentist",
        methodology: "z_test_proportions",
        parameters: %{significance_level: 0.05},
        results: %{
          "metric_key" => "checkout_conversion",
          "metric_type" => "count",
          "role" => "primary",
          "variants" => [
            %{"variant_key" => "control", "sample_size" => 250, "conversion_rate" => 0.1},
            %{"variant_key" => "treatment", "sample_size" => 250, "conversion_rate" => 0.12}
          ],
          "frequentist" => %{
            "test_method" => "z_test_proportions",
            "p_value" => 0.11,
            "confidence_level" => 0.95,
            "confidence_interval" => %{
              "lower" => -0.01,
              "upper" => 0.05,
              "point_estimate" => 0.02
            },
            "effect_size" => %{
              "absolute" => 0.02,
              "relative" => 0.2
            },
            "power_achieved" => 0.64,
            "is_significant" => false
          },
          "sample_size_calculation" => %{
            "minimum_required" => 500,
            "current_total" => 500,
            "is_sufficient" => false,
            "baseline_rate" => 0.1,
            "minimum_detectable_effect" => 0.02,
            "power" => 0.8,
            "significance_level" => 0.05
          },
          "recommendation" => %{
            "action" => "insufficient_data",
            "message" => "Collect more samples before making a decision."
          }
        },
        sample_sizes: %{"control" => 250, "treatment" => 250},
        is_significant: false
      })
      |> Repo.insert!()

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/results")
      response = json_response(conn, 200)

      assert response["overall_status"] == "insufficient_data"
      assert response["has_sufficient_data"] == false

      assert [metric] = response["metrics"]
      assert metric["recommendation"]["action"] == "insufficient_data"
      assert Enum.map(metric["variants"], & &1["conversion_rate"]) == [0.1, 0.12]
      assert metric["sample_size_calculation"]["is_sufficient"] == false
    end
  end

  describe "POST /api/v1/experiments/:experiment_id/analyze" do
    test "returns service unavailable when analysis queue is disabled", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      conn = post(conn, "/api/v1/experiments/#{experiment.id}/analyze")
      response = json_response(conn, 503)

      assert response["error"] == "service_unavailable"
      assert response["message"] =~ "Analysis queue is unavailable"
    end
  end
end
