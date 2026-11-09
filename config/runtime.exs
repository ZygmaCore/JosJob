import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("../envs/", __DIR__)

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname(".#{config_env()}.overrides.env", env_dir_prefix),
  System.get_env()
])

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Semua nilai runtime dibaca via Dotenvy `env!` -> menggabungkan envs/.env
# dengan OS env (OS env menang). Jadi `.env` menjadi sumber tunggal untuk dev
# maupun prod.

# Port HTTP endpoint (berlaku semua environment).
port = String.to_integer(env!("PORT", :string, nil) || "4000")

config :stellar_web, StellarWeb.Endpoint, http: [port: port]

# PHX_SERVER=true (di-set oleh skrip `bin/server`) menyalakan endpoint Phoenix
# saat berjalan sebagai release. Tanpa ini, release hanya memuat aplikasi tanpa
# melayani HTTP.
if env!("PHX_SERVER", :string, nil) do
  config :stellar_web, StellarWeb.Endpoint, server: true
end

# Koneksi DB — SATU skema variabel (POSTGRES_*) untuk semua environment. Nilai
# BERBEDA per-environment karena tiap environment memuat envs/.env sendiri
# (laptop lokal / server dev / server prod) — jadi kredensial dev & prod tetap
# terpisah walau nama key-nya sama. `DATABASE_URL` tetap didukung sebagai
# override penuh (mis. managed DB); bila di-set, ia menang atas POSTGRES_*.
# Di :test SENGAJA dilewati agar config/test.exs (DB test + Ecto Sandbox) berlaku.
if config_env() != :test do
  maybe_ipv6 = if env!("ECTO_IPV6", :string, nil) in ~w(true 1), do: [:inet6], else: []
  pool_size = String.to_integer(env!("POOL_SIZE", :string, nil) || "10")

  db_conn =
    case env!("DATABASE_URL", :string, nil) do
      nil ->
        [
          username: env!("POSTGRES_USER", :string, nil) || "postgres",
          password: env!("POSTGRES_PASSWORD", :string, nil) || "postgres",
          hostname: env!("POSTGRES_HOST", :string, nil) || "localhost",
          port: String.to_integer(env!("POSTGRES_PORT", :string, nil) || "5438"),
          database: env!("POSTGRES_DB", :string, nil) || "stellar_dev"
        ]

      url ->
        [url: url]
    end

  config :stellar, Stellar.Repo, db_conn ++ [pool_size: pool_size, socket_options: maybe_ipv6]
end

# TTL token API (detik). Bisa di-override via env; default: access 1 jam,
# refresh 30 hari.
config :stellar, Stellar.Accounts.Tokens,
  access_ttl_seconds: String.to_integer(env!("ACCESS_TOKEN_TTL", :string, nil) || "3600"),
  refresh_ttl_seconds: String.to_integer(env!("REFRESH_TOKEN_TTL", :string, nil) || "2592000")

# Google id_token verification (flow mobile): `client_id` = aud yang divalidasi.
config :stellar, Stellar.Accounts.GoogleAuth, client_id: env!("GOOGLE_CLIENT_ID", :string, nil)

# Kredensial Google OAuth (flow redirect web/CMS). Dibaca dari envs/.env sehingga
# tombol "Sign in with Google" pakai kredensial nyata tanpa export manual.
config :stellar, :google_oauth,
  client_id: env!("GOOGLE_CLIENT_ID", :string, nil),
  client_secret: env!("GOOGLE_CLIENT_SECRET", :string, nil),
  # BASE ke AuthPlug (ash menambah "/user/google/callback").
  redirect_uri: env!("GOOGLE_REDIRECT_URI", :string, nil) || "http://localhost:4000/auth"

# Cloudflare Stream (VOD terkelola: upload -> transcode -> HLS/CDN). App media
# streaming = :stellar_ms. Dibaca dari envs/.env. Bila kosong ->
# StellarMs.configured?() = false -> upload & seed video nyata di-skip
# (fungsi mengembalikan {:error, :not_configured}).
config :stellar_ms, StellarMs.CloudflareStream,
  account_id: env!("CLOUDFLARE_ACCOUNT_ID", :string, nil),
  api_token: env!("CLOUDFLARE_STREAM_TOKEN", :string, nil),
  # Bila di-set -> auth Global API Key (X-Auth-Email/Key) untuk testing lokal;
  # kosong -> Bearer scoped token (default/produksi).
  auth_email: env!("CLOUDFLARE_EMAIL", :string, nil),
  customer_subdomain: env!("CLOUDFLARE_STREAM_CUSTOMER_SUBDOMAIN", :string, nil),
  webhook_secret: env!("CLOUDFLARE_STREAM_WEBHOOK_SECRET", :string, nil)

