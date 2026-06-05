defmodule ExperimentHub.Experiments do
  @moduledoc """
  The Experiments context. Manages experiments, variants, and state transitions.
  """

  import Ecto.Query
  require Logger

  alias ExperimentHub.Repo
  alias ExperimentHub.Workers.AnalysisWorker

  alias ExperimentHub.Experiments.{
    Experiment,
    Variant,
    StateMachine,
    LaunchValidator,
    OverlapDetector
  }

  # --- Experiments ---

  @doc """
  Lists experiments for the current tenant with optional filtering and pagination.

  Options:
  - `:status` - filter by status
  - `:archived` - include archived (default: false)
  - `:search` - search by name or key
  - `:sort` - sort field (default: "inserted_at")
  - `:order` - sort order (default: "desc")
  - `:page` - page number (default: 1)
  - `:page_size` - items per page (default: 20, max: 100)
  """
  def list_experiments(tenant_id, opts \\ %{}) do
    page = opts |> get_integer_opt("page", 1) |> max(1)
    page_size = opts |> get_integer_opt("page_size", 20) |> min(100) |> max(1)
    offset = (page - 1) * page_size

    query =
      Experiment
      |> where(tenant_id: ^tenant_id)
      |> filter_by_status(opts)
      |> filter_by_archived(opts)
      |> filter_by_search(opts)
      |> apply_sort(opts)

    total_count = Repo.aggregate(query, :count)
    total_pages = ceil(total_count / page_size)

    experiments =
      query
      |> limit(^page_size)
      |> offset(^offset)
      |> preload(:variants)
      |> Repo.all()

    %{
      data: experiments,
      meta: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages
      }
    }
  end

  defp filter_by_status(query, %{"status" => status}) when is_binary(status) do
    where(query, status: ^status)
  end

  defp filter_by_status(query, _), do: query

  defp filter_by_archived(query, %{"archived" => true}), do: query

  defp filter_by_archived(query, _) do
    where(query, archived: false)
  end

  defp filter_by_search(query, %{"search" => search}) when is_binary(search) and search != "" do
    pattern = "%#{search}%"
    where(query, [e], ilike(e.name, ^pattern) or ilike(e.key, ^pattern))
  end

  defp filter_by_search(query, _), do: query

  defp apply_sort(query, opts) do
    field = Map.get(opts, "sort", "inserted_at")
    order = if Map.get(opts, "order", "desc") == "asc", do: :asc, else: :desc

    case field do
      "name" -> order_by(query, [e], [{^order, e.name}])
      "status" -> order_by(query, [e], [{^order, e.status}])
      "started_at" -> order_by(query, [e], [{^order, e.started_at}])
      _ -> order_by(query, [e], [{^order, e.inserted_at}])
    end
  end

  @doc """
  Gets a single experiment by ID, preloading variants and experiment_metrics.
  """
  def get_experiment(id) do
    Experiment
    |> preload([:variants, experiment_metrics: :metric_definition])
    |> Repo.get(id)
  end

  def get_experiment!(id) do
    Experiment
    |> preload([:variants, experiment_metrics: :metric_definition])
    |> Repo.get!(id)
  end

  @doc """
  Creates an experiment with nested variants.
  Returns `{:ok, experiment, warnings}` or `{:error, changeset}`.
  """
  def create_experiment(attrs) do
    tenant_id = attrs["tenant_id"]
    variants_attrs = attrs["variants"] || []

    Repo.transaction(fn ->
      case insert_experiment(attrs) do
        {:ok, experiment} ->
          case insert_variants(experiment, tenant_id, variants_attrs) do
            {:ok, variants} ->
              experiment = %{experiment | variants: variants}

              warnings =
                OverlapDetector.check_overlaps(experiment.id, experiment.feature_tag, tenant_id)

              {experiment, warnings}

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {experiment, warnings}} -> {:ok, experiment, warnings}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp insert_experiment(attrs) do
    %Experiment{}
    |> Experiment.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_variants(_experiment, _tenant_id, []), do: {:ok, []}

  defp insert_variants(experiment, tenant_id, variants_attrs) do
    results =
      Enum.map(variants_attrs, fn variant_attrs ->
        %Variant{}
        |> Variant.changeset(
          Map.merge(variant_attrs, %{
            "experiment_id" => experiment.id,
            "tenant_id" => tenant_id
          })
        )
        |> Repo.insert()
      end)

    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil -> {:ok, Enum.map(results, fn {:ok, v} -> v end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an experiment with optimistic locking.
  Returns `{:ok, experiment}`, `{:error, changeset}`, or `{:error, :stale}`.
  """
  def update_experiment(%Experiment{} = experiment, attrs) do
    with :ok <- validate_version_match(experiment, attrs) do
      experiment
      |> Experiment.update_changeset(attrs)
      |> Repo.update()
    end
  end

  # --- State Transitions ---

  @doc """
  Starts an experiment (draft → running).
  Validates launch pre-conditions first.
  """
  def start_experiment(%Experiment{} = experiment) do
    with :ok <- StateMachine.validate_transition(experiment.status, "running"),
         :ok <- LaunchValidator.validate(experiment),
         {:ok, updated} <-
           experiment
           |> Experiment.transition_changeset(%{
             "status" => "running",
             "started_at" => DateTime.utc_now() |> DateTime.truncate(:second)
           })
           |> Repo.update() do
      maybe_schedule_analysis(updated)
      {:ok, updated}
    end
  end

  @doc """
  Enqueues an analysis run for an experiment when Oban is available.
  """
  def schedule_analysis(%Experiment{} = experiment) do
    if Application.get_env(:experiment_hub, :start_oban, true) do
      try do
        Oban.insert(
          AnalysisWorker.new(%{
            experiment_id: experiment.id,
            tenant_id: experiment.tenant_id
          })
        )
      rescue
        error -> {:error, error}
      catch
        :exit, reason -> {:error, reason}
      end
    else
      {:error, :disabled}
    end
  end

  @doc """
  Pauses a running experiment (running → paused).
  """
  def pause_experiment(%Experiment{} = experiment) do
    with :ok <- StateMachine.validate_transition(experiment.status, "paused") do
      experiment
      |> Experiment.transition_changeset(%{"status" => "paused"})
      |> Repo.update()
    end
  end

  @doc """
  Resumes a paused experiment (paused → running).
  """
  def resume_experiment(%Experiment{} = experiment) do
    with :ok <- StateMachine.validate_transition(experiment.status, "running"),
         {:ok, updated} <-
           experiment
           |> Experiment.transition_changeset(%{"status" => "running"})
           |> Repo.update() do
      maybe_schedule_analysis(updated)
      {:ok, updated}
    end
  end

  @doc """
  Concludes a running or paused experiment.
  """
  def conclude_experiment(%Experiment{} = experiment, attrs) do
    with :ok <- StateMachine.validate_transition(experiment.status, "concluded") do
      experiment
      |> Experiment.conclude_changeset(
        Map.merge(attrs, %{
          "status" => "concluded",
          "concluded_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
      )
      |> Repo.update()
    end
  end

  defp get_integer_opt(opts, key, default) do
    case Map.get(opts, key, default) do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _rest} -> parsed
          :error -> default
        end

      _ ->
        default
    end
  end

  defp maybe_schedule_analysis(%Experiment{} = experiment) do
    case schedule_analysis(experiment) do
      {:ok, _job} ->
        :ok

      {:error, :disabled} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to schedule analysis for experiment #{experiment.id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp validate_version_match(%Experiment{version: current_version}, attrs) do
    case Map.get(attrs, "version") || Map.get(attrs, :version) do
      nil ->
        :ok

      ^current_version ->
        :ok

      value when is_binary(value) ->
        case Integer.parse(value) do
          {^current_version, _rest} -> :ok
          _ -> {:error, :stale}
        end

      _ ->
        {:error, :stale}
    end
  end
end
