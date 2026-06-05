defmodule ExperimentHub.Repo.Migrations.CreateTenantSettings do
  use Ecto.Migration

  def change do
    create table(:tenant_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :max_concurrent_experiments, :integer, default: 100
      add :max_traffic_percentage, :integer, default: 10_000
      add :default_analysis_method, :string, default: "frequentist"
      add :default_confidence_level, :float, default: 0.95
      add :data_retention_days, :integer, default: 365
      add :enable_bayesian, :boolean, default: false
      add :enable_sequential, :boolean, default: false
      add :enable_feature_flags, :boolean, default: true
      add :custom_config, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenant_settings, [:tenant_id])

    execute(
      "ALTER TABLE tenant_settings ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE tenant_settings DISABLE ROW LEVEL SECURITY"
    )
  end
end
