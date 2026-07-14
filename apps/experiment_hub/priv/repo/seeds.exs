# Script for populating the database.
#
# You can run it as:
#
#     mix run --no-start apps/experiment_hub/priv/repo/seeds.exs

if Mix.env() == :dev do
  Application.put_env(:experiment_hub, :start_oban, false)
  {:ok, _} = Application.ensure_all_started(:experiment_hub)

  demo = ExperimentHub.DemoSeeds.seed!()

  IO.puts("""
  Seeded local ExperimentHub demo workspace:
    tenant: #{demo.tenant.name} (#{demo.tenant.slug})
    admin: #{demo.admin.email} / #{demo.admin_password}
    SDK API key: #{demo.api_key.raw_key}
    experiments: #{Enum.join(Enum.map(demo.experiments, fn {_name, experiment} -> experiment.key end), ", ")}
  """)
else
  IO.puts("No default seed data defined for #{Mix.env()} environment.")
end
