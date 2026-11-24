# Manual vacancy and hiring demo

For six accounts with different CVs and a separate relevance-testing catalog,
see [the multi-account CV demo](cv-relevance-demo.md). The seed below remains
separate and focuses on applications and chat.

Open <http://localhost:8081>. These local accounts share a fictional organization,
**JosJob Demo Company [Demo]**. Both use password `JosJobDemo123!`.

| Role | Email |
| --- | --- |
| Candidate | `candidate@demo.josjob.test` |
| Employer | `employer@demo.josjob.test` |

Use separate browser profiles or a normal/private window to keep both sessions
open. Existing accounts and organizations are unaffected. Vacancies and example
profiles are clearly marked as fictional; the records persist in the local Docker
database when the containers restart.

Active vacancies are public (D22, 2026-11-18). You can also browse at
<http://localhost:8081/#/jobs> while signed out, or apply using your own registered
account without joining the demo organization. The demo candidate alone owns
the five example applications; other accounts start with their own empty history.

## Apply from scratch

1. Log in as the candidate and open **Jobs → Vacancies**.
2. Choose **Junior Backend Developer [Demo]**, **Flutter Developer [Demo]**,
   **UI/UX Design Intern [Demo]**, **Data Analyst [Demo]**, or **Content Writer [Demo]**.
3. Open the vacancy, select **Apply for this role**, review the saved profile,
   give consent, and submit. The candidate has a saved fictional CV profile;
   attach your own test PDF from Curriculum Vitae if desired.
4. In the employer window, open the same vacancy and select **Review applicants**.
5. Open the application and move it through
   **Applied → Reviewing → Interview → Offer → Hired**. Try shared notes,
   an interview date and **Open chat** in both windows.
6. On another application, try rejection or candidate withdrawal. Closed
   applications keep their history and chat becomes read-only.

## Start at an existing stage

Five example applications already belong to the demo candidate:

| Vacancy | Initial application stage |
| --- | --- |
| QA Engineer [Demo] | Applied |
| Frontend Developer [Demo] | Reviewing |
| Product Designer [Demo] | Interview |
| Customer Support Specialist [Demo] | Offer |
| DevOps Engineer [Demo] | Hired |

Each has two starter chat messages. Open **Applications** as the candidate or
switch to **Hiring** as the employer. The interview example has a future time.

The employer's **Manage listings** also includes **Technical Writer [Demo]**
(draft) and **Operations Assistant [Demo]** (expired). Try editing, publishing,
and filtering those statuses. There are 12 vacancies in total, initially 10 active.

## Run the seed explicitly

The additive seed is `apps/josjob/priv/repo/manual_job_seeds.exs`. It is not called
on normal application startup. With the local stack running, execute from the
repository root in PowerShell (use Docker Desktop's full path if necessary):

```powershell
$docker = 'docker.exe'
& $docker --context desktop-linux cp apps/josjob/priv/repo/manual_job_seeds.exs josjob-josjob_be-1:/tmp/manual_job_seeds.exs
& $docker --context desktop-linux exec josjob-josjob_be-1 bin/josjob rpc 'Code.eval_file(~s(/tmp/manual_job_seeds.exs))'
```

Re-running reuses matching demo accounts, memberships and vacancy titles, and
preserves existing applications and their progress. It does not reset edited
records or passwords. Renaming or deleting a seeded vacancy allows the original
title to be created again on the next run. Keep this seed on your local database.
