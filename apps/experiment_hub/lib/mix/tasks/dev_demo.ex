defmodule Mix.Tasks.Dev.Demo do
  @moduledoc """
  Populates the local development database with a complete ExperimentHub demo.

  ## Usage

      mix dev.demo
  """

  use Mix.Task

  alias ExperimentHub.DemoSeeds

  @shortdoc "Seeds a complete local ExperimentHub demo"

  @impl Mix.Task
  def run(_args) do
    if Mix.env() != :dev do
      Mix.raise("mix dev.demo only runs in the dev environment")
    end

    Mix.Task.run("app.config")
    Application.put_env(:experiment_hub, :start_oban, false)
    {:ok, _} = Application.ensure_all_started(:experiment_hub)

    demo = DemoSeeds.seed!()

    IO.puts("""
    Demo workspace ready:
      tenant: #{demo.tenant.name} (#{demo.tenant.slug})
      admin: #{demo.admin.email} / #{demo.admin_password}
      demo users: analyst@local.dev, operator@local.dev, viewer@local.dev
      demo user password: #{demo.demo_user_password}
      SDK API key: #{demo.api_key.raw_key}

      running experiment: #{demo.experiments.checkout.key}
      paused experiment: #{demo.experiments.pricing.key}
      concluded experiment: #{demo.experiments.search.key}
      draft experiment: #{demo.experiments.onboarding.key}
    """)
  end
end
