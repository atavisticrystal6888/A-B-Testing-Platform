defmodule ExperimentHub.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tenants" do
    field(:name, :string)
    field(:slug, :string)
    field(:settings, :map, default: %{})

    has_many(:users, ExperimentHub.Tenants.User)
    has_many(:api_keys, ExperimentHub.Tenants.ApiKey)

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :settings])
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 100)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$/,
      message: "must be URL-safe lowercase"
    )
    |> unique_constraint(:slug)
  end
end
