defmodule ExperimentHub.Metrics do
  @moduledoc """
  The Metrics context. Manages metric definitions and experiment-metric associations.
  """

  import Ecto.Query
  alias ExperimentHub.Repo
  alias ExperimentHub.Metrics.{MetricDefinition, ExperimentMetric}

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
end
