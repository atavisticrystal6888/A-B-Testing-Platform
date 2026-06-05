# Script for populating the database.
#
# You can run it as:
#
#     mix run --no-start apps/experiment_hub/priv/repo/seeds.exs

if Mix.env() == :dev do
	Application.put_env(:experiment_hub, :start_oban, false)
	{:ok, _} = Application.ensure_all_started(:experiment_hub)

	%{tenant: tenant, user: user, password: password} = ExperimentHub.DevSeeds.seed_local_admin!()

	IO.puts("""
	Seeded local development admin account:
		tenant: #{tenant.name} (#{tenant.slug})
		tenant_id: #{tenant.id}
		email: #{user.email}
		role: #{user.role}
		password: #{password}
	""")
else
	IO.puts("No default seed data defined for #{Mix.env()} environment.")
end
