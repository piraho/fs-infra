# fs-infra

The composition root for FamilyShare's local development stack: one `docker compose` project that builds and runs every `fs-*` service behind a single **Envoy edge gateway**. Open the app at **http://localhost:8080** — that port is the same-origin front door for both the web UI and the `/api/*` backends.

## Overview

`fs-infra` is where the individual services become a *system*. Each `fs-*` service lives in its own sibling repo; this repo wires them together:

- **`docker-compose.yml`** — declares every service (Postgres, MinIO, Mailpit, Envoy, and the nine `fs-*` Java services + the web frontend), builds the Java services in-container (multi-stage Gradle — no local JDK needed), and puts them all on one Docker network.
- **`gateway/envoy.yaml`** — the Envoy edge config: the single listening port, JWT validation, the public-route allowlist, `/api/<svc>/*` → backend routing, and correlation-id propagation.
- **`Makefile`** — the entry points (`make dev`, `make e2e`, etc.).
- **`docker-compose.override.yml`** — a small local-only port remap so the stack doesn't collide with a native Postgres or Node dev server.

Because the gateway serves the web app and the APIs from the same origin (`:8080`), the frontend calls `/api/...` with no CORS and no per-environment API URLs.

## The stack

Every service defined in `docker-compose.yml`. Host ports are the **base** ports; two are remapped locally by the override file (see the note below).

| Service | Image / Build | Host port | Purpose |
|---|---|---|---|
| `postgres` | `postgres:16` | `5432` | Shared relational database for all nine Java services (single DB `familyshare`, user/password `familyshare`). Has a `pg_isready` healthcheck; other services wait on it. |
| `identity` | build `../fs-identity` | `8081` | Auth service — issues ES256 JWTs and publishes the JWKS at `/.well-known/jwks.json`. Everything else keys off it. |
| `family` | build `../fs-family` | `8082` | Family/household domain. Referenced by nearly every other service via `FAMILY_URL`. |
| `sharing` | build `../fs-sharing` | `8083` | Sharing service (consumed by `profile` and `media` via `SHARING_URL`). |
| `profile` | build `../fs-profile` | `8084` | Profile service (calls `family` and `sharing`). |
| `calendar` | build `../fs-calendar` | `8085` | Calendar service (calls `family` and `escalation`). |
| `escalation` | build `../fs-escalation` | `8086` | Escalation service (calls `family` and `notification`). |
| `notification` | build `../fs-notification` | `8087` | Notification service — sends email through `mailpit` (`SMTP_HOST=mailpit`, `SMTP_PORT=1025`). |
| `media` | build `../fs-media` | `8088` | Media/file service — stores objects in MinIO via the `S3_*` env (`S3_ENDPOINT=http://minio:9000`, public endpoint `http://localhost:9000`). |
| `integration` | build `../fs-integration` | `8089` | External-integration service (calls `family`, `identity`, `profile`). Uses client-credentials / API-key auth in-service. |
| `minio` | `minio/minio` | `9000` (API), `9001` (console) | S3-compatible object storage backing `fs-media`. Root creds `familyshare` / `familyshare-secret`; CORS open (`MINIO_API_CORS_ALLOW_ORIGIN: "*"`). |
| `mailpit` | `axllent/mailpit` | `8025` (web UI) | SMTP sink + inbox viewer for the emails `notification` sends. Listens for SMTP on `1025` inside the network. |
| `gateway` | `envoyproxy/envoy:v1.31-latest` | `8080` | **The front door.** Envoy edge — JWT auth, routing, correlation-id. Mounts `./gateway/envoy.yaml` read-only. |
| `web` | build `../fs-web` | `3000` | Web frontend. Uses same-origin `/api/*` paths (no API URLs configured) — **reach it through the gateway at `:8080`, not `:3000` directly.** |

**Local port override.** `docker-compose.override.yml` (auto-loaded by Compose) remaps only the two host ports that commonly collide with tooling on a dev machine, using `!override` to *replace* rather than append to the base list. Container-internal ports are unchanged, so service-to-service networking is unaffected:

