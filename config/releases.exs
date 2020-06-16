import Config

# Configure your database
config :td_lm, TdLm.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: System.get_env("DB_POOL_SIZE", "4") |> String.to_integer()

config :td_lm, TdLm.Auth.Guardian, secret_key: System.fetch_env!("GUARDIAN_SECRET_KEY")

config :td_cache, :event_stream, consumer_id: System.fetch_env!("HOSTNAME")
config :td_cache, redis_host: System.fetch_env!("REDIS_HOST")
