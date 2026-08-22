defmodule ExperimentHubWeb.ShareController do
  @moduledoc """
  Shareable, read-only experiment readout links (Roadmap #7).

  `create/2` is authenticated + tenant-scoped: it stores the client-generated
  readout HTML (from `buildReadoutHtml` in the dashboard) against the
  experiment and hands back a link built from a signed Phoenix.Token — the
  token IS the capability, so `show/2` is deliberately public with no auth
  and no tenant scoping (see the moduledoc on migration 20260401000025 and
  on `ExperimentHub.Experiments.SharedReadout` for why).
  """
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Experiments
  alias ExperimentHub.Experiments.SharedReadout

  @salt "shared-readout"
  # Product call: share links are read-only capability links, not accounts —
  # 30 days balances "long enough to be useful for a stakeholder review
  # cycle" against "not a permanent, unrevocable leak surface".
  @max_age_seconds 30 * 24 * 3600

  @doc """
  POST /api/v1/experiments/:experiment_id/share-readout
  Body: `{"html" => html}`. Stores the readout and returns a public share
  URL. 404 if the experiment doesn't belong to the caller's tenant; 422 if
  the HTML exceeds the 2MB cap (enforced by SharedReadout.changeset).
  """
  def create(conn, %{"experiment_id" => experiment_id} = params) do
    case Experiments.get_experiment(experiment_id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        attrs = %{
          "tenant_id" => experiment.tenant_id,
          "experiment_id" => experiment.id,
          "html" => Map.get(params, "html")
        }

        case Experiments.create_shared_readout(attrs) do
          {:ok, shared_readout} ->
            conn
            |> put_status(201)
            |> json(%{data: %{url: share_url(shared_readout.id)}})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_error", errors: format_changeset_errors(changeset)})
        end
    end
  end

  @doc """
  GET /share/readout/:token — public, unauthenticated. Serves the stored
  HTML verbatim when the token is valid and unexpired and the row still
  exists; otherwise 404 JSON. No information is given away about *why* it
  failed (tampered, expired, or deleted all look identical) — the point of
  a capability token is that it doesn't leak state to someone without one.
  """
  def show(conn, %{"token" => token}) do
    with {:ok, id} <- Phoenix.Token.verify(endpoint(), @salt, token, max_age: @max_age_seconds),
         %SharedReadout{} = shared_readout <- safe_get(id) do
      conn
      |> put_resp_header("x-robots-tag", "noindex")
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none'; style-src 'unsafe-inline'"
      )
      |> put_resp_content_type("text/html")
      |> send_resp(200, shared_readout.html)
    else
      _ -> not_found(conn)
    end
  end

  defp safe_get(id) do
    Experiments.get_shared_readout(id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> json(%{error: "not_found", message: "Shared readout not found"})
  end

  defp share_url(shared_readout_id) do
    token = Phoenix.Token.sign(endpoint(), @salt, shared_readout_id)
    endpoint().url() <> "/share/readout/" <> token
  end

  defp endpoint, do: ExperimentHubWeb.Endpoint

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
