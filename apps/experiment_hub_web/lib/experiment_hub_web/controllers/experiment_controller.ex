defmodule ExperimentHubWeb.ExperimentController do
  use ExperimentHubWeb, :controller

  alias ExperimentHub.Experiments

  action_fallback ExperimentHubWeb.FallbackController

  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id

    %{data: experiments, meta: meta} = Experiments.list_experiments(tenant_id, params)

    conn
    |> put_status(200)
    |> render(:index, experiments: experiments, meta: meta)
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
          "concluded_by" => conn.assigns[:current_user_id]
        }

        case Experiments.conclude_experiment(experiment, attrs) do
          {:ok, updated} ->
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
end
