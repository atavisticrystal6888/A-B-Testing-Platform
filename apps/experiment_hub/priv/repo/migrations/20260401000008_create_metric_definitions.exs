defmodule ExperimentHub.Repo.Migrations.CreateMetricDefinitions do
  use Ecto.Migration

  def change do
    create table(:metric_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing), null: false
      add :key, :string, size: 100, null: false
      add :name, :string, size: 255, null: false
      add :description, :text
      add :metric_type, :string, size: 20, null: false
      add :definition, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:metric_definitions, [:tenant_id, :key])
    create index(:metric_definitions, [:tenant_id])

    execute(
      "ALTER TABLE metric_definitions ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE metric_definitions DISABLE ROW LEVEL SECURITY"
    )

    execute(
      """
      CREATE POLICY tenant_isolation ON metric_definitions
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """,
      "DROP POLICY IF EXISTS tenant_isolation ON metric_definitions"
    )
  end
end
