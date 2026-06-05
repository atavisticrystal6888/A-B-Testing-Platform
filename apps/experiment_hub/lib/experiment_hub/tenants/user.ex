defmodule ExperimentHub.Tenants.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(viewer editor admin)

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:password_hash, :string, redact: true)
    field(:role, :string)
    field(:last_login_at, :utc_datetime)
    field(:tenant_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :tenant_id])
    |> validate_required([:email, :password, :role, :tenant_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> validate_inclusion(:role, @roles)
    |> hash_password()
    |> unique_constraint([:tenant_id, :email])
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:tenant_id, :email])
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> validate_length(:password, min: 8, max: 72)
        |> put_change(:password_hash, Pbkdf2.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  def valid_password?(%__MODULE__{password_hash: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  def roles, do: @roles
end
