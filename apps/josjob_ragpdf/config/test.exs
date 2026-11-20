import Config

config :josjob_ragpdf,
  start_server: false,
  max_concurrency: 1,
  max_active_per_user: 1,
  max_queue_size: 10,
  job_ttl_seconds: 60,
  cleanup_interval_ms: 60_000,
  provider_order: [],
  gemini: [
    base_url: "https://generativelanguage.googleapis.com",
    model: "gemini-3.5-flash",
    api_key: nil,
    timeout_ms: 1_000,
    max_attempts: 1,
    base_delay_ms: 0
  ],
  nine_router: [
    base_url: "http://127.0.0.1:20128/v1",
    model: "gpt-4o-mini",
    api_key: nil,
    timeout_ms: 1_000,
    max_attempts: 1,
    base_delay_ms: 0
  ]

config :logger, level: :warning
