# josjob_ragpdf — PDF CV extraction microservice

Standalone Elixir service that turns an uploaded PDF CV into structured data
(skills, experience, education) for JosJob F6.

It exists separately from `josjob_rag` on purpose: `josjob_rag` is the document
RAG/indexer used by the main app, while this service owns the
**PDF → chunk → LLM → merged CV JSON** pipeline and its queue.

> **Not part of the JosJob umbrella.** This directory is a standalone Mix
> project. It is intentionally absent from the root `apps:` list, the OTP
> release, and the root `mix precommit`. Deploy it as its own service.

## Status (verified 2026-11-16)

Verified against the real Gemini API, not just fakes:

- 1-page PDF uploaded over HTTP → `done` in ~17s with correct skills,
  experience and education (`provider: "gemini"`, `model: "gemini-3.5-flash"`).
- 7-page PDF → 2 chunks (6 pages + 1-page overlap), both succeeded, merged
  result `done` containing skills from every page.
- `mix test`: 158 tests, 0 failures (no network, no API key needed).
  `mix compile --warnings-as-errors` and `mix format --check-formatted` clean.

Model availability moves fast. On 2026-11-16 `gemini-2.5-flash` returned 404
("no longer available to new users") and `gemini-3.8-flash` returned 503 /
timeouts under load. Default is therefore `gemini-3.5-flash`; use
`RAGPDF_GEMINI_MODEL` to pin another one, e.g. `gemini-3.5-flash-lite` for
lower latency. List what your key can actually use:

```bash
curl -s -H "x-goog-api-key: $GEMINI_API_KEY" \
  https://generativelanguage.googleapis.com/v1beta/models \
  | jq -r '.models[] | select(.supportedGenerationMethods | index("generateContent")) | .name'
```

Not wired yet: the JosJob backend does not call this service, the 9Router
fallback has never run against a real instance, and the queue does not survive
a restart.

---

## Why a queue

Gemini accepts **one file per request** and effectively **6 pages per request**.
A CV longer than 6 pages must be split and processed in several LLM calls.

This service therefore:

1. validates the PDF,
2. splits it into chunks of at most 6 pages (1-page overlap by default),
3. enqueues the job immediately (`202 Accepted`) so the user can leave,
4. processes chunks with bounded concurrency,
5. merges the chunk results and exposes progress via polling.

