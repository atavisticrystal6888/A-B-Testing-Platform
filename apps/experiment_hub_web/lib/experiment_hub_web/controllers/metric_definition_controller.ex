defmodule ExperimentHubWeb.MetricDefinitionController do
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Metrics

  action_fallback ExperimentHubWeb.FallbackController

  def index(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    metric_definitions = Metrics.list_metric_definitions(tenant_id)

    conn
    |> put_status(200)
    |> render(:index, metric_definitions: metric_definitions)
  end

  def show(conn, %{"id" => id}) do
    case Metrics.get_metric_definition(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Metric definition not found"})

      metric_definition ->
        conn
        |> put_status(200)
        |> render(:show, metric_definition: metric_definition)
    end
  end

  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.put(params, "tenant_id", tenant_id)

    case Metrics.create_metric_definition(attrs) do
      {:ok, metric_definition} ->
        conn
        |> put_status(201)
        |> render(:show, metric_definition: metric_definition)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Metrics.get_metric_definition(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Metric definition not found"})

      metric_definition ->
        case Metrics.update_metric_definition(metric_definition, params) do
          {:ok, updated} ->
            conn
            |> put_status(200)
            |> render(:show, metric_definition: updated)

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Metrics.get_metric_definition(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Metric definition not found"})

      metric_definition ->
        case Metrics.delete_metric_definition(metric_definition) do
          {:ok, _} ->
            send_resp(conn, 204, "")

          {:error, :metric_in_use} ->
            conn
            |> put_status(422)
            |> json(%{
              error: "metric_in_use",
              message: "Cannot delete metric definition that is attached to experiments"
            })
        end
    end
  end
end