# Cloudflare Realtime (live streaming WebRTC: SFU fan-out + TURN NAT traversal).
# App media streaming = :stellar_ms. Dibaca dari envs/.env. Bila kosong ->
# StellarMs.Realtime.configured?() = false -> sesi live di-skip (channel membalas
# `configured: false`, fungsi mengembalikan {:error, :not_configured}).
config :stellar_ms, StellarMs.CloudflareRealtime,
  # SFU (dashboard Cloudflare > Realtime > buat App): app_id + app_secret.
  app_id: env!("CLOUDFLARE_REALTIME_APP_ID", :string, nil),
  app_secret: env!("CLOUDFLARE_REALTIME_APP_SECRET", :string, nil),
  # TURN (dashboard Cloudflare > Realtime > buat TURN Key): key id + API token.
  turn_key_id: env!("CLOUDFLARE_TURN_KEY_ID", :string, nil),
  turn_token: env!("CLOUDFLARE_TURN_TOKEN", :string, nil)

# Kredensial Stripe (payment gateway). Dibaca dari envs/.env sehingga secret
# tidak perlu di-export manual. Bila kosong, Stripe.Client mengembalikan
# {:error, :missing_stripe_secret_key} dan webhook ditolak.
config :stellar, Stellar.Payments.Stripe,
  secret_key: env!("STRIPE_SECRET_KEY", :string, nil),
  publishable_key: env!("STRIPE_PUBLISHABLE_KEY", :string, nil),
  webhook_secret: env!("STRIPE_WEBHOOK_SECRET", :string, nil),
  api_base: env!("STRIPE_API_BASE", :string, nil) || "https://api.stripe.com"

# Base URL app Flutter — dipakai membangun tautan accept undangan teacher
# (`<fe_base_url>/invite?token=...`). Kosong → default config.exs (localhost:8081).
if fe_base_url = env!("FE_BASE_URL", :string, nil) do
  config :stellar, :fe_base_url, fe_base_url
end

# Object storage S3-compatible (Cloudflare R2 / AWS S3 / MinIO) untuk upload
# dokumen non-video (pdf/doc). App media = :stellar_ms. Kosong →
# StellarMs.Storage.configured?() = false → upload dokumen file nyata di-skip.
config :stellar_ms, StellarMs.S3Storage,
  endpoint: env!("S3_ENDPOINT", :string, nil),
  region: env!("S3_REGION", :string, nil) || "auto",
  bucket: env!("S3_BUCKET", :string, nil),
  access_key_id: env!("S3_ACCESS_KEY_ID", :string, nil),
  secret_access_key: env!("S3_SECRET_ACCESS_KEY", :string, nil),
  # Base URL publik untuk membaca objek (mis. domain publik R2 / CDN). Bila kosong,
  # dipakai `<endpoint>/<bucket>` (cocok untuk MinIO / bucket publik).
  public_base_url: env!("S3_PUBLIC_BASE_URL", :string, nil)

# SMTP mailer (Zoho Mail) — mengirim email undangan teacher (satu-satunya email
# yang dikirim app, via Stellar.Mailer.deliver/1). Aktif HANYA bila SMTP_RELAY +
# SMTP_USERNAME di-set; kosong → tetap adapter default (Local di dev/config.exs)
# sehingga email hanya muncul di /dev/mailbox.
#
# Zoho: relay `smtp.zoho.com` (region lain: smtp.zoho.eu / smtp.zoho.in /
# smtp.zoho.com.au — sesuaikan data center akun; akun bisnis custom-domain bisa
# pakai smtppro.zoho.com). Port 465 = SSL implisit, 587 = STARTTLS. Jika 2FA
# aktif WAJIB App Password (Zoho > Security > App Passwords), bukan password akun.
# `env!` dotenvy mengembalikan "" untuk key yang ADA tapi kosong (envs/.env
# mengirim kredensial kosong sebagai placeholder) — `present` memperlakukan "" =
# tak-diisi agar guard & fallback `||` bekerja benar (bukan "" yang truthy).
present = fn v -> if v in [nil, ""], do: nil, else: v end

smtp_relay = present.(env!("SMTP_RELAY", :string, nil))
smtp_username = present.(env!("SMTP_USERNAME", :string, nil))

