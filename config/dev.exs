import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :td_lm, TdLmWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :td_lm, TdLm.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_lm_dev",
  hostname: "postgres",
  stacktrace: true

config :td_cache, redis_host: "redis"
