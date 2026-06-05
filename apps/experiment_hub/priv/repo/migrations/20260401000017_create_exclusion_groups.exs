defmodule ExperimentHub.Repo.Migrations.CreateExclusionGroups do
  use Ecto.Migration

  def change do
    create table(:exclusion_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exclusion_groups, [:tenant_id, :name])

    create table(:exclusion_group_experiments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :exclusion_group_id, references(:exclusion_groups, type: :binary_id, on_delete: :delete_all), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exclusion_group_experiments, [:exclusion_group_id, :experiment_id])
    create index(:exclusion_group_experiments, [:experiment_id])

    execute(
      "ALTER TABLE exclusion_groups ENABLE ROW LEVEL SECURITY",
      "ALTER TABLE exclusion_groups DISABLE ROW LEVEL SECURITY"
    )
  end
end
