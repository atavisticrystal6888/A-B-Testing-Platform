defmodule ExperimentHub.Repo.Migrations.CreateTargetingRules do
  use Ecto.Migration

  def change do
    create table(:targeting_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :attribute, :string, null: false
      add :operator, :string, null: false
      add :value, :map, null: false
      add :priority, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:targeting_rules, [:experiment_id])
    create index(:targeting_rules, [:tenant_id])

    execute(
      "ALTER TABLE targeting_rules ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE targeting_rules DISABLE ROW LEVEL SECURITY"
    )
  end
end