| Service | Base host port | Overridden host port |
|---|---|---|
| `postgres` | `5432` | `15432` |
| `web` | `3000` | `13000` |

**Environment wiring (from the compose `environment:` blocks).**
- Every Java service gets `DATABASE_URL` / `DATABASE_USER` / `DATABASE_PASSWORD` pointing at `postgres:5432`.
- Every resource server (all but `identity`) gets `JWKS_URI: http://identity:8081/.well-known/jwks.json` so it can validate JWTs itself.
- Cross-service calls are wired by explicit URL env vars — e.g. `FAMILY_URL`, `SHARING_URL`, `PROFILE_URL`, `IDENTITY_URL`, `ESCALATION_URL`, `NOTIFICATION_URL` — resolving to Docker DNS names.
- `notification` adds `SMTP_HOST`/`SMTP_PORT`; `media` adds the `S3_*` set.

**Startup ordering (`depends_on`).** `identity` waits for `postgres` to be *healthy*; the other Java services wait for `identity` to be *healthy*; `media` additionally waits for `minio` to start; `web` waits for `identity` and `family`; and `gateway` waits for `identity, family, sharing, profile, calendar, escalation, web`. Persistent volumes: `pgdata` (Postgres) and `miniodata` (MinIO).

## The Envoy edge

`gateway/envoy.yaml` defines a single listener on `0.0.0.0:8080` (`stat_prefix: edge`, `generate_request_id: true`). Its HTTP filter chain runs in this order: **Lua → JWT auth → router**.

### JWT validation at the gateway (DEC-0020)

The `jwt_authn` filter defines one provider, `familyshare`:

- **Issuer:** `https://auth.familyshare.localhost`
- **JWKS:** fetched remotely from `http://identity:8081/.well-known/jwks.json` (via the `identity` cluster, `timeout: 2s`, `cache_duration: 300s`).
- **`forward: true`** — the validated token is passed through to the backend, which re-validates independently. Auth at the edge is **defense in depth, not a bypass**; services still enforce their own auth.

Authorization is decided by an ordered rule list (**first match wins**), so the public routes are listed *before* the catch-all API guard:

**Public allowlist — no JWT required:**

| Rule prefix | Why it's public |
|---|---|
| `/api/identity/v1/users` | Registration |
| `/api/identity/v1/sessions` | Login |
| `/api/identity/v1/tokens` | Token issuance/refresh |
| `/.well-known/` | JWKS + discovery |
| `/api/family/v1/slug-resolutions/` | Public slug lookup |
| `/api/family/v1/invitations/` | Token-in-path proves the invite |
| `/api/integration/v1/integration-tokens` | Client-credentials auth |
| `/api/integration/v1/data/` | `X-Api-Key` auth handled in-service |

**Everything else under `/api/` requires a valid JWT:**

```yaml
- match: { prefix: "/api/" }
  requires: { provider_name: familyshare }   # everything else: JWT at the edge
```

Non-`/api/` paths (the web app served at `/`) match no `jwt_authn` rule, so the frontend itself is served without a token.

### Routing — `/api/<svc>/*` → backend

The single virtual host (`domains: ["*"]`) strips the `/api/<svc>` prefix and forwards to the matching upstream cluster via `prefix_rewrite: "/"`:

| Incoming prefix | Cluster | Rewrite |
|---|---|---|
| `/api/identity/` | `identity` | → `/` |
| `/.well-known/` | `identity` | *(no rewrite — passed as-is)* |
| `/api/family/` | `family` | → `/` |
| `/api/sharing/` | `sharing` | → `/` |
| `/api/profile/` | `profile` | → `/` |
| `/api/calendar/` | `calendar` | → `/` |
| `/api/escalation/` | `escalation` | → `/` |
| `/api/notification/` | `notification` | → `/` |
| `/api/media/` | `media` | → `/` |
| `/api/integration/` | `integration` | → `/` |
| `/` (everything else) | `web` | *(no rewrite)* |

