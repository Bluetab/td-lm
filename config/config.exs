# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Environment
config :td_lm, :env, Mix.env()

# General application configuration
config :td_lm,
  ecto_repos: [TdLm.Repo]

# Configures the endpoint
config :td_lm, TdLmWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "7oQ+yw+YduBniD7YG5DVzHQi5qfM7gpBT95tB7KL69wLfYFI9FntvymXAyhulV3s",
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
  format: (System.get_env("EX_LOGGER_FORMAT") || "$time $metadata[$level] $message") <> "\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :td_lm, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: TdLmWeb.Router]
  }

config :td_lm, permission_resolver: TdPerms.Permissions

config :td_lm, :audit_service,
  protocol: "http",
  audits_path: "/api/audits/"

config :td_perms,
  permissions: [
    :is_admin,
    :create_acl_entry,
    :update_acl_entry,
    :delete_acl_entry,
    :create_domain,
    :update_domain,
    :delete_domain,
    :view_domain,
    :create_business_concept,
    :create_data_structure,
    :update_business_concept,
    :update_data_structure,
    :send_business_concept_for_approval,
    :delete_business_concept,
    :delete_data_structure,
    :publish_business_concept,
    :reject_business_concept,
    :deprecate_business_concept,
    :manage_business_concept_alias,
    :view_data_structure,
    :view_draft_business_concepts,
    :view_approval_pending_business_concepts,
    :view_published_business_concepts,
    :view_versioned_business_concepts,
    :view_rejected_business_concepts,
    :view_deprecated_business_concepts,
    :manage_business_concept_links,
    :manage_quality_rule,
    :manage_confidential_business_concepts,
    :create_ingest,
    :update_ingest,
    :send_ingest_for_approval,
    :delete_ingest,
    :publish_ingest,
    :reject_ingest,
    :deprecate_ingest,
    :view_draft_ingests,
    :view_approval_pending_ingests,
    :view_published_ingests,
    :view_versioned_ingests,
    :view_rejected_ingests,
    :view_deprecated_ingests,
    :manage_confidential_structures,
    :manage_ingest_relations
  ]

config :td_lm, :relation_loader, load_on_startup: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
