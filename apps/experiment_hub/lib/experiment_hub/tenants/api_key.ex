defmodule ExperimentHub.Tenants.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field(:key_prefix, :string)
    field(:key_hash, :string, redact: true)
    field(:name, :string)
    field(:expires_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)
    field(:last_used_at, :utc_datetime)
    field(:tenant_id, :binary_id)

    # Virtual field to hold the raw key (shown once at creation)
    field(:raw_key, :string, virtual: true, redact: true)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :tenant_id, :key_prefix, :key_hash, :expires_at])
    |> validate_required([:name, :tenant_id, :key_prefix, :key_hash])
    |> validate_length(:name, max: 255)
    |> unique_constraint(:key_hash)
  end

  def active?(%__MODULE__{revoked_at: revoked_at, expires_at: expires_at}) do
    is_nil(revoked_at) and
      (is_nil(expires_at) or DateTime.compare(expires_at, DateTime.utc_now()) == :gt)
  end
end
