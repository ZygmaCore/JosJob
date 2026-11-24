# Local preview refresh, 2026-11-23

The landing page at localhost:8081 was still served by the frontend image built
on 2026-11-17. Current source changes and seeded database records do not replace
a compiled Flutter web bundle. Both app images were rebuilt and their running
containers recreated against the existing local database.

The first backend rebuild failed while reading Windows-inaccessible symlinks
inside the standalone PDF service's generated `_build` tree. The root Docker
ignore file now excludes nested `_build` and `deps` trees, plus task output and
temporary files. Source PDF fixtures under the web app remain in the image.

Nginx now revalidates fixed-name Flutter bundles/bootstrap and metadata, alongside
its existing index/service-worker rules. A browser that already loaded the old
app may need one hard refresh. The landing page is available to signed-in users
as well at http://localhost:8081/#/welcome.

Verification:

- Both new frontend/backend images were deployed; runtime database/auth settings
  matched the prior container configuration.
- Nginx configuration validation passed.
- The served main.dart.js fingerprint changed from the old running bundle.
- Main JS, bootstrap, Flutter loader, version, manifest and index responses all
  returned `Cache-Control: no-cache`.
- The current landing hero and search action rendered at 1440px and 390px, with
  no browser page errors; screenshots were visually inspected.
- All six seeded candidate accounts logged in through the updated API and
  received the expected first job with `method: category_skill`, among 20 active
  CV-demo jobs. Existing database volumes were reused.
- `mix precommit` passed, including 120 RAG tests and 211 web tests.

For future local source updates, rebuild and recreate the app services:

```sh
docker compose -f docker-compose.fullstack.yml build josjob_fe josjob_be
docker compose -f docker-compose.fullstack.yml up -d --no-deps josjob_be josjob_fe
```

The build context excludes frontend projects from the backend release as before;
the separate frontend build still uses `apps/josjob_fe`. No data-reset command or
volume removal is part of this refresh.
