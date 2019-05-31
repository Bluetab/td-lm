use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :td_lm, TdLmWeb.Endpoint,
  http: [port: 4012],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :td_lm, TdLm.Repo,
  username: "postgres",
  password: "postgres",
  database: "td_lm_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :td_lm, :audit_service,
  api_service: TdLmWeb.ApiServices.MockTdAuditService,
  audit_host: "localhost",
  audit_port: "4007",
  audit_domain: ""

config :td_lm, permission_resolver: TdLm.Permissions.MockPermissionResolver
config :td_lm, bc_cache: TdPerms.MockBusinessConceptCache

config :td_lm, cache_links_on_startup: false
config :td_lm, cache_relations_on_startup: false

config :td_perms, redis_host: "localhost"
