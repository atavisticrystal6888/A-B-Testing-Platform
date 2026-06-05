defmodule ExperimentHub.Repo.Migrations.CreateExperimentMetrics do
  use Ecto.Migration

  def change do
    create table(:experiment_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :metric_definition_id, references(:metric_definitions, type: :binary_id, on_delete: :nothing), null: false
      add :role, :string, size: 20, null: false
      add :guardrail_threshold, :decimal
      add :guardrail_direction, :string, size: 10

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:experiment_metrics, [:tenant_id, :experiment_id, :metric_definition_id])
    create index(:experiment_metrics, [:experiment_id])

    execute(
      "ALTER TABLE experiment_metrics ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE experiment_metrics DISABLE ROW LEVEL SECURITY"
    )

    execute(
      """
      CREATE POLICY tenant_isolation ON experiment_metrics
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """,
      "DROP POLICY IF EXISTS tenant_isolation ON experiment_metrics"
    )
  end
end
