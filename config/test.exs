import Config

db_username = System.get_env("DB_USERNAME", "postgres")
db_password = System.get_env("DB_PASSWORD", "postgres")
db_hostname = System.get_env("DB_HOST", "localhost")
db_port = String.to_integer(System.get_env("DB_PORT", "5432"))

db_name =
  System.get_env("DB_NAME") || "experiment_hub_test#{System.get_env("MIX_TEST_PARTITION")}"

config :experiment_hub, ExperimentHub.Repo,
  username: db_username,
  password: db_password,
  hostname: db_hostname,
  port: db_port,
  database: db_name,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :experiment_hub_web, ExperimentHubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "f+ur6WIEJS1YY6jaUyGOsA/RG0tJgirU2xY99iIoTlLnwq9o0Rd9UdDPzGreuF2o",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :experiment_hub_web, :jwt_secret, "test-secret-key-do-not-use-in-production"

config :experiment_hub,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6380"),
  start_oban: false

# Disable Oban in test
config :experiment_hub, Oban, queues: false, plugins: false
