defmodule ExperimentHub.Tenants.ApiKeyGenerator do
  @moduledoc """
  Generates cryptographically secure API keys with the `eh_live_` prefix
  and SHA-256 hashing for storage.
  """

  @prefix "eh_live_"
  @key_byte_length 32

  @doc """
  Generates a new API key. Returns `{raw_key, key_prefix, key_hash}`.
  The raw key is shown once at creation and never stored.
  """
  def generate do
    random_part = :crypto.strong_rand_bytes(@key_byte_length) |> Base.url_encode64(padding: false)
    raw_key = @prefix <> random_part
    key_hash = hash_key(raw_key)
    key_prefix = String.slice(raw_key, 0, 8)

    {raw_key, key_prefix, key_hash}
  end

  @doc """
  Hashes an API key with SHA-256 for storage/lookup.
  """
  def hash_key(raw_key) when is_binary(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end
end
