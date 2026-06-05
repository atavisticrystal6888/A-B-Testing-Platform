import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/experiment_hub_web start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :experiment_hub_web, ExperimentHubWeb.Endpoint, server: true
end

config :experiment_hub_web, ExperimentHubWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

required_env! = fn name, example ->
  System.get_env(name) ||
    raise """
    environment variable #{name} is missing.
    #{example}
    """
end

csv_env = fn value ->
  value
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
end

parse_kafka_brokers = fn value ->
  value
  |> csv_env.()
  |> Enum.map(fn broker ->
    case String.split(broker, ":", parts: 2) do
      [host, port] when host != "" ->
        {host, String.to_integer(port)}

      _ ->
        raise """
        environment variable KAFKA_BROKERS must be a comma-separated HOST:PORT list.
        For example: kafka-1.internal:9092,kafka-2.internal:9092
        """
    end
  end)
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :experiment_hub, ExperimentHub.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: String.to_existing_atom(System.get_env("DB_SSL") || "false")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  redis_url =
    required_env!.(
      "REDIS_URL",
      "For example: redis://redis.internal:6379"
    )

  stat_engine_url =
    required_env!.(
      "STAT_ENGINE_URL",
      "For example: http://stats.internal:8000"
    )

  stat_engine_api_key =
    required_env!.(
      "STAT_ENGINE_API_KEY",
      "It must match the INTERNAL_API_KEY configured on the statistical engine."
    )

  kafka_brokers =
    required_env!.(
      "KAFKA_BROKERS",
      "For example: kafka-1.internal:9092,kafka-2.internal:9092"
    )
    |> parse_kafka_brokers.()

  kafka_topics =
    System.get_env("KAFKA_TOPICS", "experimenthub.events.inbound")
    |> csv_env.()

  host = System.get_env("PHX_HOST") || "example.com"

  config :experiment_hub,
    redis_url: redis_url,
    stat_engine_url: stat_engine_url,
    stat_engine_api_key: stat_engine_api_key

  config :event_collector, EventCollector.Broadway.EventPipeline,
    kafka_brokers: kafka_brokers,
    kafka_group_id: System.get_env("KAFKA_GROUP_ID", "experimenthub-event-collector"),
    kafka_topics: kafka_topics

  config :experiment_hub_web, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :experiment_hub_web, ExperimentHubWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :experiment_hub_web, ExperimentHubWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :experiment_hub_web, ExperimentHubWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
