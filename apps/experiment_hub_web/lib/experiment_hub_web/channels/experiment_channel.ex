defmodule ExperimentHubWeb.ExperimentChannel do
  @moduledoc """
  Phoenix Channel for live experiment updates (FR-157).
  Broadcasts result updates to subscribed dashboard clients.
  """
  use Phoenix.Channel

  @impl true
  def join("experiment:" <> experiment_id, _params, socket) do
    {:ok, assign(socket, :experiment_id, experiment_id)}
  end

  @impl true
  def handle_in("request_update", _payload, socket) do
    experiment_id = socket.assigns.experiment_id
    push(socket, "update_requested", %{experiment_id: experiment_id})
    {:noreply, socket}
  end

  @doc """
  Broadcast result update to all subscribers of an experiment channel.
  """
  def broadcast_result_update(experiment_id, results) do
    ExperimentHubWeb.Endpoint.broadcast(
      "experiment:#{experiment_id}",
      "results_updated",
      %{experiment_id: experiment_id, results: results}
    )
  end

  @doc """
  Broadcast state change to all subscribers of an experiment channel.
  """
  def broadcast_state_change(experiment_id, new_status) do
    ExperimentHubWeb.Endpoint.broadcast(
      "experiment:#{experiment_id}",
      "status_changed",
      %{experiment_id: experiment_id, status: new_status}
    )
  end
end
