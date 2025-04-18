# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Environment
config :td_lm, :env, Mix.env()

config :td_cluster, :env, Mix.env()
config :td_cluster, groups: [:lm]

# General application configuration
config :td_lm, ecto_repos: [TdLm.Repo]
config :td_lm, TdLm.Repo, pool_size: 4

# Configures the endpoint
config :td_lm, TdLmWeb.Endpoint,
  http: [port: 4012],
  url: [host: "localhost"],
  render_errors: [view: TdLmWeb.ErrorView, accepts: ~w(json)]

# Configures Auth module Guardian
config :td_lm, TdLm.Auth.Guardian,
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
    (System.get_env("EX_LOGGER_FORMAT") || "$date\T$time\Z [$level] $metadata$message") <>
      "\n",
  level: :info,
  metadata: [:pid, :module],
  utc_log: true

config :phoenix, :json_library, Jason

config :td_cache, :audit,
  service: "td_lm",
  stream: "audit:events"

config :td_cache, :event_stream,
  consumer_id: "default",
  consumer_group: "lm",
  streams: [
    [key: "link:commands", consumer: TdLm.Cache.LinkRemover]
  ]

config :td_lm, TdLm.Scheduler,
  jobs: [
    cache_cleaner: [
      schedule: "@reboot",
      task:
        {TdCache.CacheCleaner, :clean,
         [
           [
             "relation_type:*",
             "business_concept*:",
             "data_field*:",
             "data_structure*:",
             "implementation*:",
             "ingest*:",
             "*:bc_padre",
             "*:bc_caculo",
             "*:relations"
           ]
         ]},
      run_strategy: Quantum.RunStrategy.Local
    ],
    link_loader: [
      schedule: "@reboot",
      task: {TdLm.Cache.LinkLoader, :load, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    implementation_link_migration_id_to_ref: [
      schedule: "@reboot",
      task: {TdLm.Cache.LinkLoader, :check_relation_impl_id_to_impl_ref, []},
      run_strategy: Quantum.RunStrategy.Local
    ],
    link_refresher: [
      schedule: "@hourly",
      task: {TdLm.Cache.LinkLoader, :refresh, []},
      run_strategy: Quantum.RunStrategy.Local
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
