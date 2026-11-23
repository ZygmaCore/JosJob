# Multiple CV accounts and seeded job listings

This explicit local/demo seed creates six fictional candidates, their individual
PDFs and saved CV profiles, one employer, and 22 jobs. Twenty jobs are active;
one is draft and one is expired. Nothing runs automatically on startup.

The seed has been run against the local `paradedb / josjob_dev` database. All
seven account logins, candidate CV skills, resume PDF downloads and the active
job count were checked through the running API. Category ordering was checked
against the current source with each saved CV. The local frontend/backend images were rebuilt on 2026-11-23; the running API
now verifies the expected per-account category ordering and the latest landing page.

## Accounts

Every new account initially uses password **`JosJobDemo123!`**. Re-running the
seed preserves changed passwords and matching demo records.

| Role | Email | Expected first job within this demo set |
| --- | --- | --- |
| Backend developer | `backend@cv-demo.josjob.test` | Elixir Backend Engineer [CV Demo] |
| Frontend developer | `frontend@cv-demo.josjob.test` | React Frontend Developer [CV Demo] |
| Product designer | `design@cv-demo.josjob.test` | Product Designer [CV Demo] |
| Data analyst | `data@cv-demo.josjob.test` | Data Analyst [CV Demo] |
| Accountant | `finance@cv-demo.josjob.test` | Financial Accountant [CV Demo] |
| Barista | `hospitality@cv-demo.josjob.test` | Cafe Barista [CV Demo] |
| Employer | `employer@cv-demo.josjob.test` | Manage the 22 seeded listings |

The first six accounts have completed onboarding, graduate access, distinct
skills/experience/education, a selected owned PDF and an account-scoped saved
category profile. Their PDFs contain fictional names and explicit demo labels.
The employer has posting/management permissions only in the separate
**CV Relevance Demo Company [Demo]** organization. No applications are seeded.

## Try the different orderings

1. Open <http://localhost:8081> and sign in using a candidate account.
2. On the current rebuilt Jobs page, use **Most relevant to my CV**.
3. Search **CV Demo** to isolate this controlled set. The same 20 active jobs
   remain available to each candidate, but the first role changes as above.
4. Switch accounts in separate browser profiles/private windows and compare.
5. Sign in as the employer to see all 22 records, including draft/expired jobs.

Every candidate has one full-skill match, partial matches and skill-gap examples.
The strongest exact-skill job is deliberately older than its partial matches,
so the demo verifies that recency does not outrank CV relevance. The catalog also
contains related full-stack/DevOps roles and unrelated roles further down.
Existing jobs elsewhere in the database may also be relevant; use the search
above when comparing the expected first jobs.

## Run the seed again

From the repository root in a configured Linux/Elixir development environment:

```sh
mix ecto.migrate
mix run apps/josjob/priv/repo/cv_relevance_seeds.exs
```

For a **rebuilt** local release that includes `JosjobRag.DemoSeeds`:

```powershell
docker exec job-seeker-ai-josjob_be-1 bin/josjob rpc 'case JosjobRag.DemoSeeds.seed() do {:ok, result} -> IO.inspect(result); {:error, reason} -> raise inspect(reason) end'
```

The default PDF base URL is `http://localhost:4000`. Set
`JOSJOB_DEMO_BASE_URL` before seeding a different demo host, or call
`JosjobRag.DemoSeeds.seed(base_url: "https://your-demo-api.example")`.
Previously seeded document URLs are preserved, so use the intended URL on the
first run. Production credentials/data are not needed for this local demo.

## Reusable source data and PDFs

- Seed entry: `apps/josjob/priv/repo/cv_relevance_seeds.exs`.
- Implementation: `JosjobRag.DemoSeeds` in `apps/josjob_rag`.
- Manifest: `apps/josjob_rag/priv/demo/cv_relevance.json`.
- Versioned individual PDFs: `apps/josjob_web/priv/static/assets/demo-cvs/`.
- Download URLs: `/assets/demo-cvs/backend.pdf`, `frontend.pdf`, `design.pdf`,
  `data.pdf`, `finance.pdf`, and `hospitality.pdf` under the same directory.
- Combined review-only pack: `output/pdf/demo-cv-pack.pdf`. Use an individual
  PDF, not this six-person pack, for upload tests.

After editing the manifest, regenerate the one-page PDFs using:

```sh
python -m pip install reportlab pypdf
python scripts/generate_cv_demo_pdfs.py
```

The generator checks page counts and extracted skills and produces stable PDF
bytes for unchanged input. Saved CV version IDs match the individual PDF hashes,
so uploading an unchanged fixture reuses its seeded facts without an AI call.
Provenance is honestly marked `synthetic_demo`; this seed does not claim that an
AI provider extracted these facts. It exercises matching and caching, not live
Gemini/9Router extraction.

## Rerun behavior and verification

The seed runs transactionally and uses an advisory lock to serialize concurrent
runs. It reuses reserved demo emails, the marked organization, memberships,
documents, CV versions and job titles. It refuses unexpected account/organization
collisions, preserves job edits and password changes, and does not reset other
CVs that a candidate later selects. Renaming/deleting a seeded job lets the
original title be created again on a later run.

Automated checks cover distinct CV ownership, expected first jobs for all six
accounts, publication filtering, repeatability, preserved edits/passwords,
collision rollback and public fictional PDF downloads. PDF text and all six
rendered pages were also inspected. No AI tokens are consumed by seeding.

Validation: `mix precommit` passed, including 120 RAG tests and 211 web tests.
The explicit seed was run twice on `josjob_dev` with the same account IDs and
22 jobs afterward. Seven live API logins, six private CV profiles, six PDF URLs
and the 20-active-job count passed. All six expected relevance leaders were
verified against the current source, with no AI calls.
