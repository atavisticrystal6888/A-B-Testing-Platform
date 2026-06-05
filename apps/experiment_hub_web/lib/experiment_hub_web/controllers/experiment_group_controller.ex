defmodule ExperimentHubWeb.ExperimentGroupController do
  use ExperimentHubWeb, :controller
  action_fallback ExperimentHubWeb.FallbackController

  alias ExperimentHub.Experiments.ExperimentGroups

  def index(conn, _params) do
    tenant_id = conn.assigns[:tenant_id]
    groups = ExperimentGroups.list_groups(tenant_id)
    json(conn, %{data: Enum.map(groups, &format_group/1)})
  end

  def show(conn, %{"id" => id}) do
    group = ExperimentGroups.get_group!(id)
    json(conn, %{data: format_group(group)})
  end

  def create(conn, params) do
    tenant_id = conn.assigns[:tenant_id]
    attrs = Map.put(params, "tenant_id", tenant_id)

    case ExperimentGroups.create_group(attrs) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> json(%{data: format_group(group)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    group = ExperimentGroups.get_group!(id)

    case ExperimentGroups.update_group(group, params) do
      {:ok, group} ->
        json(conn, %{data: format_group(group)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    group = ExperimentGroups.get_group!(id)
    ExperimentGroups.delete_group(group)
    send_resp(conn, :no_content, "")
  end

  def add_experiment(conn, %{"group_id" => group_id, "experiment_id" => experiment_id}) do
    case ExperimentGroups.add_experiment(group_id, experiment_id) do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, changeset} -> {:error, changeset}
    end
  end

  def remove_experiment(conn, %{"group_id" => group_id, "experiment_id" => experiment_id}) do
    ExperimentGroups.remove_experiment(group_id, experiment_id)
    send_resp(conn, :no_content, "")
  end

  defp format_group(group) do
    %{
      id: group.id,
      name: group.name,
      description: group.description,
      experiments: format_experiments(group),
      inserted_at: group.inserted_at
    }
  end

  defp format_experiments(%{experiments: %Ecto.Association.NotLoaded{}}), do: []

  defp format_experiments(%{experiments: experiments}) do
    Enum.map(experiments, fn e ->
      %{id: e.id, name: e.name, key: e.key, status: e.status}
    end)
  end
end
