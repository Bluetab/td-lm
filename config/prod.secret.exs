use Mix.Config

# In this file, we keep production configuration that
# you'll likely want to automate and keep away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or yourself later on).
config :td_lm, TdLmWeb.Endpoint,
  secret_key_base: "iqmuyccnMDB9ZZNvDJkoq/qIGAbUsb1elGOPSs3WP9nU0e0gvHuPshfz8lzasMh8"

# Configure your database
config :td_lm, TdLm.Repo,
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  database: "${DB_NAME}",
  hostname: "${DB_HOST}",
  pool_size: 10

config :td_cache, redis_host: "${REDIS_HOST}"

config :td_lm, :audit_service,
  api_service: TdLmWeb.ApiServices.HttpTdAuditService,
  audit_host: "${API_AUDIT_HOST}",
  audit_port: "${API_AUDIT_PORT}",
  audit_domain: ""

config :td_lm, TdLm.Auth.Guardian,
  allowed_algos: ["HS512"],
  issuer: "tdauth",
  ttl: {1, :hours},
  secret_key: "${GUARDIAN_SECRET_KEY}"

config :td_cache, :event_stream,
  consumer_id: "${HOSTNAME}",
  consumer_group: "lm",
  streams: [
    [key: "data_field:events", consumer: TdLm.Cache.LinkMigrater],
    [key: "link:commands", consumer: TdLm.Cache.LinkRemover]
  ]
