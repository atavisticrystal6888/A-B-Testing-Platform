defmodule ExperimentHub.FeatureFlags.FlagCache do
  @moduledoc """
  Redis caching for feature flag config (FR-125).
  Key pattern: flag:{tenant_id}:{flag_key} with 5-min TTL.
  """

  @ttl_seconds 300

  @doc """
  Get cached flag config or fetch from DB.
  """
  def get_or_fetch(tenant_id, flag_key, fetch_fn) do
    cache_key = "flag:#{tenant_id}:#{flag_key}"

    case get_cached(cache_key) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        case fetch_fn.() do
          {:ok, value} ->
            put_cached(cache_key, value)
            {:ok, value}

          error ->
            error
        end
    end
  end

  @doc """
  Invalidate cached flag.
  """
  def invalidate(tenant_id, flag_key) do
    cache_key = "flag:#{tenant_id}:#{flag_key}"

    try do
      Redix.command(:redix, ["DEL", cache_key])
    rescue
      _ -> :ok
    end
  end

  defp get_cached(key) do
    try do
      case Redix.command(:redix, ["GET", key]) do
        {:ok, nil} -> :miss
        {:ok, data} -> {:ok, Jason.decode!(data)}
        _ -> :miss
      end
    rescue
      _ -> :miss
    end
  end

  defp put_cached(key, value) do
    try do
      encoded = Jason.encode!(value)
      Redix.command(:redix, ["SET", key, encoded, "EX", @ttl_seconds])
    rescue
      _ -> :ok
    end
  end
end
