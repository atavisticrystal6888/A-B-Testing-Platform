defmodule ExperimentHub.Repo.Migrations.ExtendRowLevelSecurity do
  use Ecto.Migration

  @moduledoc """
  Completes tenant row-level security coverage across every table that carries
  a tenant_id column, using the same pattern as 20260401000004
  (ENABLE + tenant_isolation policy + FORCE).

  Pre-existing state this migration builds on:

    * users, api_keys                  — ENABLE + policy + FORCE (000004). Untouched here.
    * experiments, variants, metric_definitions, experiment_metrics,
      assignments, assignment_overrides, experiment_events_raw,
      experiment_results_daily, statistical_analyses
                                       — ENABLE + tenant_isolation policy were created in
                                         each table's own migration (000005..000014), but
                                         FORCE was never applied, so the owning role
                                         bypassed RLS entirely. This migration adds FORCE.
    * audit_logs, targeting_rules, exclusion_groups, tenant_settings,
      feature_flags, custom_metrics    — ENABLE was applied in their create migrations
                                         (000015..000020) but NO policy existed (default
                                         deny for non-owner roles, wide open for the owner
                                         without FORCE). This migration adds the
                                         tenant_isolation policy and FORCE.

  Partitioned tables (experiment_events_raw, experiment_results_daily):
  the policy lives on the partitioned PARENT. PostgreSQL applies the policies of
  the table named in the query, so every query routed through the parent — which
  is all application access, since the Ecto schemas name the parent tables —
  is filtered even when the planner scans child partitions. Direct SQL against a
  child partition would bypass the parent policy, but PartitionManagerWorker only
  CREATEs child partitions and never reads/writes them by name, so parent-level
  RLS suffices and the worker needs no per-partition RLS.

  Deliberately excluded (no tenant_id column):

    * tenants                     — root of the tenancy hierarchy; rows ARE the tenants.
    * exclusion_group_experiments — join table (exclusion_group_id, experiment_id) with no
                                    tenant_id; it is only reachable via its parents
                                    (exclusion_groups, experiments), both of which are
                                    RLS-protected, and both FK targets are unguessable
                                    UUIDs. Forcing a policy would require a subquery join
                                    in the policy expression rather than the standard
                                    tenant_id equality pattern.
    * oban_jobs / oban_peers      — global background-job infrastructure.
    * schema_migrations           — Ecto bookkeeping.
  """

  # ENABLE RLS + tenant_isolation policy already exist from each table's own
  # create migration; only FORCE (apply RLS to the table owner too) is missing.
  @forced_only ~w(
    experiments
    variants
    metric_definitions
    experiment_metrics
    assignments
    assignment_overrides
    experiment_events_raw
    experiment_results_daily
    statistical_analyses
  )

  # ENABLE RLS exists from the create migration, but no policy was ever created.
  @needs_policy ~w(
    audit_logs
    targeting_rules
    exclusion_groups
    tenant_settings
    feature_flags
    custom_metrics
  )

  def up do
    for table <- @needs_policy do
      # ENABLE is idempotent — already set in the create migrations, repeated
      # here so this migration is self-sufficient on databases restored from
      # a structure dump.
      execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY"

      execute """
      CREATE POLICY tenant_isolation ON #{table}
        USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
      """
    end

    for table <- @forced_only ++ @needs_policy do
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY"
    end
  end

  def down do
    for table <- @forced_only ++ @needs_policy do
      execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY"
    end

    for table <- @needs_policy do
      execute "DROP POLICY IF EXISTS tenant_isolation ON #{table}"
      # RLS stays ENABLEd — that came from each table's create migration,
      # not from this one.
    end
  end
end
