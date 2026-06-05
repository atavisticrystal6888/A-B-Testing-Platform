defmodule ExperimentHubWeb.UserSocket do
  @moduledoc """
  Phoenix socket for WebSocket connections from the dashboard (FR-157).
  """
  use Phoenix.Socket

  channel "experiment:*", ExperimentHubWeb.ExperimentChannel

  alias ExperimentHubWeb.Plugs.SessionAuth

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case SessionAuth.verify_token(token) do
      {:ok, claims} ->
        {:ok,
         socket
         |> assign(:user_id, claims["sub"])
         |> assign(:tenant_id, claims["tenant_id"])
         |> assign(:role, claims["role"])}

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