The queue is **in-memory** (ETS + GenServer + `Task.Supervisor`). There is no
Redis and no Postgres/Oban in this service. Consequence: **a service restart
loses queued and in-flight jobs.** That is an accepted hackathon trade-off and
is listed under [Limitations](#limitations).

---

## Pipeline

```
HTTP (Bandit + Plug.Router)
  POST   /v1/cv/analyses        -> validate + enqueue, 202
  GET    /v1/cv/analyses/:id    -> status, progress, result
  DELETE /v1/cv/analyses/:id    -> cancel / delete
  GET    /v1/queue              -> queue stats (auth)
  GET    /health                -> public liveness probe
  GET    /                      -> public service info

JosjobRagpdf.Queue (GenServer, in-memory FIFO, per-user fairness)
  -> Task.Supervisor (JosjobRagpdf.TaskSupervisor)
  -> JosjobRagpdf.Worker.run(job)
       -> JosjobRagpdf.Pdf.validate/page_count/chunk_ranges/split
       -> JosjobRagpdf.AI.extract_chunk/2
            -> JosjobRagpdf.Providers.Gemini        (primary, PDF inline)
            -> JosjobRagpdf.Providers.NineRouter    (text fallback, OpenAI-compatible)
            -> JosjobRagpdf.Providers.Keyword       (deterministic last resort)
       -> JosjobRagpdf.Merge.merge/1
       -> JosjobRagpdf.Jobs.update/2
```

Provider order is configurable (`RAGPDF_PROVIDER_ORDER`) but restricted to the
fixed allowlist `gemini,nine_router,keyword`. There is no free-form user prompt:
the prompt and JSON schema are server-side constants in `JosjobRagpdf.Prompt`.

---

## Status contract

```
queued -> processing -> done | partial | unreadable | failed
```

| Status | Meaning |
| --- | --- |
| `queued` | accepted, waiting for a worker slot |
| `processing` | chunk extraction in progress (`chunks_done / chunks_total`) |
| `done` | every chunk succeeded and the merged result is non-empty |
| `partial` | some chunks failed, or the merged result has no useful fields |
| `unreadable` | not a valid/readable PDF (bad file, zero pages, wrong magic bytes) |
| `failed` | all chunks/providers failed, or the job crashed |

`GET /v1/cv/analyses/:id` includes `progress` (0.0–1.0), `chunks_done`,
`chunks_total`, `provider`, `model`, `warnings`, and `result`.

`result` shape:

```json
{
  "skills": [{ "name": "Elixir", "confidence": 0.9, "source": "gemini" }],
  "experience": [
    {
      "title": "Backend Engineer",
      "company": "ACME",
      "start_date": "2024-01",
      "end_date": "2025-06",
      "description": "..."
    }
  ],
  "education": [
    {
      "degree": "B.Sc. Computer Science",
      "institution": "University",
      "field": "Computer Science",
      "start_date": "2020-08",
      "end_date": "2024-06"
    }
  ],
  "extraction_confidence": 0.82
}
```

---

## HTTP API

Success bodies are wrapped in `{"data": ...}`. Errors use:

```json
{ "error": "validation_failed", "message": "invalid or missing fields",
  "fields": { "user_id": "is required" } }
```

### Upload a PDF (multipart)

```bash
curl -sS -X POST http://127.0.0.1:4010/v1/cv/analyses \
  -H "Authorization: Bearer $RAGPDF_API_TOKEN" \
  -F "user_id=user_123" \
  -F "cv_id=cv_123" \
  -F "idempotency_key=cv_123-v1" \
  -F "known_skills=[\"Elixir\",\"PostgreSQL\",\"React\"]" \
  -F "file=@/path/to/cv.pdf;type=application/pdf"
```

`202 Accepted`:

```json
{
  "data": {
    "id": "job_...",
    "status": "queued",
    "queue_position": 0,
    "cv_id": "cv_123",
    "filename": "cv.pdf",
    "progress": 0.0,
    "inserted_at": "2026-11-16T10:00:00Z"
  }
}
```

Sending the same `user_id` + `idempotency_key` again returns `200` with the
existing job instead of creating a duplicate.

### Upload by URL or base64 (JSON)

```bash
curl -sS -X POST http://127.0.0.1:4010/v1/cv/analyses \
  -H "Authorization: Bearer $RAGPDF_API_TOKEN" \
  -H "content-type: application/json" \
  -d '{
    "user_id": "user_123",
    "file_url": "https://example.com/cv.pdf",
    "known_skills": ["Elixir", "SQL"]
  }'
```

`content_base64` is accepted the same way (a `data:application/pdf;base64,`
prefix is stripped). Exactly one of `file`, `file_url`, `content_base64` is
required.

### Poll

```bash
curl -sS http://127.0.0.1:4010/v1/cv/analyses/job_... \
  -H "Authorization: Bearer $RAGPDF_API_TOKEN"
```

### Cancel / delete

```bash
curl -sS -X DELETE http://127.0.0.1:4010/v1/cv/analyses/job_... \
  -H "Authorization: Bearer $RAGPDF_API_TOKEN"
# 204, or 404 if unknown
```

Queued jobs are removed. Active jobs are killed. Terminal jobs are deleted from
the store. The job temp directory is always removed.

### Auth

If `RAGPDF_API_TOKEN` is set, every `/v1/*` request must send either
`Authorization: Bearer <token>` or `x-api-key: <token>`. `/health` and `/` stay
public. If the token is empty, auth is disabled (local development only).

---

## Configuration

Copy `.env.example` to `.env` (gitignored). In dev/prod the service also reads
`../../envs/.env` from the repo root, so an existing `GOOGLE_API_KEY` is picked
up automatically. The test environment reads **no secret files**.

| Variable | Default | Purpose |
| --- | --- | --- |
| `RAGPDF_PORT` | `4010` | Bandit port |
| `RAGPDF_API_TOKEN` | empty | optional bearer/`x-api-key` shared secret |
| `RAGPDF_START_SERVER` | `true` | start Bandit (set `false` for `iex -S mix`) |
| `RAGPDF_MAX_CONCURRENCY` | `1` | globally active workers |
| `RAGPDF_MAX_ACTIVE_PER_USER` | `1` | active jobs per `user_id` |
| `RAGPDF_MAX_QUEUE_SIZE` | `50` | pending jobs before `429` |
| `RAGPDF_MAX_PDF_BYTES` | `10000000` | upload limit (10 MB) |
| `RAGPDF_MAX_PAGES_PER_REQUEST` | `6` | Gemini page limit per chunk |
| `RAGPDF_CHUNK_OVERLAP_PAGES` | `1` | overlap between chunks |
| `RAGPDF_JOB_TTL_SECONDS` | `3600` | finished jobs kept in memory |
| `RAGPDF_CLEANUP_INTERVAL_MS` | `60000` | cleanup tick |
| `RAGPDF_HTTP_TIMEOUT_MS` | `120000` | provider HTTP timeout |
| `RAGPDF_RETRY_MAX_ATTEMPTS` | `3` | provider retries |
| `RAGPDF_RETRY_BASE_DELAY_MS` | `1000` | exponential backoff base |
| `RAGPDF_QPDF_BIN` | `qpdf` | PDF split/page-count binary |
| `RAGPDF_PDFTOTEXT_BIN` | `pdftotext` | text fallback binary |
| `GEMINI_API_KEY` | — | preferred Gemini key |
| `GOOGLE_API_KEY` | — | fallback if `GEMINI_API_KEY` is unset |
| `RAGPDF_GEMINI_MODEL` | `gemini-3.5-flash` | pinned extraction model |
| `RAGPDF_GEMINI_BASE_URL` | `https://generativelanguage.googleapis.com` | Gemini API base |
| `NINE_ROUTER_BASE_URL` | `http://127.0.0.1:20128/v1` | 9Router (blind-set) |
| `NINE_ROUTER_API_KEY` | empty | 9Router key |
| `NINE_ROUTER_MODEL` | `gpt-4o-mini` | 9Router model |
| `RAGPDF_PROVIDER_ORDER` | `gemini,nine_router,keyword` | fallback order |

The API key is sent as the `x-goog-api-key` header, never in the query string,
and is never logged.

Config names are service-prefixed on purpose. `apps/josjob_ragpdf` loads the shared
`envs/.env` first, and that file pins `GEMINI_MODEL` to an embedding model for
the main app, so the extraction model is read from `RAGPDF_GEMINI_MODEL`
instead. Never leave a blank `GEMINI_API_KEY=` / `GOOGLE_API_KEY=` in
`apps/josjob_ragpdf/.env`; a blank value shadows the key from `envs/.env`.

Naming: the directory, the OTP app (`:josjob_ragpdf`) and the modules
(`JosjobRagpdf.*`, `JosjobRagpdfWeb.*`) follow the repo convention of the other
`josjob_*` apps. Env vars keep the short `RAGPDF_` prefix documented above.

> **9Router is blind-set and untested.** It is configured as an
> OpenAI-compatible fallback on loopback. Treat it as unavailable until a real
> instance is running. The keyword provider is the deterministic last resort.

---

## Running

NixOS (no global Elixir needed):

```bash
cd apps/josjob_ragpdf
nix-shell          # elixir + qpdf + poppler-utils
mix deps.get
mix run --no-halt  # starts Bandit on :4010
```

Or without `shell.nix`:

```bash
nix-shell -p elixir qpdf poppler-utils --run "mix deps.get && mix run --no-halt"
```

For development with a shell:

```bash
RAGPDF_START_SERVER=true iex -S mix
```

Check it:

```bash
curl -sS http://127.0.0.1:4010/health | jq
```

---

## Testing

```bash
cd apps/josjob_ragpdf
nix-shell --run "mix test"
```

The suite has **no real Gemini/9Router calls and needs no API keys**. Providers
are tested with an injected fake HTTP client; PDF tests skip gracefully when
`qpdf`/`pdftotext` are not installed.

Also useful:

```bash
mix compile --warnings-as-errors
mix format --check-formatted
```

---

## Limitations

- **In-memory queue:** jobs are lost on restart; there is no persistence and no
  cross-node coordination. Run a single instance.
- **No per-user rate limit** beyond `max_active_per_user` and
  `max_queue_size`. Add a real rate limiter before exposing publicly.
- **Results expire:** terminal jobs are removed after `RAGPDF_JOB_TTL_SECONDS`.
  The main app should copy the result into its own `Cv` record.
- **No object storage integration:** the service accepts a multipart upload, a
  URL, or base64. Downloading from a private S3 bucket (presigned GET) is the
  caller's job.
- **No raw CV logging:** the service never logs PDF bytes or extracted text,
  but the caller must still treat `result` as personal data.
- **9Router path is unverified** (blind configuration only).

---

## Integrating with the main JosJob app

1. Main app uploads/proxies the PDF to `POST /v1/cv/analyses` with the
   candidate's `user_id` and its own `cv_id`.
2. Main app stores the returned `job id` on the `Cv` record and returns `202` to
   Flutter.
3. Flutter polls `GET /v1/cv/analyses/:id` (or the main app proxies it).
4. On `done`/`partial`, the main app persists `result` and provenance
   (`provider`, `model`) into the `Cv` record.
5. On `unreadable`/`failed`, the UI asks for a better PDF; no ranking is built.

Protect the service with `RAGPDF_API_TOKEN` and keep it on the private network.
