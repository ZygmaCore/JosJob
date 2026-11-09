# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :ash_oban, pro?: false
config :stellar_web, Oban, plugins: [{Oban.Plugins.Cron, []}]

config :stellar, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: Stellar.Repo

# Configure Mix tasks and generators
config :stellar,
  ecto_repos: [Stellar.Repo],
  ash_domains: [
    Stellar.Accounts,
    Stellar.Payments,
    Stellar.Orgs,
    Stellar.Rbac,
    Stellar.Invitations
  ]

# Modul Document (bank dokumen) tinggal di app :stellar_doc, tetap pakai Stellar.Repo.
config :stellar_doc, ash_domains: [StellarDoc.Documents]

# Ekosistem course (Section/Course/Class/Enrollment) di app :stellar_lrn, pakai Stellar.Repo.
config :stellar_lrn, ash_domains: [StellarLrn.Learning]

config :stellar,
       :token_signing_secret,
       "a_long_enough_random_signing_secret_for_jwt_tokens_to_work_properly"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :stellar, Stellar.Mailer, adapter: Swoosh.Adapters.Local

# Alamat pengirim email (undangan teacher, dll). Override di runtime.exs bila perlu.
config :stellar, :mail_from, {"Stellar", "no-reply@stellar.local"}

# Base URL app Flutter — dipakai membangun tautan accept undangan
# (`<fe_base_url>/invite?token=...`). Dev default = FE nginx (host 8081).
# Override lewat env FE_BASE_URL (lihat runtime.exs).
config :stellar, :fe_base_url, "http://localhost:8081"

config :stellar_web,
  ecto_repos: [Stellar.Repo],
  generators: [context_app: :stellar],
  # AshAdmin menemukan domain dari otp_app endpoint (:stellar_web). Domain
  # sebenarnya milik app :stellar; daftarkan di sini agar AshAdmin melihatnya.
  ash_domains: [
    Stellar.Accounts,
    Stellar.Payments,
    Stellar.Orgs,
    Stellar.Rbac,
    Stellar.Invitations,
    StellarDoc.Documents,
    StellarLrn.Learning
  ]

# Configures the endpoint
config :stellar_web, StellarWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StellarWeb.ErrorHTML, json: StellarWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Stellar.PubSub,
  live_view: [signing_salt: "Y4wAUFhz"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  stellar_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/stellar_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  stellar_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/stellar_web", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Atomic Server RAG settings
config :stellar_rag, :atomic,
  base_url: "https://stellar-rag.onprem.vip",
  api_token: System.get_env("ATOMIC_API_TOKEN", "default_token")

# Force building xberg NIF from source since precompiled target for x86_64-apple-darwin is missing
config :rustler_precompiled, :force_build, xberg: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
