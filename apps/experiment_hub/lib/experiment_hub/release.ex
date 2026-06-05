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
    repo
    |> Module.split()
    |> List.last()
    |> String.to_atom()
  end
end
