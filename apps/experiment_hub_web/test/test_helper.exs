ExUnit.start()

if Process.whereis(ExperimentHub.Repo) do
  Ecto.Adapters.SQL.Sandbox.mode(ExperimentHub.Repo, :manual)
end
