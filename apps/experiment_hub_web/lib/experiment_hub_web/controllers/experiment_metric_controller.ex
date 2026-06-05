defmodule ExperimentHubWeb.ExperimentMetricController do
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Metrics

  action_fallback ExperimentHubWeb.FallbackController

  def index(conn, %{"experiment_id" => experiment_id}) do
    experiment_metrics = Metrics.list_experiment_metrics(experiment_id)

    conn
    |> put_status(200)
    |> render(:index, experiment_metrics: experiment_metrics)
  end

  def create(conn, %{"experiment_id" => experiment_id} = params) do
    tenant_id = conn.assigns.tenant_id

    attrs =
      params
      |> Map.put("experiment_id", experiment_id)
      |> Map.put("tenant_id", tenant_id)

    case Metrics.attach_metric(attrs) do
      {:ok, experiment_metric} ->
        experiment_metric = ExperimentHub.Repo.preload(experiment_metric, :metric_definition)

        conn
        |> put_status(201)
        |> render(:show, experiment_metric: experiment_metric)

      {:error, :primary_metric_already_exists} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "primary_metric_exists",
          message:
            "Experiment already has a primary metric. Remove it first before adding a new one."
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    case Metrics.detach_metric(id) do
      {:ok, _} ->
        send_resp(conn, 204, "")

      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment metric not found"})
    end
  end
end
