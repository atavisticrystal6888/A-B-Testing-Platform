defmodule ExperimentHub.ExportTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Export

  describe "export_experiment/3" do
    test "returns error for unsupported format" do
      assert {:error, :unsupported_format} =
               Export.export_experiment(Ecto.UUID.generate(), "xml")
    end
  end
end
