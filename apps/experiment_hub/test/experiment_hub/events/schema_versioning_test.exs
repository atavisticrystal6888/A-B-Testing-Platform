defmodule ExperimentHub.Events.SchemaVersioningTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Events.SchemaVersioning

  describe "validate_version/1" do
    test "accepts schema version 1" do
      assert {:ok, 1} = SchemaVersioning.validate_version(%{"schema_version" => 1})
    end

    test "defaults to version 1 when missing" do
      assert {:ok, 1} = SchemaVersioning.validate_version(%{})
    end

    test "rejects unsupported version" do
      assert {:error, {:unsupported_schema_version, 99}} =
               SchemaVersioning.validate_version(%{"schema_version" => 99})
    end
  end

  describe "stamp/1" do
    test "adds schema_version to message" do
      msg = SchemaVersioning.stamp(%{event: "test"})
      assert msg.schema_version == 1
    end

    test "does not overwrite existing version" do
      msg = SchemaVersioning.stamp(%{schema_version: 1, event: "test"})
      assert msg.schema_version == 1
    end
  end

  describe "migrate/1" do
    test "v1 message passes through unchanged" do
      msg = %{"schema_version" => 1, "data" => "test"}
      assert {:ok, ^msg} = SchemaVersioning.migrate(msg)
    end

    test "unsupported version returns error" do
      assert {:error, _} = SchemaVersioning.migrate(%{"schema_version" => 99})
    end
  end

  describe "supported?/1" do
    test "version 1 is supported" do
      assert SchemaVersioning.supported?(1)
    end

    test "version 2 is not yet supported" do
      refute SchemaVersioning.supported?(2)
    end
  end
end
