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
      {tenant_id, schema} when is_binary(tenant_id) and is_atom(schema) ->
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
