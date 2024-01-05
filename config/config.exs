# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :hello_keycloak,
  generators: [timestamp_type: :utc_datetime]

config :ueberauth, Ueberauth,
  providers: [
    keycloak: {Ueberauth.Strategy.Keycloak, [default_scope: "openid profile email"]}
  ]

config :ueberauth, Ueberauth.Strategy.Keycloak.OAuth,
  client_id: "phoenix",
  client_secret: "MfyqFrtLxTtWeGdvnGRiJfQz",
  redirect_uri: "http://localhost:4000/auth/keycloak/callback",
  authorize_url: "http://localhost:9000/realms/local/protocol/openid-connect/auth",
  token_url: "http://localhost:9000/realms/local/protocol/openid-connect/token",
  userinfo_url: "http://localhost:9000/realms/local/protocol/openid-connect/userinfo"

# Configures the endpoint
config :hello_keycloak, HelloKeycloakWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HelloKeycloakWeb.ErrorHTML, json: HelloKeycloakWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HelloKeycloak.PubSub,
  live_view: [signing_salt: "XE/9yLVv"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :hello_keycloak, HelloKeycloak.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
