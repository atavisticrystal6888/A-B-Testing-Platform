defmodule ExperimentHub.Tenants.TenantSettings do
  @moduledoc """
  Tenant-level configuration settings (FR-115).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tenant_settings" do
    field(:tenant_id, :binary_id)
    field(:max_concurrent_experiments, :integer, default: 100)
    field(:max_traffic_percentage, :integer, default: 10_000)
    field(:default_analysis_method, :string, default: "frequentist")
    field(:default_confidence_level, :float, default: 0.95)
    field(:data_retention_days, :integer, default: 365)
    field(:enable_bayesian, :boolean, default: false)
    field(:enable_sequential, :boolean, default: false)
    field(:enable_feature_flags, :boolean, default: true)
    field(:custom_config, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [
      :tenant_id,
      :max_concurrent_experiments,
      :max_traffic_percentage,
      :default_analysis_method,
      :default_confidence_level,
      :data_retention_days,
      :enable_bayesian,
      :enable_sequential,
      :enable_feature_flags,
      :custom_config
    ])
    |> validate_required([:tenant_id])
    |> validate_number(:max_concurrent_experiments, greater_than: 0)
    |> validate_number(:default_confidence_level, greater_than: 0.5, less_than: 1.0)
    |> validate_inclusion(:default_analysis_method, ~w(frequentist bayesian sequential))
    |> unique_constraint(:tenant_id)
  end
end
