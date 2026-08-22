defmodule ExperimentHub.Repo.Migrations.CreateSharedReadouts do
  use Ecto.Migration

  @moduledoc """
  Shareable read-only experiment readouts (Roadmap #7).

  RLS note (deliberate deviation from the tenant_isolation idiom used by every
  other tenant_id-bearing table — see 20260401000023 for that pattern): this
  table is intentionally NOT given `ENABLE ROW LEVEL SECURITY` / a
  `tenant_isolation` policy.

  The public `GET /share/readout/:token` route is unauthenticated by design —
  a signed, unguessable Phoenix.Token IS the access-control mechanism, not
  tenant membership. That request never calls `Repo.put_tenant_id/1` (there is
  no tenant to set: the whole point is a link a person outside the tenant can
  open), so `current_setting('app.current_tenant_id')` would be unset on
  whatever pooled connection serves the request. Enforcing tenant_isolation
  here would either raise (fresh connection, GUC never set) or, worse, filter
  by whatever tenant happened to be left on a reused pooled connection from an
  unrelated prior request — silently 404ing a valid share link or, in the
  wrong circumstance, leaking a different tenant's row under the wrong
  context. Neither is acceptable for a read whose only real access check is
  "did you hold the token".

  Tenant isolation for this table is instead enforced entirely at the write
  path: `POST /experiments/:experiment_id/share-readout` is authenticated and
  tenant-scoped (ShareController.create looks the experiment up via
  `Experiments.get_experiment/1`, which is already tenant-scoped by
  `ExperimentHub.Repo`'s automatic query scoping — see repo.ex — so a
  cross-tenant experiment id resolves to `nil` and 404s before any row is
  ever inserted). `tenant_id` and `experiment_id` are kept as plain columns
  for auditing/reporting, not as an RLS boundary.
  """

  def change do
    create table(:shared_readouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing), null: false

      add :experiment_id, references(:experiments, type: :binary_id, on_delete: :delete_all),
        null: false

      add :html, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shared_readouts, [:tenant_id])
    create index(:shared_readouts, [:experiment_id])
  end
end
