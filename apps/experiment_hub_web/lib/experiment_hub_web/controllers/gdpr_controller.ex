defmodule ExperimentHubWeb.GDPRController do
  @moduledoc """
  REST API for GDPR compliance operations (FR-300).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.GDPR

  def erase(conn, params) do
    case fetch_user_id(params) do
      {:ok, user_id} ->
        tenant_id = conn.assigns[:current_scope].tenant_id

        case GDPR.erase_user_data(tenant_id, user_id) do
          {:ok, result} ->
            json(conn, %{data: result})

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{error: "erasure_failed", message: inspect(reason)})
        end

      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "validation_error", message: "user_id is required"})
    end
  end

  def export(conn, params) do
    case fetch_user_id(params) do
      {:ok, user_id} ->
        tenant_id = conn.assigns[:current_scope].tenant_id
        data = GDPR.export_user_data(tenant_id, user_id)

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"user_data_#{user_id}.json\""
        )
        |> json(%{data: data})

      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "validation_error", message: "user_id is required"})
    end
  end

  defp fetch_user_id(%{"user_id" => user_id}) when is_binary(user_id) and user_id != "",
    do: {:ok, user_id}

  defp fetch_user_id(_params), do: :error
end
