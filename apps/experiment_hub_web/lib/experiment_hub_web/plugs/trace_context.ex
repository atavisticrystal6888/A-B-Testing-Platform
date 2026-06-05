defmodule ExperimentHubWeb.Plugs.TraceContext do
  @moduledoc """
  W3C Trace Context propagation (Constitution Article IX.4).
  Extracts `traceparent` header on inbound requests and sets trace_id in Logger metadata.
  Generates a new trace ID if none is provided.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    {trace_id, traceparent} =
      case get_req_header(conn, "traceparent") do
        [header] -> parse_traceparent(header)
        _ -> generate_trace()
      end

    Logger.metadata(trace_id: trace_id)

    conn
    |> assign(:trace_id, trace_id)
    |> put_resp_header("traceparent", traceparent)
  end

  defp parse_traceparent(header) do
    case String.split(header, "-") do
      [_version, trace_id, _parent_id, _flags] when byte_size(trace_id) == 32 ->
        # Generate new span ID for this service
        span_id = random_hex(8)
        {trace_id, "00-#{trace_id}-#{span_id}-01"}

      _ ->
        generate_trace()
    end
  end

  defp generate_trace do
    trace_id = random_hex(16)
    span_id = random_hex(8)
    {trace_id, "00-#{trace_id}-#{span_id}-01"}
  end

  defp random_hex(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end
end
