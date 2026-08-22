defmodule ExperimentHubWeb.ExperimentController do
  use ExperimentHubWeb, :controller

  alias ExperimentHub.{AuditLog, Experiments}
  alias ExperimentHub.Metrics

  action_fallback ExperimentHubWeb.FallbackController

  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id

    %{data: experiments, meta: meta} = Experiments.list_experiments(tenant_id, params)
    # One extra pair of queries for the whole page, not one per experiment.
    projections = Metrics.latest_primary_projections(Enum.map(experiments, & &1.id))

    conn
    |> put_status(200)
    |> render(:index, experiments: experiments, meta: meta, projections: projections)
  end

  def show(conn, %{"id" => id}) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        conn
        |> put_status(200)
        |> render(:show, experiment: experiment)
    end
  end

  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.put(params, "tenant_id", tenant_id)

    case Experiments.create_experiment(attrs) do
      {:ok, experiment, warnings} ->
        conn
        |> put_status(201)
        |> render(:show_with_warnings, experiment: experiment, warnings: warnings)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_error", errors: format_changeset_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        case Experiments.update_experiment(experiment, params) do
          {:ok, updated} ->
            conn
            |> put_status(200)
            |> render(:show, experiment: Experiments.get_experiment!(updated.id))

          {:error, :stale} ->
            current = Experiments.get_experiment!(experiment.id)

            conn
            |> put_status(409)
            |> json(%{
              error: "conflict",
              message: "Experiment was modified by another user. Please refresh and try again.",
              current_version: current.version
            })

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_error", errors: format_changeset_errors(changeset)})
        end
    end
  end

  def start(conn, %{"id" => id}) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        case Experiments.start_experiment(experiment) do
          {:ok, updated} ->
            log_lifecycle_event(conn, experiment, updated, "started")

            conn
            |> put_status(200)
            |> render(:transition, experiment: updated)

          {:error, violations} when is_list(violations) ->
            conn
            |> put_status(422)
            |> json(%{
              error: "invalid_transition",
              message: "Cannot start experiment: pre-conditions not met",
              violations: violations
            })

          {:error, message} when is_binary(message) ->
            conn
            |> put_status(422)
            |> json(%{error: "invalid_transition", message: message, violations: []})
        end
    end
  end

  def pause(conn, %{"id" => id}) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        case Experiments.pause_experiment(experiment) do
          {:ok, updated} ->
            log_lifecycle_event(conn, experiment, updated, "paused")

            conn
            |> put_status(200)
            |> render(:transition, experiment: updated)

          {:error, message} when is_binary(message) ->
            conn
            |> put_status(422)
            |> json(%{error: "invalid_transition", message: message, violations: []})
        end
    end
  end

  def resume(conn, %{"id" => id}) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        case Experiments.resume_experiment(experiment) do
          {:ok, updated} ->
            log_lifecycle_event(conn, experiment, updated, "resumed")

            conn
            |> put_status(200)
            |> render(:transition, experiment: updated)

          {:error, message} when is_binary(message) ->
            conn
            |> put_status(422)
            |> json(%{error: "invalid_transition", message: message, violations: []})
        end
    end
  end

  def conclude(conn, %{"id" => id} = params) do
    case Experiments.get_experiment(id) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "not_found", message: "Experiment not found"})

      experiment ->
        attrs = %{
          "conclusion_decision" => params["decision"],
          "conclusion_rationale" => params["rationale"],
          "winner_variant_id" => params["winner_variant_id"],
          "concluded_by" => conn.assigns[:current_user_id]
        }

        case Experiments.conclude_experiment(experiment, attrs) do
          {:ok, updated} ->
            log_conclusion(conn, experiment, updated, params)

            conn
            |> put_status(200)
            |> render(:transition, experiment: updated)

          {:error, message} when is_binary(message) ->
            conn
            |> put_status(422)
            |> json(%{error: "invalid_transition", message: message, violations: []})
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Writes the audit trail for API-driven lifecycle transitions. This is
  # intentionally scoped to this controller rather than the shared
  # `Experiments.start_experiment/1` etc. context functions: those are also
  # called by Oban workers (ScheduledStartWorker, ExperimentScheduler,
  # GuardrailWorker) and `demo_seeds.ex`, which already write their own
  # differently-named audit entries ("scheduled_start", "guardrail_breach",
  # the demo_seed rows) right after calling them — logging inside the shared
  # functions too would double-log every one of those paths. `conclude`
  # doesn't share this risk (its own path, `ConclusionService`, never calls
  # `Experiments.conclude_experiment/2`), but it's logged the same way here
  # for consistency.
  defp log_lifecycle_event(conn, experiment, updated, action) do
    AuditLog.log_experiment_change(
      updated,
      action,
      actor_opts(conn) ++ [changes: %{status: %{from: experiment.status, to: updated.status}}]
    )
  end

  defp log_conclusion(conn, experiment, updated, params) do
    AuditLog.log_experiment_change(
      updated,
      "concluded",
      actor_opts(conn) ++
        [
          reason: params["rationale"],
          changes: %{
            status: %{from: experiment.status, to: updated.status},
            conclusion_decision: params["decision"],
            winner_variant_id: params["winner_variant_id"]
          }
        ]
    )
  end

  # Mirrors how other writers (ConclusionService, the Oban workers) populate
  # actor_id/actor_type: a dashboard session user is "user", an API-key
  # caller is "api_key" (a valid ExperimentHub.AuditLog actor_type),
  # anything else (shouldn't happen behind :api_authenticated) falls back to
  # "system".
  defp actor_opts(conn) do
    cond do
      conn.assigns[:current_user_id] ->
        [actor_id: conn.assigns.current_user_id, actor_type: "user"]

      conn.assigns[:api_key] ->
        [actor_id: conn.assigns.api_key.id, actor_type: "api_key"]

      true ->
        [actor_id: nil, actor_type: "system"]
    end
  end
end
