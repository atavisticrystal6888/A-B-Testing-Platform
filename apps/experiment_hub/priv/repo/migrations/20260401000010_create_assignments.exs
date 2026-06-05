defmodule ExperimentHub.Repo.Migrations.CreateAssignments do
  use Ecto.Migration

  def change do
    create table(:assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :variant_id, references(:variants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :string, null: false, size: 255

      add :assigned_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create unique_index(:assignments, [:tenant_id, :experiment_id, :user_id])
    create index(:assignments, [:tenant_id, :experiment_id, :variant_id])

    execute """
    ALTER TABLE assignments ENABLE ROW LEVEL SECURITY
    """,
    """
    ALTER TABLE assignments DISABLE ROW LEVEL SECURITY
    """

    execute """
    CREATE POLICY tenant_isolation ON assignments
      USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    """,
    """
    DROP POLICY IF EXISTS tenant_isolation ON assignments
    """
  end
end
