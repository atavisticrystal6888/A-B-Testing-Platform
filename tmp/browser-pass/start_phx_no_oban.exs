Mix.Task.run("app.config")
Application.put_env(:experiment_hub, :start_oban, false)

endpoint_config =
	:experiment_hub_web
	|> Application.get_env(ExperimentHubWeb.Endpoint, [])
	|> Keyword.merge(server: true, watchers: [])

Application.put_env(:experiment_hub_web, ExperimentHubWeb.Endpoint, endpoint_config)
{:ok, _} = Application.ensure_all_started(:experiment_hub_web)

receive do
after
	:infinity -> :ok
end
