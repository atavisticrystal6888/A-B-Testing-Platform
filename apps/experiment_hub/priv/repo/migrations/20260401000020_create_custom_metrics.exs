defmodule ExperimentHub.Repo.Migrations.CreateCustomMetrics do
  use Ecto.Migration

  def change do
    create table(:custom_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :name, :string, null: false
      add :key, :string, null: false
      add :description, :text
      add :aggregation_type, :string, null: false
      add :formula, :map
      add :unit, :string
      add :is_inverted, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:custom_metrics, [:tenant_id, :key])
    create index(:custom_metrics, [:tenant_id])

    execute(
      "ALTER TABLE custom_metrics ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE custom_metrics DISABLE ROW LEVEL SECURITY"
    )
  end
end
