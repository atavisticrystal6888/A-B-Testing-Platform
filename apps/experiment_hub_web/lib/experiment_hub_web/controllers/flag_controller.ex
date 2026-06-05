defmodule ExperimentHubWeb.FlagController do
  @moduledoc """
  SDK-facing flag evaluation endpoint (FR-125).
  GET /v1/flags/{flag_key} for client-side flag evaluation.
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.FeatureFlags.Evaluator

  def show(conn, %{"flag_key" => flag_key} = params) do
    tenant_id = conn.assigns[:tenant_id]
    user_id = params["user_id"] || ""
    user_attributes = params["attributes"] || %{}

    {:ok, enabled} = Evaluator.evaluate(tenant_id, flag_key, user_id, user_attributes)

    json(conn, %{
      flag_key: flag_key,
      enabled: enabled,
      user_id: user_id
    })
  end
end
