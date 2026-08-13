defmodule ExperimentHub.Release do
  @moduledoc false

  @app :experiment_hub

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()

    {:ok, repo} = fetch_repo(repo)

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Creates the first tenant, admin user, and SDK API key on a fresh
  deployment — the release-safe equivalent of the ad hoc console commands
  this used to require. Refuses to run if any tenant already exists, so
  it's safe to invoke more than once. Starts only the repo (not the full
  supervision tree), same as migrate/0, so it works via `bin/APP eval`
  without the release already running.

  Usage against a running release container:

      bin/experiment_hub_web eval \\
        'ExperimentHub.Release.bootstrap_first_tenant("Acme Corp", "acme", "admin@acme.example", "ChangeMe123!")'
  """
  def bootstrap_first_tenant(tenant_name, tenant_slug, admin_email, admin_password) do
    load_app()

    [repo | _] = repos()

    {:ok, result, _} =
      Ecto.Migrator.with_repo(repo, fn _repo ->
        do_bootstrap_first_tenant(tenant_name, tenant_slug, admin_email, admin_password)
      end)

    result
  end

  defp do_bootstrap_first_tenant(tenant_name, tenant_slug, admin_email, admin_password) do
    case ExperimentHub.Tenants.list_tenants() do
      [] ->
        with {:ok, tenant} <-
               ExperimentHub.Tenants.create_tenant(%{
                 "name" => tenant_name,
                 "slug" => tenant_slug
               }),
             {:ok, user} <-
               ExperimentHub.Tenants.create_user(%{
                 "tenant_id" => tenant.id,
                 "email" => admin_email,
                 "password" => admin_password,
                 "role" => "admin"
               }),
             {:ok, api_key} <-
               ExperimentHub.Tenants.create_api_key(%{
                 "tenant_id" => tenant.id,
                 "name" => "Bootstrap SDK Key"
               }) do
          IO.puts("Created tenant #{tenant.slug} (#{tenant.id})")
          IO.puts("Created admin user #{user.email}")
          IO.puts("SDK API key (save this now, it is only shown once): #{api_key.raw_key}")
          {:ok, %{tenant: tenant, user: user, api_key: api_key}}
        else
          {:error, changeset} ->
            IO.puts("Bootstrap failed: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

      existing ->
        IO.puts(
          "Refusing to bootstrap: #{length(existing)} tenant(s) already exist. " <>
            "Create additional tenants from the console instead."
        )

        {:error, :tenants_already_exist}
    end
  end

  defp load_app do
    Application.load(@app)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp fetch_repo(repo) when is_atom(repo) do
    Enum.find_value(repos(), {:error, :repo_not_found}, fn current_repo ->
      if repo in [current_repo, repo_name(current_repo)] do
        {:ok, current_repo}
      end
    end)
  end

  defp fetch_repo(repo) when is_binary(repo) do
    repo
    |> String.to_existing_atom()
    |> fetch_repo()
  rescue
    ArgumentError -> {:error, :repo_not_found}
  end

  defp repo_name(repo) do
    # `repo` is always one of the fixed, compile-time :ecto_repos list (see
    # repos/0) — an operator-invoked release command, not a hot path taking
    # arbitrary input.
    repo
    |> Module.split()
    |> List.last()
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    |> String.to_atom()
  end
end
