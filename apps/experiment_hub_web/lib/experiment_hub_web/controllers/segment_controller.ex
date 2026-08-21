defmodule ExperimentHubWeb.SegmentController do
  @moduledoc """
  Descriptive per-segment result breakdowns
  (`GET /api/v1/experiments/:experiment_id/segments?attribute=country`).
  Splits by an attribute captured at assignment time; defaults to the
  experiment's primary metric unless `metric_definition_id` is given.
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.{Experiments, Metrics, Repo}
  alias ExperimentHub.Metrics.Segments

  def index(conn, %{"experiment_id" => experiment_id, "attribute" => attribute} = params) do
    # Cast up front: a malformed id should be a 404, not an Ecto.Query.CastError 500.
    with {:uuid, {:ok, _}} <- {:uuid, Ecto.UUID.cast(experiment_id)},
         {:experiment, %{} = experiment} <-
           {:experiment, Experiments.get_experiment(experiment_id)},
         {:metric, %{} = experiment_metric} <-
           {:metric, resolve_metric(experiment_id, params["metric_definition_id"])} do
      experiment = Repo.preload(experiment, :variants)

      case Segments.breakdown(experiment, experiment_metric, attribute) do
        {:ok, segments} ->
          json(conn, %{
            data: %{
              attribute: attribute,
              metric_key: experiment_metric.metric_definition.key,
              metric_name: experiment_metric.metric_definition.name,
              note:
                "Descriptive breakdown only — per-segment differences are not significance-tested.",
              segments: segments
            }
          })

        {:error, :invalid_attribute} ->
          conn
          |> put_status(422)
          |> json(%{
            error: "invalid_attribute",
            message: "attribute must be 1-64 chars of letters, digits, _, ., or -"
          })
      end
    else
      {:uuid, :error} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      {:experiment, nil} ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      {:metric, nil} ->
        conn
        |> put_status(422)
        |> json(%{
          error: "no_metric",
          message: "No metric to segment. Attach a primary metric or pass metric_definition_id."
        })
    end
  end

  def index(conn, _params) do
    conn
    |> put_status(422)
    |> json(%{error: "missing_attribute", message: "attribute query parameter is required"})
  end

  defp resolve_metric(experiment_id, nil) do
    experiment_id
    |> Metrics.list_experiment_metrics()
    |> Enum.find(&(&1.role == "primary"))
  end

  defp resolve_metric(experiment_id, metric_definition_id) do
    experiment_id
    |> Metrics.list_experiment_metrics()
    |> Enum.find(&(&1.metric_definition_id == metric_definition_id))
  end
end
