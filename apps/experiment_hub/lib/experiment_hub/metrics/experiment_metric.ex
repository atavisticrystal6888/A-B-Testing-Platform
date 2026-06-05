defmodule ExperimentHub.Metrics.ExperimentMetric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(primary secondary guardrail)
  @guardrail_directions ~w(above below)

  schema "experiment_metrics" do
    field(:tenant_id, :binary_id)
    field(:role, :string)
    field(:guardrail_threshold, :decimal)
    field(:guardrail_direction, :string)

    belongs_to(:experiment, ExperimentHub.Experiments.Experiment)
    belongs_to(:metric_definition, ExperimentHub.Metrics.MetricDefinition)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(experiment_metric, attrs) do
    experiment_metric
    |> cast(attrs, [
      :tenant_id,
      :experiment_id,
      :metric_definition_id,
      :role,
      :guardrail_threshold,
      :guardrail_direction
    ])
    |> validate_required([:tenant_id, :experiment_id, :metric_definition_id, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_guardrail_fields()
    |> unique_constraint([:tenant_id, :experiment_id, :metric_definition_id])
  end

  defp validate_guardrail_fields(changeset) do
    case get_field(changeset, :role) do
      "guardrail" ->
        changeset
        |> validate_required([:guardrail_threshold, :guardrail_direction])
        |> validate_inclusion(:guardrail_direction, @guardrail_directions)

      _ ->
        changeset
    end
  end

  def roles, do: @roles
end