Each cluster is a `STRICT_DNS` upstream with `connect_timeout: 2s`, pointing at the service's Docker DNS name and internal port (e.g. `identity:8081`, `web:3000`). The config spells every cluster out explicitly because Envoy's loader does not support YAML merge-key anchors.

### Correlation-id propagation (DEC-0021)

A Lua filter runs before auth and ensures every request carries a correlation id:

```lua
function envoy_on_request(h)
  if h:headers():get("x-correlation-id") == nil then
    h:headers():add("x-correlation-id", h:headers():get("x-request-id"))
  end
end
```

It **honors a client-supplied `x-correlation-id`**, and otherwise mints one from Envoy's generated `x-request-id`. On the way out, the virtual host echoes it back to the caller via a response header:

```yaml
response_headers_to_add:
  - header: { key: "X-Correlation-Id", value: "%REQ(X-CORRELATION-ID)%" }
```

> `gateway/nginx.conf.superseded` is a retired NGINX version of this edge, kept only for reference — Envoy is the active gateway.

## Makefile targets

| Target | What it does |
|---|---|
| `make dev` | **Build & run the full stack** — `docker compose up --build -d`, then prints the URLs to use (app at `http://localhost:8080`, plus the `identity`/`family` `/actuator/health` endpoints). |
| `make logs` | Tail logs from all services — `docker compose logs -f`. |
| `make down` | Stop and remove the stack — `docker compose down`. |
| `make e2e` | **Run the golden journey against the running stack** — runs `../fs-e2e/smoke.sh` (API smoke test) and then `npx playwright test` from `../fs-web` (browser journey). |

## Running locally

1. **Start everything:**
   ```bash
   make dev
   ```
   The **first run builds the Java services inside Docker** (multi-stage Gradle), so it takes a while; subsequent runs use the build cache. No local JDK is required.

2. **Open the app** at **http://localhost:8080** — this is the Envoy gateway serving the web UI and `/api/*` from the same origin. Do not open `:3000` (or `:13000`) directly; the frontend expects same-origin API paths that only exist behind the gateway.

3. **Run the end-to-end journey** against the running stack:
   ```bash
   make e2e
   ```

**Handy local endpoints:**

| What | URL |
|---|---|
| App (use this) | http://localhost:8080 |
| Mailpit inbox (emails sent by `notification`) | http://localhost:8025 |
| MinIO console (object storage for `media`) | http://localhost:9001 — login `familyshare` / `familyshare-secret` |
| MinIO S3 API | http://localhost:9000 |
| `identity` health | http://localhost:8081/actuator/health |
| `family` health | http://localhost:8082/actuator/health |

Each Java service exposes `/actuator/health` on its own port (`8081`–`8089`); those health checks are what `depends_on: { condition: service_healthy }` waits on.

## Production notes

This repo is the **local** composition root; the production posture swaps the self-hosted stubs for managed services and moves from Compose to Kubernetes. In short:

- **Managed backing services.** Replace the local `postgres` container with managed Postgres, MinIO with S3/GCS, and Mailpit with a real SMTP/email provider — the services already speak the right protocols, so these are credential + endpoint changes (`DATABASE_*`, `S3_*`, `SMTP_*`), not rewrites.
- **Orchestration.** Move from `docker compose` to Kubernetes with a container registry and GitOps (the intended "values-bump PR to fs-infra" model). Early deploy scaffolding exists in this repo — a Helm chart and per-service values under `deploy/`, an Envoy gateway + NGINX ingress manifest set, and OKE Terraform under `terraform/` — but the production Helm/Argo CD wiring is **not yet complete**.
- **Edge hardening.** The gateway currently trusts same-origin; production still needs wildcard TLS, CSP/HSTS/CORS at the edge, and rate limiting on the login/register routes.

For the full, code-grounded checklist (managed-infra swaps, the per-instance JWT-key blocker, passkeys/OAuth, observability, ops hardening), see the bundle's **`PRODUCTION-READINESS.md`** at the repository-bundle root.
