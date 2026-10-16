# AGENTS.md

## Repository Purpose

IPTV-Manager is a Node.js/Express IPTV management server with:

- Web UI under `public/`
- REST/Xtream/HDHomeRun endpoints under `src/routes/` and `src/controllers/`
- SQLite persistence under `DATA_DIR`
- optional Redis stream tracking
- Docker and bare-metal deployment paths

Treat changes as production backend changes. Preserve user data, stream
reliability, authentication behavior, and Docker upgrade compatibility.

## Working Rules

- Prefer small, focused fixes.
- Read the relevant controller, route, service, and DB schema before editing.
- When changing routes, environment variables, setup, Docker behavior, or
  integration behavior, update `README.md`, `docs/API_REFERENCE.md`,
  `docs/CONFIGURATION.md`, or `docs/DEVELOPMENT.md` as relevant.
- Do not commit runtime data, databases, secrets, cache files, or temp upload
  data.
- Do not introduce new dependencies unless clearly justified.
- Keep API responses backward-compatible unless explicitly requested.
- Avoid broad refactors in controllers that handle streaming, auth, provider
  sync, EPG, imports/exports, or database migrations.
- `provider_access` is disabled for normal users by default and controls only
  upstream provider management and connection-details visibility. Provider
  names/options and catalog rows remain available for list editing; restricted
  catalog responses must omit raw stream URLs, HTTP headers, and DRM metadata.
  It must not remove a user's ability to edit their own channel, movie, series,
  or category-scoped EPG mappings.

## Package and Build Rules

- Primary package manager: `npm`.
- Docker and GitHub release use `package-lock.json` with `npm ci`.
- If dependencies change, update `package.json` and `package-lock.json`
  together.
- `pnpm-lock.yaml` may exist, but do not treat it as the Docker source of
  truth unless the build pipeline is changed too.

## Runtime Data Rules

Runtime data defaults to the repo root unless `DATA_DIR` is set. Docker uses
`DATA_DIR=/data`.

Never commit:

- `db.sqlite*`
- `epg.db*`
- `secret.key`
- `jwt.secret`
- `cache/`
- `temp_*`
- `temp_uploads/`

When running tests locally, prefer an isolated data dir for tests that touch the
real DB:

```bash
DATA_DIR="$(mktemp -d)" npm test
```

## Database and Migration Rules

- Migrations run from `initDb(true)` in the primary process before workers
  start.
- Migrations must be idempotent.
- Heavy migrations must be guarded by schema checks or marker rows in
  `settings`.
- Avoid repeated `VACUUM`, full-table rewrites, or unbounded startup work.
- Preserve existing user/provider/channel IDs unless a migration explicitly
  requires a remap.
- When changing user clone, import/export, provider sync, category mapping, or
  EPG mapping, add focused regression coverage.

## Docker Rules

- Docker runtime runs as non-root `app`.
- Do not recursively `chown /app` at container start. `/app` contains
  `node_modules`; recursive ownership fixes there can make startup very slow.
- `/data` ownership may be fixed for backward compatibility, but only when
  needed.
- Keep `.dockerignore` excluding local DBs, secrets, caches, temp data, reports,
  and host dependencies.

## Validation

Run available checks relevant to the change:

1. `npm run lint`
2. targeted `npm test -- <test file>` or `npm exec vitest run <test file>`
3. `npm test` when practical
4. `npm run build`

If full `npm test` fails because of existing unrelated tests or environment
paths, report the exact failing suites and run targeted coverage for the change.

Keep smoke coverage current for:

- Express app route registration and security middleware
- API and configuration documentation
- Docker and runtime-data ignore rules
- user clone/import/export/provider-sync regressions
- normal-user provider visibility and continued channel/movie/series/EPG list
  editing

The Playwright smoke test starts its own ephemeral server and uses a temporary
`DATA_DIR` when none is configured. Keep that isolation behavior so browser
tests do not write to the repository's runtime database.

## Base44 Sandbox Preview

Sandbox-only run path: `docker-compose.base44.yml` plus
`docker/base44.dev.Dockerfile`. The repository is bind-mounted and the start
command runs `npm ci --omit=dev` from `package-lock.json`, then
`node --watch src/server.js` — so edits under `src/` restart the server and
edits under `public/` are served on reload.

- Never point that compose at the project's own `Dockerfile` or the `ghcr.io`
  image: both bake a production copy of `src`/`public`, and edits would never
  reach the preview.
- The sandbox checks the repository out as `0700 root`, so the dev container
  runs as root — a non-root user cannot read the bind mount. The deployed image
  still drops privileges as usual.
- `DATA_DIR=/data` on a volume, so `db.sqlite`, `epg.db`, `cache/`,
  `jwt.secret` and `secret.key` stay out of the repository. The
  `base44-node-modules` and `base44-npm-cache` volumes keep start-up installs
  fast; drop those volumes to force a clean dependency install.
- No external credentials are needed to boot. JWT/encryption keys are generated
  into `DATA_DIR`, and IPTV provider accounts plus the optional MaxMind key are
  entered in the Web UI. `.env.base44-defaults` only seeds the dev admin login
  (`admin` / `base44-dev-admin`) and is listed first so that
  `/run/base44/app.env` overrides it. The app forces a password change at that
  first sign-in.
- No application code is gated on `BASE44_PREVIEW_MODE`: Express has no host or
  origin allowlist, so the preview host needs no configuration.
- Healthcheck probes `GET /` (Web UI) and `POST /api/login` with no
  credentials, which must answer 400 — that reaches SQLite, so a broken database
  answers 500 instead. The login route is `/api/login`, not `/api/auth/login`.
- A signed-in session cannot be verified automatically: the first successful
  sign-in raises a native `alert()`, which blocks the preview browser's page
  thread. Verify the credential path through `POST /api/login`, and drive the
  signed-in UI by hand.
