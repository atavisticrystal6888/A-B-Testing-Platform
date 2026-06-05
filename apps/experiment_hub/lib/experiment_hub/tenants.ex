defmodule ExperimentHub.Tenants do
  @moduledoc """
  The Tenants context. Manages tenants, users, and API keys.
  """

  import Ecto.Query
  alias ExperimentHub.Repo
  alias ExperimentHub.Tenants.{Tenant, User, ApiKey, ApiKeyGenerator}

  # --- Tenants ---

  def list_tenants do
    Repo.all(Tenant)
  end

  def get_tenant(id), do: Repo.get(Tenant, id)

  def get_tenant!(id), do: Repo.get!(Tenant, id)

  def get_tenant_by_slug(slug), do: Repo.get_by(Tenant, slug: slug)

  def create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  # --- Users ---

  def list_users(tenant_id) do
    User
    |> where(tenant_id: ^tenant_id)
    |> Repo.all()
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(tenant_id, email) do
    Repo.get_by(User, tenant_id: tenant_id, email: email)
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def update_user_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def authenticate_user(tenant_id, email, password) do
    with {:ok, resolved_tenant_id} <- resolve_tenant_id(tenant_id),
         user when not is_nil(user) <- get_user_by_email(resolved_tenant_id, email),
         true <- User.valid_password?(user, password) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def authenticate_user(email, password) do
    users = Repo.all(from(u in User, where: u.email == ^email))

    case users do
      [user] ->
        if User.valid_password?(user, password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      [] ->
        {:error, :invalid_credentials}

      _many ->
        {:error, :tenant_required}
    end
  end

  # --- API Keys ---

  def list_api_keys(tenant_id) do
    ApiKey
    |> where(tenant_id: ^tenant_id)
    |> Repo.all()
  end

  def get_api_key(id), do: Repo.get(ApiKey, id)

  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Creates a new API key. Returns `{:ok, api_key}` where `api_key.raw_key`
  contains the raw key shown once to the user.
  """
  def create_api_key(attrs) do
    {raw_key, key_prefix, key_hash} = ApiKeyGenerator.generate()

    attrs =
      attrs
      |> Map.put("key_prefix", key_prefix)
      |> Map.put("key_hash", key_hash)

    case %ApiKey{} |> ApiKey.changeset(attrs) |> Repo.insert() do
      {:ok, api_key} ->
        {:ok, %{api_key | raw_key: raw_key}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Looks up an API key by its raw key value.
  Returns `{:ok, api_key}` if found and active, `{:error, reason}` otherwise.
  """
  def verify_api_key(raw_key) when is_binary(raw_key) do
    key_hash = ApiKeyGenerator.hash_key(raw_key)

    case Repo.get_by(ApiKey, key_hash: key_hash) do
      nil ->
        {:error, :not_found}

      api_key ->
        if ApiKey.active?(api_key) do
          # Update last_used_at (fire-and-forget, non-blocking)
          from(a in ApiKey, where: a.id == ^api_key.id)
          |> Repo.update_all(
            set: [last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)]
          )

          {:ok, api_key}
        else
          {:error, :revoked_or_expired}
        end
    end
  end

  def revoke_api_key(%ApiKey{} = api_key) do
    api_key
    |> Ecto.Changeset.change(revoked_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  defp resolve_tenant_id(tenant_ref) when is_binary(tenant_ref) do
    case Ecto.UUID.cast(tenant_ref) do
      {:ok, tenant_id} ->
        {:ok, tenant_id}

      :error ->
        case get_tenant_by_slug(tenant_ref) do
          %Tenant{id: tenant_id} -> {:ok, tenant_id}
          nil -> {:error, :invalid_tenant}
        end
    end
  end

  defp resolve_tenant_id(_tenant_ref), do: {:error, :invalid_tenant}
end
