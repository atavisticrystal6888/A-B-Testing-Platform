defmodule ExperimentHub.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :key_prefix, :string, null: false, size: 8
      add :key_hash, :string, null: false, size: 255
      add :name, :string, null: false, size: 255
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:tenant_id])
    create index(:api_keys, [:key_prefix])
  end
end
