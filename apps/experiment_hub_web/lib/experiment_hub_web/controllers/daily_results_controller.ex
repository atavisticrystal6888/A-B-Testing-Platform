defmodule ExperimentHubWeb.DailyResultsController do
  @moduledoc """
  Serves daily conversion rollups for an experiment's PRIMARY metric, so the
  dashboard can plot real per-day, per-variant conversion rates instead of
  fabricating them client-side.
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.{Experiments, Metrics}

  @doc """
  GET /api/v1/experiments/:experiment_id/daily-results
  """
  def show(conn, %{"experiment_id" => experiment_id}) do
    case Experiments.get_experiment(experiment_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        conn
        |> put_status(200)
        |> json(%{data: Metrics.daily_primary_results(experiment)})
    end
  end
end
