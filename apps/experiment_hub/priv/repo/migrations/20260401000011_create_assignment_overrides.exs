defmodule ExperimentHub.Repo.Migrations.CreateAssignmentOverrides do
  use Ecto.Migration

  def change do
    create table(:assignment_overrides, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :variant_id, references(:variants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :string, null: false, size: 255
      add :reason, :string, size: 500

      timestamps(type: :utc_datetime)
    end

    create unique_index(:assignment_overrides, [:tenant_id, :experiment_id, :user_id])

    execute """
    ALTER TABLE assignment_overrides ENABLE ROW LEVEL SECURITY
    """,
    """
    ALTER TABLE assignment_overrides DISABLE ROW LEVEL SECURITY
    """

    execute """
    CREATE POLICY tenant_isolation ON assignment_overrides
      USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    """,
    """
    DROP POLICY IF EXISTS tenant_isolation ON assignment_overrides
    """
  end
end
