defmodule ExperimentHub.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :actor_id, :binary_id
      add :actor_type, :string, null: false
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id, null: false
      add :changes, :map, default: %{}
      add :reason, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:actor_id])
    create index(:audit_logs, [:inserted_at])

    execute(
      "ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY"
    )
  end
end
