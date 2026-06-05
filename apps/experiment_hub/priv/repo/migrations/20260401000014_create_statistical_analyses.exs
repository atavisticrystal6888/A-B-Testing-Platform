defmodule ExperimentHub.Repo.Migrations.CreateStatisticalAnalyses do
  use Ecto.Migration

  def change do
    create table(:statistical_analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all), null: false
      add :metric_definition_id, references(:metric_definitions, type: :binary_id, on_delete: :delete_all), null: false
      add :analysis_type, :string, null: false, size: 20
      add :methodology, :string, null: false, size: 50
      add :parameters, :map, null: false, default: %{}
      add :results, :map, null: false, default: %{}
      add :sample_sizes, :map, null: false, default: %{}
      add :is_significant, :boolean
      add :winning_variant_id, references(:variants, type: :binary_id)
      add :computed_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:statistical_analyses, [:tenant_id, :experiment_id, :metric_definition_id, :computed_at])
    create index(:statistical_analyses, [:tenant_id, :experiment_id, :analysis_type])

    execute """
    ALTER TABLE statistical_analyses ENABLE ROW LEVEL SECURITY
    """,
    """
    ALTER TABLE statistical_analyses DISABLE ROW LEVEL SECURITY
    """

    execute """
    CREATE POLICY tenant_isolation ON statistical_analyses
      USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    """,
    """
    DROP POLICY IF EXISTS tenant_isolation ON statistical_analyses
    """
  end
end
