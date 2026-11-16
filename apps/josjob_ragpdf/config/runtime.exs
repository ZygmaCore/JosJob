import Config
import Dotenvy

# Dev/prod boleh memakai envs/.env milik repo utama + .env lokal service.
# Test sengaja tidak membaca file secret supaya suite tidak pernah menyentuh
# API key asli.
env_files =
  if config_env() == :test do
    []
  else
    [
      Path.expand("../../../envs/.env", __DIR__),
      Path.expand("../.env", __DIR__)
    ]
    |> Enum.filter(&File.exists?/1)
  end

source!(env_files ++ [System.get_env()])

integer = fn key, default ->
  case env!(key, :string, nil) do
    nil -> default
    "" -> default
    value -> String.to_integer(value)
  end
end

boolean = fn key, default ->
  case env!(key, :string, nil) do
    nil -> default
    value -> value in ["1", "true", "TRUE", "yes", "on"]
  end
end

blank_to_nil = fn
  nil ->
    nil

  value ->
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
end

provider_order =
  case env!("RAGPDF_PROVIDER_ORDER", :string, nil) do
    nil ->
      nil

    value ->
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.flat_map(fn
        "gemini" -> [:gemini]
        "nine_router" -> [:nine_router]
        "keyword" -> [:keyword]
        _ -> []
      end)
  end

gemini_api_key =
  blank_to_nil.(env!("GEMINI_API_KEY", :string, nil)) ||
    blank_to_nil.(env!("GOOGLE_API_KEY", :string, nil))

gemini = [
  base_url:
    env!("RAGPDF_GEMINI_BASE_URL", :string, nil) || "https://generativelanguage.googleapis.com",
  model: env!("RAGPDF_GEMINI_MODEL", :string, nil) || "gemini-3.5-flash",
  api_key: gemini_api_key,
  timeout_ms: integer.("RAGPDF_HTTP_TIMEOUT_MS", 120_000),
  max_attempts: integer.("RAGPDF_RETRY_MAX_ATTEMPTS", 3),
  base_delay_ms: integer.("RAGPDF_RETRY_BASE_DELAY_MS", 1_000)
]

nine_router = [
  base_url: env!("NINE_ROUTER_BASE_URL", :string, nil) || "http://127.0.0.1:20128/v1",
  model: env!("NINE_ROUTER_MODEL", :string, nil) || "gpt-4o-mini",
  api_key: blank_to_nil.(env!("NINE_ROUTER_API_KEY", :string, nil)),
  timeout_ms: integer.("RAGPDF_HTTP_TIMEOUT_MS", 120_000),
  max_attempts: integer.("RAGPDF_RETRY_MAX_ATTEMPTS", 2),
  base_delay_ms: integer.("RAGPDF_RETRY_BASE_DELAY_MS", 1_000)
]

config :josjob_ragpdf,
  port: integer.("RAGPDF_PORT", 4010),
  api_token: blank_to_nil.(env!("RAGPDF_API_TOKEN", :string, nil)),
  start_server: config_env() != :test and boolean.("RAGPDF_START_SERVER", true),
  max_concurrency: integer.("RAGPDF_MAX_CONCURRENCY", 1),
  max_active_per_user: integer.("RAGPDF_MAX_ACTIVE_PER_USER", 1),
  max_queue_size: integer.("RAGPDF_MAX_QUEUE_SIZE", 50),
  max_pdf_bytes: integer.("RAGPDF_MAX_PDF_BYTES", 10_000_000),
  max_pages_per_request: integer.("RAGPDF_MAX_PAGES_PER_REQUEST", 6),
  chunk_overlap_pages: integer.("RAGPDF_CHUNK_OVERLAP_PAGES", 1),
  job_ttl_seconds: integer.("RAGPDF_JOB_TTL_SECONDS", 3_600),
  cleanup_interval_ms: integer.("RAGPDF_CLEANUP_INTERVAL_MS", 60_000),
  tmp_dir: env!("RAGPDF_TMP_DIR", :string, nil) || Path.join(System.tmp_dir!(), "josjob_ragpdf"),
  qpdf_bin: env!("RAGPDF_QPDF_BIN", :string, nil) || "qpdf",
  pdftotext_bin: env!("RAGPDF_PDFTOTEXT_BIN", :string, nil) || "pdftotext",
  http_client: JosjobRagpdf.HTTP,
  gemini: gemini,
  nine_router: nine_router

if provider_order do
  config :josjob_ragpdf, provider_order: provider_order
end
