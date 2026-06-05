defmodule ExperimentHub.Repo.Migrations.CreateFeatureFlags do
  use Ecto.Migration

  def change do
    create table(:feature_flags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "disabled"
      add :rollout_percentage, :integer, default: 10_000
      add :targeting_rules, {:array, :map}, default: []
      add :metadata, :map, default: %{}
      add :stale_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:feature_flags, [:tenant_id, :key])
    create index(:feature_flags, [:tenant_id])
    create index(:feature_flags, [:status])

    execute(
      "ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE feature_flags DISABLE ROW LEVEL SECURITY"
    )
  end
end
