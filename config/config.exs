# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Environment
config :td_lm, :env, Mix.env()

# General application configuration
config :td_lm, ecto_repos: [TdLm.Repo]
config :td_lm, TdLm.Repo, pool_size: 5

# Configures the endpoint
config :td_lm, TdLmWeb.Endpoint,
  http: [port: 4012],
  url: [host: "localhost"],
  render_errors: [view: TdLmWeb.ErrorView, accepts: ~w(json)]

# Configures Auth module Guardian
config :td_lm, TdLm.Auth.Guardian,
  # optional
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "SuperSecretTruedat"

config :td_lm, hashing_module: Comeonin.Bcrypt

# Configures Elixir's Logger
# set EX_LOGGER_FORMAT environment variable to override Elixir's Logger format
# (without the 'end of line' character)
# EX_LOGGER_FORMAT='$date $time [$level] $message'
config :logger, :console,
  format:
    (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level]$levelpad $metadata$message") <>
      "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

config :phoenix, :json_library, Jason
config :phoenix_swagger, :json_library, Jason

config :td_lm, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdLmWeb.Router]
  }

config :td_lm, :relation_loader, load_on_startup: true

config :td_cache, :audit,
  service: "td_lm",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "lm",
  streams: [
    [key: "link:commands", consumer: TdLm.Cache.LinkRemover]
  ]

config :td_lm, :cache_cleaner,
  clean_on_startup: true,
  patterns: [
    "relation_type:*",
    "business_concept*:",
    "data_field*:",
    "data_structure*:",
    "ingest*:",
    "*:bc_padre",
    "*:bc_caculo",
    "*:relations"
  ]

config :td_lm, TdLm.Scheduler,
  jobs: [
    link_refresher: [
      schedule: "@hourly",
      task: {TdLm.Cache.LinkLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