if smtp_relay && smtp_username do
  smtp_port = String.to_integer(present.(env!("SMTP_PORT", :string, nil)) || "465")

  # 465 → SSL implisit; selain itu STARTTLS. Paksa via SMTP_SSL=true/false.
  smtp_ssl =
    case present.(env!("SMTP_SSL", :string, nil)) do
      nil -> smtp_port == 465
      v -> v in ~w(true 1)
    end

  # TLS: gen_smtp mewarisi default OTP `verify_peer` tapi TIDAK mengisi CA store,
  # jadi handshake gagal ({:options, :incompatible, [verify: :verify_peer,
  # cacerts: :undefined]}). Sediakan CA bundle sistem + match_fun wildcard ala
  # HTTPS (sertifikat Zoho = *.zoho.com). CA default = path image Debian; override
  # via SMTP_CACERTFILE.
  cacertfile =
    present.(env!("SMTP_CACERTFILE", :string, nil)) ||
      "/etc/ssl/certs/ca-certificates.crt"

  tls_opts = [
    verify: :verify_peer,
    cacertfile: cacertfile,
    depth: 9,
    server_name_indication: String.to_charlist(smtp_relay),
    customize_hostname_check: [
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]

  # 465 (ssl implisit) memakai opsi TLS via `sockopts` (saat connect); STARTTLS
  # (587) via `tls_options` (saat upgrade). Dipisah agar opsi ssl tak bocor ke
  # koneksi TCP polos 587 (gen_tcp menolak opsi ssl).
  transport = if smtp_ssl, do: [sockopts: tls_opts], else: [tls_options: tls_opts]

  mailer_opts =
    [
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_relay,
      username: smtp_username,
      password: present.(env!("SMTP_PASSWORD", :string, nil)),
      port: smtp_port,
      ssl: smtp_ssl,
      tls: if(smtp_ssl, do: :never, else: :always),
      auth: :always,
      retries: 2,
      no_mx_lookups: true
    ] ++ transport

  config :stellar, Stellar.Mailer, mailer_opts
end

# Alamat pengirim (From). Zoho MENOLAK from yang bukan alamat akun / alias
# terverifikasi → default ke SMTP_USERNAME. Override nama/alamat via MAIL_FROM_*.
mail_from_address = present.(env!("MAIL_FROM_ADDRESS", :string, nil)) || smtp_username

if mail_from_address do
  mail_from_name = present.(env!("MAIL_FROM_NAME", :string, nil)) || "Stellar"
  config :stellar, :mail_from, {mail_from_name, mail_from_address}
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env!("SECRET_KEY_BASE", :string, nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Host + skema + port PUBLIK (yang dilihat browser). Dipakai untuk URL yang
  # di-generate DAN sebagai basis check_origin. Di belakang reverse proxy TLS
  # (mis. https://dev.example.com) set PHX_HOST=dev.example.com dan
  # PHX_SCHEME=https. Tanpa proxy (akses http://IP:4000) biarkan default.
  phx_host = env!("PHX_HOST", :string, nil) || "localhost"
  url_scheme = env!("PHX_SCHEME", :string, nil) || "http"

  url_port =
    String.to_integer(
      env!("PHX_PORT", :string, nil) ||
        if(url_scheme == "https", do: "443", else: to_string(port))
    )

  # check_origin: Phoenix menolak koneksi WebSocket (LiveView `/live`) yang origin-
  # nya tak cocok. Default TRUE membandingkan dengan :url -> kalau url=http://localhost
  # tapi diakses via https://domain, koneksi ditolak -> LiveView "Loading..." abadi.
  # Default di sini = URL publik (scheme+host). Override: CHECK_ORIGIN (dipisah koma),
  # atau "true"/"false".
  check_origin =
    case env!("CHECK_ORIGIN", :string, nil) do
      nil -> ["#{url_scheme}://#{phx_host}"]
      "true" -> true
      "false" -> false
      list -> String.split(list, ",", trim: true)
    end

  config :stellar_web, StellarWeb.Endpoint,
    url: [host: phx_host, port: url_port, scheme: url_scheme],
    check_origin: check_origin,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      # Port BIND internal (di belakang proxy) tetap PORT (mis. 4000).
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :stellar_web, StellarWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :stellar_web, StellarWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :stellar_web, StellarWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :stellar, Stellar.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  token_signing_secret =
    env!("TOKEN_SIGNING_SECRET", :string, nil) ||
      raise """
      environment variable TOKEN_SIGNING_SECRET is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :stellar, :token_signing_secret, token_signing_secret

  config :stellar, :dns_cluster_query, env!("DNS_CLUSTER_QUERY", :string, nil)
end
