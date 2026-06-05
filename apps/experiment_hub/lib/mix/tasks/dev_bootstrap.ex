defmodule Mix.Tasks.Dev.Bootstrap do
  @moduledoc """
  Creates or refreshes the default local development tenant and admin account.

  ## Usage

      mix dev.bootstrap
  """

  use Mix.Task

  alias ExperimentHub.DevSeeds

  @shortdoc "Bootstraps the default dev tenant and admin user"

  @impl Mix.Task
  def run(_args) do
    if Mix.env() != :dev do
      Mix.raise("mix dev.bootstrap only runs in the dev environment")
    end

    Mix.Task.run("app.config")
    Application.put_env(:experiment_hub, :start_oban, false)
    {:ok, _} = Application.ensure_all_started(:experiment_hub)

    %{tenant: tenant, user: user, password: password} = DevSeeds.seed_local_admin!()

    Mix.shell().info("""
    Local dev admin ready:
      tenant: #{tenant.name} (#{tenant.slug})
      tenant_id: #{tenant.id}
      email: #{user.email}
      role: #{user.role}
      password: #{password}
    """)
  end
end
