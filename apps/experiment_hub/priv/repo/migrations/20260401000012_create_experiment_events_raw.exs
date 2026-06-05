defmodule ExperimentHub.Repo.Migrations.CreateExperimentEventsRaw do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE experiment_events_raw (
      id UUID DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      experiment_id UUID NOT NULL,
      variant_id UUID NOT NULL,
      user_id VARCHAR(255) NOT NULL,
      event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('conversion', 'metric', 'revenue')),
      event_name VARCHAR(100) NOT NULL,
      value DECIMAL,
      properties JSONB DEFAULT '{}',
      idempotency_key VARCHAR(255) NOT NULL,
      is_bot BOOLEAN NOT NULL DEFAULT false,
      is_post_conclusion BOOLEAN NOT NULL DEFAULT false,
      timestamp TIMESTAMPTZ NOT NULL,
      inserted_at TIMESTAMPTZ NOT NULL DEFAULT now()
    ) PARTITION BY RANGE (inserted_at)
    """

    # Create current month partition
    {year, month, _} = Date.utc_today() |> Date.to_erl()
    {next_year, next_month} = if month == 12, do: {year + 1, 1}, else: {year, month + 1}
    partition_name = "experiment_events_raw_#{year}_#{String.pad_leading(to_string(month), 2, "0")}"

    execute """
    CREATE TABLE #{partition_name} PARTITION OF experiment_events_raw
    FOR VALUES FROM ('#{year}-#{String.pad_leading(to_string(month), 2, "0")}-01')
    TO ('#{next_year}-#{String.pad_leading(to_string(next_month), 2, "0")}-01')
    """

    # Indexes on partition
    execute "CREATE UNIQUE INDEX #{partition_name}_dedup_idx ON #{partition_name} (tenant_id, idempotency_key)"
    execute "CREATE INDEX #{partition_name}_query_idx ON #{partition_name} (tenant_id, experiment_id, inserted_at)"
    execute "CREATE INDEX #{partition_name}_agg_idx ON #{partition_name} (tenant_id, experiment_id, variant_id, event_name)"

    # RLS
    execute "ALTER TABLE experiment_events_raw ENABLE ROW LEVEL SECURITY"

    execute """
    CREATE POLICY tenant_isolation ON experiment_events_raw
      USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS experiment_events_raw CASCADE"
  end
end
