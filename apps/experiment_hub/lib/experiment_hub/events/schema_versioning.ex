defmodule ExperimentHub.Events.SchemaVersioning do
  @moduledoc """
  Schema versioning for Kafka message schemas (Constitution Art.V).
  Validates schema_version field and handles backward-compatible schema evolution.
  """

  @current_version 1
  @supported_versions [1]

  @doc """
  Get the current schema version.
  """
  def current_version, do: @current_version

  @doc """
  Validate a message's schema version.
  Returns {:ok, version} or {:error, reason}.
  """
  def validate_version(message) when is_map(message) do
    version =
      Map.get(message, "schema_version") || Map.get(message, :schema_version, @current_version)

    if version in @supported_versions do
      {:ok, version}
    else
      {:error, {:unsupported_schema_version, version}}
    end
  end

  @doc """
  Add schema_version to a message if not present.
  """
  def stamp(message) when is_map(message) do
    Map.put_new(message, :schema_version, @current_version)
  end

  @doc """
  Migrate a message from one schema version to the current version.
  """
  def migrate(message, from_version \\ nil) do
    version =
      from_version || Map.get(message, "schema_version") || Map.get(message, :schema_version, 1)

    case version do
      1 -> {:ok, message}
      _ -> {:error, {:unsupported_schema_version, version}}
    end
  end

  @doc """
  Check if a schema version is supported.
  """
  def supported?(version), do: version in @supported_versions
end
