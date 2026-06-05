defmodule ExperimentHub.Repo.Migrations.AddFeatureTagToExperiments do
  use Ecto.Migration

  def change do
    alter table(:experiments) do
      add :feature_tag, :string, size: 100
    end

    create index(:experiments, [:tenant_id, :feature_tag, :status])
  end
end
