defmodule ExperimentHubWeb.ErrorView do
  @moduledoc """
  Standardized JSON error response format.

  All API errors follow this shape:
    %{error: "error_code", message: "Human-readable description", details: %{}}
  """

  def render_error(conn, status, error_code, message, details \\ %{}) do
    body = %{error: error_code, message: message}
    body = if details == %{}, do: body, else: Map.put(body, :details, details)

    conn
    |> Plug.Conn.put_status(status)
    |> Phoenix.Controller.json(body)
  end

  def not_found(conn, message \\ "Resource not found") do
    render_error(conn, 404, "not_found", message)
  end

  def unprocessable(conn, message, details \\ %{}) do
    render_error(conn, 422, "unprocessable_entity", message, details)
  end

  def conflict(conn, message, details \\ %{}) do
    render_error(conn, 409, "conflict", message, details)
  end

  def bad_request(conn, message, details \\ %{}) do
    render_error(conn, 400, "bad_request", message, details)
  end
end
