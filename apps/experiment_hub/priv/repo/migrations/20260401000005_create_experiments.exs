defmodule ExperimentHub.Repo.Migrations.CreateExperiments do
  use Ecto.Migration

  def change do
    create table(:experiments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing), null: false
      add :experiment_group_id, :binary_id
      add :key, :string, size: 100, null: false
      add :name, :string, size: 255, null: false
      add :hypothesis, :text
      add :description, :text
      add :status, :string, size: 20, null: false, default: "draft"
      add :conclusion_decision, :string, size: 20
      add :conclusion_rationale, :text
      add :concluded_by, :binary_id
      add :scheduled_start_at, :utc_datetime
      add :scheduled_end_at, :utc_datetime
      add :started_at, :utc_datetime
      add :concluded_at, :utc_datetime
      add :version, :integer, null: false, default: 1
      add :archived, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiments, [:tenant_id, :key])
    create index(:experiments, [:tenant_id, :status])
    create index(:experiments, [:tenant_id, :experiment_group_id])
    create index(:experiments, [:tenant_id, :archived, :status])

    execute(
      "ALTER TABLE experiments ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE experiments DISABLE ROW LEVEL SECURITY"
    )

    execute(
      """
      CREATE POLICY tenant_isolation ON experiments
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """,
      "DROP POLICY IF EXISTS tenant_isolation ON experiments"
    )
  end
end
