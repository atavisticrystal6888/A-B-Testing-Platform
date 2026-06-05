defmodule ExperimentHub.Metrics.CustomMetric do
  @moduledoc """
  Custom metric definitions with formula support (FR-145).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @aggregation_types ~w(sum count average min max percentile_95 percentile_99 rate ratio)

  schema "custom_metrics" do
    field(:tenant_id, :binary_id)
    field(:name, :string)
    field(:key, :string)
    field(:description, :string)
    field(:aggregation_type, :string)
    field(:formula, :map)
    field(:unit, :string)
    field(:is_inverted, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(tenant_id name key aggregation_type)a
  @optional_fields ~w(description formula unit is_inverted)a

  def changeset(metric, attrs) do
    metric
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:aggregation_type, @aggregation_types)
    |> validate_format(:key, ~r/^[a-z][a-z0-9_.]{0,254}$/)
    |> unique_constraint([:tenant_id, :key])
  end
end
