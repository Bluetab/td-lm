import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_lm, TdLmWeb.Endpoint, server: false

config :td_lm, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warning

# Track all Plug compile-time dependencies
config :phoenix, :plug_init_mode, :runtime

config :td_lm,
  resources_mod: TdLm.Mock.Resources

# Configure your database
config :td_lm, TdLm.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_lm_test",
  hostname: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :td_cache, :audit, stream: "audit:events:test"
config :td_cache, redis_host: "redis", port: 6380

config :td_lm, TdLm.Scheduler, jobs: []

config :td_cluster, TdCluster.ClusterHandler, MockClusterHandler

config :td_lm, :oban, attempts: 1
