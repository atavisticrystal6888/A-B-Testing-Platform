defmodule ExperimentHub.Metrics.StatisticalAnalysis do
  @moduledoc """
  Ecto schema for statistical analysis results.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @analysis_types ~w(frequentist bayesian sequential)

  schema "statistical_analyses" do
    field(:tenant_id, :binary_id)
    field(:experiment_id, :binary_id)
    field(:metric_definition_id, :binary_id)
    field(:analysis_type, :string)
    field(:methodology, :string)
    field(:parameters, :map, default: %{})
    field(:results, :map, default: %{})
    field(:sample_sizes, :map, default: %{})
    field(:is_significant, :boolean)
    field(:winning_variant_id, :binary_id)
    field(:computed_at, :utc_datetime)
  end

  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [
      :tenant_id,
      :experiment_id,
      :metric_definition_id,
      :analysis_type,
      :methodology,
      :parameters,
      :results,
      :sample_sizes,
      :is_significant,
      :winning_variant_id,
      :computed_at
    ])
    |> validate_required([
      :tenant_id,
      :experiment_id,
      :metric_definition_id,
      :analysis_type,
      :methodology,
      :parameters,
      :results,
      :sample_sizes
    ])
    |> validate_inclusion(:analysis_type, @analysis_types)
    |> put_computed_at()
  end

  defp put_computed_at(changeset) do
    if get_field(changeset, :computed_at) do
      changeset
    else
      put_change(changeset, :computed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end
end
