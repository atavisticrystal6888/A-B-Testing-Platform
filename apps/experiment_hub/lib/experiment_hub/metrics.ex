defmodule ExperimentHub.Metrics do
  @moduledoc """
  The Metrics context. Manages metric definitions and experiment-metric associations.
  """

  import Ecto.Query
  alias ExperimentHub.Repo

  alias ExperimentHub.Metrics.{
    MetricDefinition,
    ExperimentMetric,
    ExperimentResultDaily,
    StatisticalAnalysis
  }

  # --- Metric Definitions ---

  def list_metric_definitions(tenant_id) do
    MetricDefinition
    |> where(tenant_id: ^tenant_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_metric_definition(id), do: Repo.get(MetricDefinition, id)

  def get_metric_definition!(id), do: Repo.get!(MetricDefinition, id)

  def get_metric_definition_by_key(tenant_id, key) do
    Repo.get_by(MetricDefinition, tenant_id: tenant_id, key: key)
  end

  def create_metric_definition(attrs) do
    %MetricDefinition{}
    |> MetricDefinition.changeset(attrs)
    |> Repo.insert()
  end

  def update_metric_definition(%MetricDefinition{} = metric_def, attrs) do
    metric_def
    |> MetricDefinition.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a metric definition only if it's not attached to any experiment.
  """
  def delete_metric_definition(%MetricDefinition{} = metric_def) do
    attached_count =
      ExperimentMetric
      |> where(metric_definition_id: ^metric_def.id)
      |> Repo.aggregate(:count)

    if attached_count > 0 do
      {:error, :metric_in_use}
    else
      Repo.delete(metric_def)
    end
  end

  # --- Experiment Metrics ---

  def list_experiment_metrics(experiment_id) do
    ExperimentMetric
    |> where(experiment_id: ^experiment_id)
    |> preload(:metric_definition)
    |> Repo.all()
  end

  @doc """
  Attaches a metric definition to an experiment.
  Enforces that only one primary metric can exist per experiment.
  """
  def attach_metric(attrs) do
    role = attrs["role"]

    if role == "primary" do
      existing_primary =
        ExperimentMetric
        |> where(experiment_id: ^attrs["experiment_id"], role: "primary")
        |> Repo.exists?()

      if existing_primary do
        {:error, :primary_metric_already_exists}
      else
        do_attach_metric(attrs)
      end
    else
      do_attach_metric(attrs)
    end
  end

  defp do_attach_metric(attrs) do
    %ExperimentMetric{}
    |> ExperimentMetric.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Detaches a metric from an experiment.
  """
  def detach_metric(id) do
    case Repo.get(ExperimentMetric, id) do
      nil -> {:error, :not_found}
      experiment_metric -> Repo.delete(experiment_metric)
    end
  end

  @doc """
  Days-to-significance projection for each experiment's primary metric, read
  from the latest persisted `StatisticalAnalysis`. Returns
  `%{experiment_id => projection_map | nil}`, nil-safe throughout (missing
  primary metric, no persisted analysis yet, or an analysis predating this
  feature all resolve to nil rather than raising).

  Runs exactly two queries regardless of how many experiment_ids are passed,
  so callers rendering a page of experiments avoid an N+1 per row.
  """
  def latest_primary_projections([]), do: %{}

  def latest_primary_projections(experiment_ids) when is_list(experiment_ids) do
    primary_metric_ids =
      ExperimentMetric
      |> where([em], em.experiment_id in ^experiment_ids and em.role == "primary")
      |> select([em], {em.experiment_id, em.metric_definition_id})
      |> Repo.all()
      |> Map.new()

    if primary_metric_ids == %{} do
      %{}
    else
      exp_ids = Map.keys(primary_metric_ids)
      metric_ids = primary_metric_ids |> Map.values() |> Enum.uniq()

      # Scoped to primary-metric analyses only, and de-duped to the newest
      # row per {experiment_id, metric_definition_id} directly in SQL (via
      # DISTINCT ON, expressed as distinct/order_by below) rather than
      # pulling every historical analysis row back to pick the latest in
      # Elixir — this stays O(experiments) in rows fetched regardless of how
      # many analyses have piled up for a long-running experiment.
      latest_analysis_by_key =
        StatisticalAnalysis
        |> where(
          [sa],
          sa.experiment_id in ^exp_ids and sa.metric_definition_id in ^metric_ids
        )
        |> order_by([sa],
          asc: sa.experiment_id,
          asc: sa.metric_definition_id,
          desc: sa.computed_at
        )
        |> distinct([sa], [sa.experiment_id, sa.metric_definition_id])
        |> select([sa], %{
          experiment_id: sa.experiment_id,
          metric_definition_id: sa.metric_definition_id,
          results: sa.results
        })
        |> Repo.all()
        |> Map.new(fn row -> {{row.experiment_id, row.metric_definition_id}, row.results} end)

      Map.new(primary_metric_ids, fn {experiment_id, metric_definition_id} ->
        projection =
          case Map.get(latest_analysis_by_key, {experiment_id, metric_definition_id}) do
            nil -> nil
            results -> get_in(results, ["projection"])
          end

        {experiment_id, projection}
      end)
    end
  end

  @doc """
  Daily conversion rollups for an experiment's PRIMARY metric, sourced from
  `ExperimentResultDaily` (the `experiment_results_daily` partitioned table).

  Expects `experiment` to have `:experiment_metrics` preloaded (with
  `:metric_definition`), as returned by `Experiments.get_experiment/1` — the
  same struct the timeline/results controllers already load, so callers don't
  pay for an extra query just to resolve the primary metric.

  Returns `%{metric_key: nil, metric_name: nil, series: []}` when the
  experiment has no primary metric attached, and `series: []` (with the
  metric identified) when a primary metric exists but no rollups have been
  computed for it yet. Otherwise returns one series entry per date
  (ascending), each carrying every variant's sample_size, conversions, and
  conversion_rate (`conversions / sample_size`, `nil` when sample_size is 0
  rather than dividing by zero).
  """
  def daily_primary_results(experiment) do
    case Enum.find(experiment.experiment_metrics, &(&1.role == "primary")) do
      nil ->
        %{metric_key: nil, metric_name: nil, series: []}

      %ExperimentMetric{metric_definition: metric_definition} = experiment_metric ->
        series =
          experiment_metric.metric_definition_id
          |> daily_rollup_rows(experiment)
          |> Enum.group_by(& &1.date)
          |> Enum.sort_by(fn {date, _rows} -> date end, {:asc, Date})
          |> Enum.map(fn {date, rows} ->
            %{
              date: Date.to_iso8601(date),
              variants:
                Enum.map(rows, fn row ->
                  %{
                    variant_key: row.variant_key,
                    sample_size: row.sample_size,
                    conversions: row.conversions,
                    conversion_rate: conversion_rate(row.sample_size, row.conversions)
                  }
                end)
            }
          end)

        %{
          metric_key: metric_definition.key,
          metric_name: metric_definition.name,
          series: series
        }
    end
  end

  defp daily_rollup_rows(metric_definition_id, experiment) do
    from(r in ExperimentResultDaily,
      join: v in ExperimentHub.Experiments.Variant,
      on: v.id == r.variant_id,
      where:
        r.tenant_id == ^experiment.tenant_id and
          r.experiment_id == ^experiment.id and
          r.metric_definition_id == ^metric_definition_id,
      order_by: [asc: r.date, asc: v.sort_order, asc: v.key],
      select: %{
        date: r.date,
        variant_key: v.key,
        sample_size: r.sample_size,
        conversions: r.conversions
      }
    )
    |> Repo.all()
  end

  defp conversion_rate(0, _conversions), do: nil
  defp conversion_rate(sample_size, conversions), do: conversions / sample_size
end
