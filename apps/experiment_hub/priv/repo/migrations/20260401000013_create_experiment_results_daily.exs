defmodule ExperimentHub.Repo.Migrations.CreateExperimentResultsDaily do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE experiment_results_daily (
      id UUID DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      experiment_id UUID NOT NULL,
      variant_id UUID NOT NULL,
      metric_definition_id UUID NOT NULL,
      date DATE NOT NULL,
      sample_size BIGINT NOT NULL DEFAULT 0,
      conversions BIGINT NOT NULL DEFAULT 0,
      sum_value DECIMAL NOT NULL DEFAULT 0,
      sum_squared_value DECIMAL NOT NULL DEFAULT 0,
      inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    ) PARTITION BY RANGE (date)
    """

    # Create current month partition
    {year, month, _} = Date.utc_today() |> Date.to_erl()
    {next_year, next_month} = if month == 12, do: {year + 1, 1}, else: {year, month + 1}
    partition = "experiment_results_daily_#{year}_#{String.pad_leading(to_string(month), 2, "0")}"

    execute """
    CREATE TABLE #{partition} PARTITION OF experiment_results_daily
    FOR VALUES FROM ('#{year}-#{String.pad_leading(to_string(month), 2, "0")}-01')
    TO ('#{next_year}-#{String.pad_leading(to_string(next_month), 2, "0")}-01')
    """

    execute "CREATE UNIQUE INDEX #{partition}_unique_idx ON #{partition} (tenant_id, experiment_id, variant_id, metric_definition_id, date)"
    execute "CREATE INDEX #{partition}_query_idx ON #{partition} (tenant_id, experiment_id, date)"

    execute "ALTER TABLE experiment_results_daily ENABLE ROW LEVEL SECURITY"
    execute """
    CREATE POLICY tenant_isolation ON experiment_results_daily
      USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS experiment_results_daily CASCADE"
  end
end
