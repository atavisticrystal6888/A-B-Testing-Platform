defmodule ExperimentHubWeb.Plugs.Cors do
  @moduledoc """
  CORS middleware for dashboard cross-origin requests.
  Wraps Corsica with project-specific configuration.
  """

  use Corsica.Router,
    origins: {__MODULE__, :allowed_origins, []},
    allow_headers: ["content-type", "authorization", "x-api-key", "traceparent"],
    allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    expose_headers: [
      "x-ratelimit-limit",
      "x-ratelimit-remaining",
      "x-ratelimit-reset",
      "traceparent"
    ],
    max_age: 86_400,
    allow_credentials: true

  resource("/*")

  def allowed_origins(_conn, _origin) do
    Application.get_env(:experiment_hub_web, :cors_origins, ["http://localhost:5173"])
  end
end
