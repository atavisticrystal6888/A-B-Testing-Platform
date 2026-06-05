defmodule ExperimentHubWeb.AssignController do
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Assignments

  action_fallback ExperimentHubWeb.FallbackController

  @doc """
  POST /v1/assign - Single assignment
  """
  def assign(conn, params) do
    with :ok <- validate_assign_params(params) do
      tenant_id = conn.assigns.tenant_id

      case Assignments.assign(tenant_id, params) do
        {:ok, result} ->
          conn
          |> put_status(200)
          |> json(%{
            experiment_key: result.experiment_key,
            variant_key: result.variant_key,
            variant_name: result.variant_name,
            experiment_id: result.experiment_id,
            variant_id: result.variant_id,
            is_control: result.is_control,
            enrolled: result.enrolled,
            assigned_at: result.assigned_at
          })

        {:error, :experiment_not_found} ->
          conn
          |> put_status(404)
          |> json(%{
            error: "experiment_not_found",
            message: "Experiment '#{params["experiment_key"]}' does not exist"
          })
      end
    else
      {:error, body} ->
        conn
        |> put_status(400)
        |> json(body)
    end
  end

  @doc """
  POST /v1/assign/batch - Batch assignment
  """
  def batch_assign(conn, params) do
    tenant_id = conn.assigns.tenant_id

    case Assignments.batch_assign(tenant_id, params) do
      {:ok, result} ->
        assignments =
          Enum.map(result.assignments, fn
            %{error: error} = a ->
              %{experiment_key: a.experiment_key, error: error}

            a ->
              %{
                experiment_key: a.experiment_key,
                variant_key: a.variant_key,
                experiment_id: a.experiment_id,
                variant_id: a.variant_id,
                is_control: a.is_control,
                enrolled: a.enrolled
              }
          end)

        conn
        |> put_status(200)
        |> json(%{
          user_id: result.user_id,
          assignments: assignments,
          assigned_at: result.assigned_at
        })
    end
  end

  defp validate_assign_params(params) do
    user_id = params["user_id"] || params[:user_id]
    experiment_key = params["experiment_key"] || params[:experiment_key]

    if is_binary(user_id) and user_id != "" and is_binary(experiment_key) and experiment_key != "" do
      :ok
    else
      {:error, %{error: "validation_error", message: "user_id and experiment_key are required"}}
    end
  end
end
