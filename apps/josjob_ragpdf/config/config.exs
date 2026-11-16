import Config

config :josjob_ragpdf,
  start_server: true,
  port: 4010,
  api_token: nil,
  max_concurrency: 1,
  max_active_per_user: 1,
  max_queue_size: 50,
  max_pdf_bytes: 10_000_000,
  max_pages_per_request: 6,
  chunk_overlap_pages: 1,
  job_ttl_seconds: 3_600,
  cleanup_interval_ms: 60_000,
  tmp_dir: Path.join(System.tmp_dir!(), "josjob_ragpdf"),
  qpdf_bin: "qpdf",
  pdftotext_bin: "pdftotext",
  provider_order: [:gemini, :nine_router, :keyword],
  http_client: JosjobRagpdf.HTTP,
  gemini: [
    base_url: "https://generativelanguage.googleapis.com",
    model: "gemini-3.5-flash",
    api_key: nil,
    timeout_ms: 120_000,
    max_attempts: 3,
    base_delay_ms: 1_000
  ],
  nine_router: [
    base_url: "http://127.0.0.1:20128/v1",
    model: "gpt-4o-mini",
    api_key: nil,
    timeout_ms: 120_000,
    max_attempts: 2,
    base_delay_ms: 1_000
  ]

config :logger, level: :info
