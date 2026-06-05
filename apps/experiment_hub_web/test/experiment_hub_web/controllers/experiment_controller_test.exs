defmodule ExperimentHubWeb.ExperimentControllerTest do
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

    %{conn: conn, tenant: tenant, api_key: api_key}
  end

  # T045 - POST /api/v1/experiments
  describe "POST /api/v1/experiments" do
    test "creates experiment with variants", %{conn: conn} do
      params = %{
        "key" => "checkout-button-color",
        "name" => "Checkout Button Color Test",
        "hypothesis" => "Green button increases conversions by 5%",
        "feature_tag" => "checkout-page",
        "variants" => [
          %{
            "key" => "control",
            "name" => "Blue Button",
            "is_control" => true,
            "traffic_allocation" => 5000
          },
          %{
            "key" => "treatment",
            "name" => "Green Button",
            "is_control" => false,
            "traffic_allocation" => 5000
          }
        ]
      }

      conn = post(conn, "/api/v1/experiments", params)
      response = json_response(conn, 201)

      assert response["key"] == "checkout-button-color"
      assert response["name"] == "Checkout Button Color Test"
      assert response["hypothesis"] == "Green button increases conversions by 5%"
      assert response["feature_tag"] == "checkout-page"
      assert response["status"] == "draft"
      assert response["version"] == 1
      assert length(response["variants"]) == 2
      assert is_list(response["warnings"])
    end

    test "creates experiment without variants", %{conn: conn} do
      params = %{
        "key" => "minimal-test",
        "name" => "Minimal Test"
      }

      conn = post(conn, "/api/v1/experiments", params)
      response = json_response(conn, 201)

      assert response["key"] == "minimal-test"
      assert response["status"] == "draft"
      assert response["variants"] == []
    end

    test "returns 422 for invalid experiment key", %{conn: conn} do
      params = %{
        "key" => "INVALID KEY!",
        "name" => "Bad Key Test"
      }

      conn = post(conn, "/api/v1/experiments", params)
      assert json_response(conn, 422)["error"] == "validation_error"
    end

    test "returns 422 for missing required fields", %{conn: conn} do
      conn = post(conn, "/api/v1/experiments", %{})
      assert json_response(conn, 422)["error"] == "validation_error"
    end

    test "returns 422 for duplicate experiment key", %{conn: conn} do
      params = %{
        "key" => "duplicate-key",
        "name" => "First Experiment"
      }

      post(conn, "/api/v1/experiments", params)
      conn = post(conn, "/api/v1/experiments", params)

      assert json_response(conn, 422)["error"] == "validation_error"
    end

    test "returns warnings for overlapping feature_tag", %{conn: conn, tenant: tenant} do
      # Create a running experiment with same feature_tag
      Repo.insert!(%ExperimentHub.Experiments.Experiment{
        tenant_id: tenant.id,
        key: "existing-exp",
        name: "Existing Experiment",
        hypothesis: "Test",
        feature_tag: "checkout-page",
        status: "running"
      })

      params = %{
        "key" => "new-exp",
        "name" => "New Experiment",
        "feature_tag" => "checkout-page",
        "variants" => [
          %{
            "key" => "control",
            "name" => "Control",
            "is_control" => true,
            "traffic_allocation" => 5000
          },
          %{
            "key" => "treatment",
            "name" => "Treatment",
            "is_control" => false,
            "traffic_allocation" => 5000
          }
        ]
      }

      conn = post(conn, "/api/v1/experiments", params)
      response = json_response(conn, 201)

      assert length(response["warnings"]) > 0
      assert hd(response["warnings"])["type"] == "experiment_overlap"
    end
  end

  # T046 - GET /api/v1/experiments
  describe "GET /api/v1/experiments" do
    test "lists experiments with default pagination", %{conn: conn} do
      create_experiment(conn, "exp-1", "Experiment 1")
      create_experiment(conn, "exp-2", "Experiment 2")

      conn = get(conn, "/api/v1/experiments")
      response = json_response(conn, 200)

      assert is_list(response["data"])
      assert length(response["data"]) == 2
      assert response["meta"]["page"] == 1
      assert response["meta"]["total_count"] == 2
    end

    test "filters by status", %{conn: conn, tenant: tenant} do
      create_experiment(conn, "draft-exp", "Draft")

      Repo.insert!(%ExperimentHub.Experiments.Experiment{
        tenant_id: tenant.id,
        key: "running-exp",
        name: "Running",
        hypothesis: "Test",
        status: "running"
      })

      conn = get(conn, "/api/v1/experiments", %{"status" => "running"})
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["status"] == "running"
    end

    test "searches by name", %{conn: conn} do
      create_experiment(conn, "alpha-test", "Alpha Test")
      create_experiment(conn, "beta-test", "Beta Test")

      conn = get(conn, "/api/v1/experiments", %{"search" => "Alpha"})
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["name"] == "Alpha Test"
    end

    test "paginates results", %{conn: conn} do
      for i <- 1..5 do
        create_experiment(conn, "exp-page-#{i}", "Experiment #{i}")
      end

      conn = get(conn, "/api/v1/experiments", %{"page" => 1, "page_size" => 2})
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
      assert response["meta"]["page"] == 1
      assert response["meta"]["page_size"] == 2
      assert response["meta"]["total_count"] == 5
      assert response["meta"]["total_pages"] == 3
    end

    test "excludes archived experiments by default", %{conn: conn, tenant: tenant} do
      create_experiment(conn, "active-exp", "Active")

      Repo.insert!(%ExperimentHub.Experiments.Experiment{
        tenant_id: tenant.id,
        key: "archived-exp",
        name: "Archived",
        hypothesis: "Test",
        archived: true
      })

      conn = get(conn, "/api/v1/experiments")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert hd(response["data"])["key"] == "active-exp"
    end
  end

  # T047 - GET /api/v1/experiments/:id
  describe "GET /api/v1/experiments/:id" do
    test "shows experiment detail with variants and metrics", %{conn: conn, tenant: tenant} do
      experiment = create_experiment(conn, "detail-test", "Detail Test")

      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "test-metric",
          "name" => "Test Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      {:ok, _} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment["id"],
          "metric_definition_id" => metric_def.id,
          "role" => "primary"
        })

      conn = get(conn, "/api/v1/experiments/#{experiment["id"]}")
      response = json_response(conn, 200)

      assert response["id"] == experiment["id"]
      assert response["key"] == "detail-test"
      assert is_list(response["variants"])
      assert is_list(response["metrics"])
      assert length(response["metrics"]) == 1
      assert hd(response["metrics"])["role"] == "primary"
    end

    test "returns 404 for non-existent experiment", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/v1/experiments/#{fake_id}")

      assert json_response(conn, 404)["error"] == "not_found"
    end
  end

  # T048 - PUT /api/v1/experiments/:id
  describe "PUT /api/v1/experiments/:id" do
    test "updates experiment fields", %{conn: conn} do
      experiment = create_experiment(conn, "update-test", "Update Test")

      conn =
        put(conn, "/api/v1/experiments/#{experiment["id"]}", %{
          "name" => "Updated Name",
          "description" => "Updated description",
          "version" => experiment["version"]
        })

      response = json_response(conn, 200)

      assert response["name"] == "Updated Name"
      assert response["description"] == "Updated description"
    end

    test "returns 409 on stale version (optimistic locking)", %{conn: conn} do
      experiment = create_experiment(conn, "stale-test", "Stale Test")

      # First update succeeds
      put(conn, "/api/v1/experiments/#{experiment["id"]}", %{
        "name" => "First Update",
        "version" => experiment["version"]
      })

      # Second update with same version fails
      conn =
        put(conn, "/api/v1/experiments/#{experiment["id"]}", %{
          "name" => "Second Update",
          "version" => experiment["version"]
        })

      assert json_response(conn, 409)["error"] == "conflict"
    end

    test "returns 404 for non-existent experiment", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      conn = put(conn, "/api/v1/experiments/#{fake_id}", %{"name" => "Nope"})
      assert json_response(conn, 404)["error"] == "not_found"
    end
  end

  # State transition tests
  describe "POST /api/v1/experiments/:id/start" do
    test "starts a draft experiment with all preconditions met", %{conn: conn, tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "start-test-metric",
          "name" => "Start Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      experiment =
        create_experiment_with_variants(conn, "start-test", "Start Test", "Test hypothesis")

      {:ok, _} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment["id"],
          "metric_definition_id" => metric_def.id,
          "role" => "primary"
        })

      conn = post(conn, "/api/v1/experiments/#{experiment["id"]}/start")
      response = json_response(conn, 200)

      assert response["status"] == "running"
      assert response["started_at"] != nil
    end

    test "returns 422 when starting without primary metric", %{conn: conn} do
      experiment =
        create_experiment_with_variants(conn, "no-metric-start", "No Metric", "Hypothesis")

      conn = post(conn, "/api/v1/experiments/#{experiment["id"]}/start")
      response = json_response(conn, 422)

      assert response["error"] == "invalid_transition"
      assert "primary_metric_required" in response["violations"]
    end
  end

  describe "POST /api/v1/experiments/:id/pause" do
    test "returns 422 when pausing a draft experiment", %{conn: conn} do
      experiment = create_experiment(conn, "pause-draft", "Pause Draft")

      conn = post(conn, "/api/v1/experiments/#{experiment["id"]}/pause")
      assert json_response(conn, 422)["error"] == "invalid_transition"
    end
  end

  describe "POST /api/v1/experiments/:id/conclude" do
    test "returns 422 when concluding a draft experiment", %{conn: conn} do
      experiment = create_experiment(conn, "conclude-draft", "Conclude Draft")

      conn =
        post(conn, "/api/v1/experiments/#{experiment["id"]}/conclude", %{
          "decision" => "ship_variant",
          "rationale" => "Test"
        })

      assert json_response(conn, 422)["error"] == "invalid_transition"
    end
  end

  # Helpers

  defp create_experiment(conn, key, name) do
    conn = post(conn, "/api/v1/experiments", %{"key" => key, "name" => name})
    json_response(conn, 201)
  end

  defp create_experiment_with_variants(conn, key, name, hypothesis) do
    params = %{
      "key" => key,
      "name" => name,
      "hypothesis" => hypothesis,
      "variants" => [
        %{
          "key" => "control",
          "name" => "Control",
          "is_control" => true,
          "traffic_allocation" => 5000
        },
        %{
          "key" => "treatment",
          "name" => "Treatment",
          "is_control" => false,
          "traffic_allocation" => 5000
        }
      ]
    }

    conn = post(conn, "/api/v1/experiments", params)
    json_response(conn, 201)
  end
end
