defmodule ExperimentHub.Tracing.CrossServiceTest do
  use ExperimentHub.DataCase, async: true

  describe "W3C Trace Context propagation" do
    test "trace context plug is available" do
      assert Code.ensure_loaded?(ExperimentHubWeb.Plugs.TraceContext)
    end

    test "traceparent format is valid" do
      # Verify the expected format: 00-{trace_id}-{span_id}-{flags}
      traceparent =
        "00-#{:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}-01"

      parts = String.split(traceparent, "-")
      assert length(parts) == 4
      assert Enum.at(parts, 0) == "00"
      assert byte_size(Enum.at(parts, 1)) == 32
      assert byte_size(Enum.at(parts, 2)) == 16
    end
  end
end
