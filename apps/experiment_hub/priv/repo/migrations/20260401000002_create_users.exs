defmodule ExperimentHub.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :email, :string, null: false, size: 255
      add :password_hash, :string, null: false, size: 255
      add :role, :string, null: false, size: 20
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:tenant_id, :email])
    create index(:users, [:tenant_id])
  end
end
