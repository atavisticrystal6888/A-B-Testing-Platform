defmodule ExperimentHub.Repo.Migrations.EnableRowLevelSecurity do
  use Ecto.Migration

  def up do
    # Enable RLS on all tenant-scoped tables
    for table <- ~w(users api_keys) do
      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY"

      execute """
      CREATE POLICY tenant_isolation ON #{table}
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """

      # Ensure the table owner (migration user) bypasses RLS
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY"
    end
  end

  def down do
    for table <- ~w(users api_keys) do
      execute "DROP POLICY IF EXISTS tenant_isolation ON #{table}"
      execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY"
    end
  end
end
