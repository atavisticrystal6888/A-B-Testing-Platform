defmodule ExperimentHubWeb.DailyResultsControllerTest do
  use ExperimentHubWeb.ConnCase, async: true

  alias ExperimentHub.Metrics
  alias ExperimentHub.Metrics.ExperimentResultDaily
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

  defp insert_rollup!(
         tenant,
         experiment,
         variant,
         metric_definition,
         date,
         sample_size,
         conversions
       ) do
    %ExperimentResultDaily{}
    |> ExperimentResultDaily.changeset(%{
      "tenant_id" => tenant.id,
      "experiment_id" => experiment.id,
      "variant_id" => variant.id,
      "metric_definition_id" => metric_definition.id,
      "date" => date,
      "sample_size" => sample_size,
      "conversions" => conversions
    })
    |> Repo.insert!()
  end

  describe "GET /api/v1/experiments/:experiment_id/daily-results" do
    test "returns daily rollups for the primary metric, ordered by date, with per-variant conversion rate",
         %{conn: conn, tenant: tenant} do
      experiment = experiment_fixture(tenant: tenant)

      control =
        variant_fixture(experiment: experiment, tenant: tenant, key: "control", is_control: true)

      treatment =
        variant_fixture(
          experiment: experiment,
          tenant: tenant,
          key: "treatment",
          is_control: false
        )

      {:ok, metric_definition} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "signup-rate",
          "name" => "Signup Rate",
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

      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      insert_rollup!(tenant, experiment, control, metric_definition, yesterday, 100, 10)
      insert_rollup!(tenant, experiment, treatment, metric_definition, yesterday, 100, 20)
      insert_rollup!(tenant, experiment, control, metric_definition, today, 0, 0)
      insert_rollup!(tenant, experiment, treatment, metric_definition, today, 200, 40)

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/daily-results")
      response = json_response(conn, 200)
      data = response["data"]

      assert data["metric_key"] == "signup-rate"
      assert data["metric_name"] == "Signup Rate"

      series = data["series"]
      assert length(series) == 2

      assert Enum.map(series, & &1["date"]) == [
               Date.to_iso8601(yesterday),
               Date.to_iso8601(today)
             ]

      yesterday_entry = Enum.find(series, &(&1["date"] == Date.to_iso8601(yesterday)))

      control_yesterday =
        Enum.find(yesterday_entry["variants"], &(&1["variant_key"] == "control"))

      treatment_yesterday =
        Enum.find(yesterday_entry["variants"], &(&1["variant_key"] == "treatment"))

      assert control_yesterday["sample_size"] == 100
      assert control_yesterday["conversions"] == 10
      assert control_yesterday["conversion_rate"] == 0.1

      assert treatment_yesterday["sample_size"] == 100
      assert treatment_yesterday["conversions"] == 20
      assert treatment_yesterday["conversion_rate"] == 0.2

      today_entry = Enum.find(series, &(&1["date"] == Date.to_iso8601(today)))
      control_today = Enum.find(today_entry["variants"], &(&1["variant_key"] == "control"))

      # sample_size = 0 must yield a nil conversion_rate rather than dividing by zero.
      assert control_today["sample_size"] == 0
      assert control_today["conversion_rate"] == nil
    end

    test "returns empty series when the experiment has no primary metric", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/daily-results")
      data = json_response(conn, 200)["data"]

      assert data["metric_key"] == nil
      assert data["metric_name"] == nil
      assert data["series"] == []
    end

    test "returns empty series when the primary metric has no daily rollups yet", %{
      conn: conn,
      tenant: tenant
    } do
      experiment = experiment_fixture(tenant: tenant)

      {:ok, metric_definition} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "no-data-metric",
          "name" => "No Data Metric",
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

      conn = get(conn, "/api/v1/experiments/#{experiment.id}/daily-results")
      data = json_response(conn, 200)["data"]

      assert data["metric_key"] == "no-data-metric"
      assert data["metric_name"] == "No Data Metric"
      assert data["series"] == []
    end

    test "returns 404 for a different tenant's experiment", %{conn: conn} do
      other_tenant = tenant_fixture()
      other_experiment = experiment_fixture(tenant: other_tenant)

      conn = get(conn, "/api/v1/experiments/#{other_experiment.id}/daily-results")

      assert json_response(conn, 404)["error"] == "not_found"
    end
  end
end
