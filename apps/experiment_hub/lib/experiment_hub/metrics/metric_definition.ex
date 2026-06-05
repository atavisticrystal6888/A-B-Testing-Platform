defmodule ExperimentHub.Metrics.MetricDefinition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @metric_types ~w(count ratio sum funnel)

  schema "metric_definitions" do
    field(:tenant_id, :binary_id)
    field(:key, :string)
    field(:name, :string)
    field(:description, :string)
    field(:metric_type, :string)
    field(:definition, :map)

    has_many(:experiment_metrics, ExperimentHub.Metrics.ExperimentMetric)

    timestamps(type: :utc_datetime)
  end

  def changeset(metric_definition, attrs) do
    metric_definition
    |> cast(attrs, [:tenant_id, :key, :name, :description, :metric_type, :definition])
    |> validate_required([:tenant_id, :key, :name, :metric_type, :definition])
    |> validate_length(:key, max: 100)
    |> validate_length(:name, max: 255)
    |> validate_format(:key, ~r/^[a-z0-9][a-z0-9_-]*[a-z0-9]$|^[a-z0-9]$/,
      message: "must be URL-safe lowercase"
    )
    |> validate_inclusion(:metric_type, @metric_types)
    |> unique_constraint([:tenant_id, :key])
  end

  def update_changeset(metric_definition, attrs) do
    metric_definition
    |> cast(attrs, [:name, :description, :metric_type, :definition])
    |> validate_length(:name, max: 255)
    |> validate_inclusion(:metric_type, @metric_types)
  end

  def metric_types, do: @metric_types
end
