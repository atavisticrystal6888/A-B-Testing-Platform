defmodule ExperimentHub.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false, size: 255
      add :slug, :string, null: false, size: 100
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:slug])
  end
end
