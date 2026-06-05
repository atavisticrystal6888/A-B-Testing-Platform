defmodule ExperimentHub.Metrics.ExperimentResultDaily do
  @moduledoc """
  Ecto schema for daily aggregated experiment results (partitioned table).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "experiment_results_daily" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:variant_id, :binary_id)
    field(:metric_definition_id, :binary_id)
    field(:date, :date)
    field(:sample_size, :integer, default: 0)
    field(:conversions, :integer, default: 0)
    field(:sum_value, :decimal, default: Decimal.new(0))
    field(:sum_squared_value, :decimal, default: Decimal.new(0))

    timestamps(type: :utc_datetime)
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :tenant_id,
      :experiment_id,
      :variant_id,
      :metric_definition_id,
      :date,
      :sample_size,
      :conversions,
      :sum_value,
      :sum_squared_value
    ])
    |> validate_required([
      :tenant_id,
      :experiment_id,
      :variant_id,
      :metric_definition_id,
      :date
    ])
    |> unique_constraint([:tenant_id, :experiment_id, :variant_id, :metric_definition_id, :date])
  end
end
