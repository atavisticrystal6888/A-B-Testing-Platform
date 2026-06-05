defmodule ExperimentHub.Repo.Migrations.CreateVariants do
  use Ecto.Migration

  def change do
    create table(:variants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :string, size: 100, null: false
      add :name, :string, size: 255, null: false
      add :description, :text
      add :is_control, :boolean, null: false, default: false
      add :traffic_allocation, :integer, null: false
      add :sort_order, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:variants, [:tenant_id, :experiment_id, :key])
    create index(:variants, [:experiment_id])

    execute(
      "ALTER TABLE variants ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE variants DISABLE ROW LEVEL SECURITY"
    )

    execute(
      """
      CREATE POLICY tenant_isolation ON variants
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """,
      "DROP POLICY IF EXISTS tenant_isolation ON variants"
    )
  end
end
