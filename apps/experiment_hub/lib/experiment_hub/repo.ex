defmodule ExperimentHub.Repo do
  use Ecto.Repo,
    otp_app: :experiment_hub,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query

  @tenant_key {__MODULE__, :tenant_id}

  @doc """
  Sets the tenant context for tenant-scoped queries and best-effort RLS policies.
  """
  def put_tenant_id(tenant_id) when is_binary(tenant_id) do
    case Ecto.UUID.cast(tenant_id) do
      {:ok, valid_uuid} ->
        Process.put(@tenant_key, valid_uuid)
        query!("SELECT set_config('app.current_tenant_id', $1, false)", [valid_uuid])
        :ok

      :error ->
        raise ArgumentError, "invalid tenant_id: must be a valid UUID"
    end
  end

  @doc """
  Clears the tenant context: the per-process value used by
  `prepare_query/3`, and the Postgres session GUC RLS policies read.

  Callers (`ExperimentHubWeb.Plugs.TenantContext`'s `before_send` hook,
  Oban workers after `put_tenant_id/1`) call this once their unit of work
  finishes, so a pooled connection doesn't carry one tenant's id into the
  next, unrelated caller that reuses it.

  Residual risk (documented, not fixed here — see the fixes report for
  why a full fix needs an architectural change this task intentionally
  does not make): `set_config(..., false)` is session-scoped because nothing
  wraps the request/job in an explicit transaction, so `SET LOCAL` isn't an
  option. Outside a transaction, Ecto/DBConnection checks a connection out
  of the pool per query, not once per request — so `put_tenant_id/1` and a
  later query in the *same* request are not guaranteed to run on the *same*
  physical connection, and this function's own `RESET` query is subject to
  the same pool checkout as anything else. This closes the common case (a
  connection that goes idle at the end of a request/job keeps a tenant id
  forever); it does not guarantee every query in every request lands on a
  connection that has *this* request's tenant id and no other's for RLS
  purposes. `prepare_query/3`'s process-dictionary scoping is unaffected by
  any of this — it dies with the request process, not the connection.
  """
  def clear_tenant_id do
    Process.delete(@tenant_key)

    case query("RESET app.current_tenant_id", []) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  def current_tenant_id do
    Process.get(@tenant_key)
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    if opts[:skip_tenant_scope] do
      {query, opts}
    else
      {maybe_scope_query(query), opts}
    end
  end

  defp maybe_scope_query(%Ecto.Query{} = query) do
    case {current_tenant_id(), tenant_scoped_schema(query)} do
      # tenant_scoped_schema/1 returns nil for schemas with no :tenant_id
      # field (e.g. Oban.Job) — and is_atom(nil) is true, so this guard
      # must exclude nil explicitly or every query on a non-tenant schema
      # gets a `where tenant_id == ...` injected and blows up with an
      # undefined-column error the moment any tenant context is active.
      {tenant_id, schema} when is_binary(tenant_id) and is_atom(schema) and not is_nil(schema) ->
        where(query, [record], field(record, :tenant_id) == ^tenant_id)

      _ ->
        query
    end
  end

  defp tenant_scoped_schema(%Ecto.Query{from: %{source: {_source, schema}}})
       when is_atom(schema) do
    if function_exported?(schema, :__schema__, 1) and :tenant_id in schema.__schema__(:fields) do
      schema
    end
  end

  defp tenant_scoped_schema(_query), do: nil
end
