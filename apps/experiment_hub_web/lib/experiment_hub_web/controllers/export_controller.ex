defmodule ExperimentHubWeb.ExportController do
  @moduledoc """
  REST API for data export (FR-120).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Export

  def export_experiment(conn, %{"experiment_id" => experiment_id} = params) do
    format = params["format"] || "json"

    case Export.export_experiment(experiment_id, format) do
      {:ok, data} ->
        conn
        |> put_resp_content_type(content_type(format))
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"experiment_#{experiment_id}.#{format}\""
        )
        |> send_resp(200, data)

      {:error, :unsupported_format} ->
        conn
        |> put_status(400)
        |> json(%{error: "unsupported_format", message: "Supported formats: json, csv"})
    end
  end

  def export_results(conn, %{"experiment_id" => experiment_id} = params) do
    format = params["format"] || "csv"

    case Export.export_daily_results(experiment_id, format) do
      {:ok, data} ->
        conn
        |> put_resp_content_type(content_type(format))
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"results_#{experiment_id}.#{format}\""
        )
        |> send_resp(200, data)

      {:error, :unsupported_format} ->
        conn
        |> put_status(400)
        |> json(%{error: "unsupported_format"})
    end
  end

  defp content_type("csv"), do: "text/csv"
  defp content_type("json"), do: "application/json"
  defp content_type(_), do: "application/octet-stream"
end
