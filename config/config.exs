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
config :josjob_web, Oban, plugins: [{Oban.Plugins.Cron, []}]

config :josjob, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: Josjob.Repo

# Configure Mix tasks and generators
config :josjob,
  ecto_repos: [Josjob.Repo],
  ash_domains: [
    Josjob.Accounts,
    Josjob.Payments,
    Josjob.Orgs,
    Josjob.Rbac,
    Josjob.Invitations
  ]

# Modul Document (bank dokumen) tinggal di app :josjob_doc, tetap pakai Josjob.Repo.
config :josjob_doc, ash_domains: [JosjobDoc.Documents]

# Ekosistem course (Section/Course/Class/Enrollment) di app :josjob_lrn, pakai Josjob.Repo.
config :josjob_lrn, ash_domains: [JosjobLrn.Learning]

config :josjob_job, ash_domains: [JosjobJob]

config :josjob,
       :token_signing_secret,
       "a_long_enough_random_signing_secret_for_jwt_tokens_to_work_properly"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :josjob, Josjob.Mailer, adapter: Swoosh.Adapters.Local

# Alamat pengirim email (undangan teacher, dll). Override di runtime.exs bila perlu.
config :josjob, :mail_from, {"JosJob", "no-reply@josjob.local"}

# Base URL app Flutter — dipakai membangun tautan accept undangan
# (`<fe_base_url>/invite?token=...`). Dev default = FE nginx (host 8081).
# Override lewat env FE_BASE_URL (lihat runtime.exs).
config :josjob, :fe_base_url, "http://localhost:8081"

config :josjob_web,
  ecto_repos: [Josjob.Repo],
  generators: [context_app: :josjob],
  # AshAdmin menemukan domain dari otp_app endpoint (:josjob_web). Domain
  # sebenarnya milik app :josjob; daftarkan di sini agar AshAdmin melihatnya.
  ash_domains: [
    Josjob.Accounts,
    Josjob.Payments,
    Josjob.Orgs,
    Josjob.Rbac,
    Josjob.Invitations,
    JosjobDoc.Documents,
    JosjobLrn.Learning,
    JosjobJob
  ]

# Configures the endpoint
config :josjob_web, JosjobWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JosjobWeb.ErrorHTML, json: JosjobWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Josjob.PubSub,
  live_view: [signing_salt: "Y4wAUFhz"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  josjob_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/josjob_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  josjob_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/josjob_web", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Atomic Server RAG settings
config :josjob_rag, :atomic,
  # Existing external service hostname; rebranding does not provision a new DNS record.
  base_url: System.get_env("ATOMIC_BASE_URL", "https://stellar-rag.onprem.vip"),
  api_token: System.get_env("ATOMIC_API_TOKEN", "default_token")

# Prefer the published NIF on supported platforms. Source builds remain opt-in
# for custom targets/toolchains via XBERG_BUILD=true.
config :rustler_precompiled, :force_build, xberg: System.get_env("XBERG_BUILD") in ["1", "true"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
