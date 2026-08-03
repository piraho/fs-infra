# FamilyShare — CI/CD & Production Status

**Live API:** `https://163-192-201-183.sslip.io`  ·  **Cluster:** OCI OKE `us-chicago-1` (Always‑Free)

---

## 🟢 Live production status (what's actually running on OKE)

Auto-refreshed hourly by the [`status-sync`](https://github.com/piraho/fs-infra/actions/workflows/status-sync.yml) workflow (run it manually for an instant refresh). It reads the running image tag (the deployed **git SHA**, linked to its commit) straight from the cluster, and compares its digest to the newest image built from `main` (GHCR `:latest`).

- **Running in prod** = the commit currently serving traffic.
- **Matches latest build?** — ✅ `latest` = prod is on the newest image built from `main`; ⬆️ `behind` = a newer image exists that prod hasn't rolled out yet.

<!-- LIVE:START -->
_Live status — last synced 2026-08-03 04:50 UTC (auto). Trigger `status-sync` to refresh now._

| Service | Ready | Running in prod (image) | Matches latest build? |
|---------|:-----:|-------------------------|:---------------------:|
| **fs-identity** | 1/1 | [`edbe083`](https://github.com/piraho/fs-identity/commit/edbe0834f20114377efc16955ac700cac9f98971) | ✅ latest |
| **fs-family** | 1/1 | [`f79ba01`](https://github.com/piraho/fs-family/commit/f79ba01a7242d193b80ac4f64b86e1dc3597f176) | ✅ latest |
| **fs-sharing** | 1/1 | [`1f2219d`](https://github.com/piraho/fs-sharing/commit/1f2219db6f17fcb5a25ceb7ce9234c381db5847c) | ✅ latest |
| **fs-profile** | 1/1 | [`056ed23`](https://github.com/piraho/fs-profile/commit/056ed237ea90b0c574f2b7d2e6f3c7b7dc07f7c8) | ✅ latest |
| **fs-calendar** | 1/1 | [`782f6a5`](https://github.com/piraho/fs-calendar/commit/782f6a5be277edc56a6be568b38be6beaf050c88) | ✅ latest |
| **fs-escalation** | 1/1 | [`1081aa6`](https://github.com/piraho/fs-escalation/commit/1081aa6445066580c4100066ca46ab7a16ba585e) | ✅ latest |
| **fs-notification** | 1/1 | [`05da28f`](https://github.com/piraho/fs-notification/commit/05da28f34cfcef8e4fb5cb50b2e5dfd8f2715c1e) | ✅ latest |
| **fs-media** | 1/1 | [`2e91d6e`](https://github.com/piraho/fs-media/commit/2e91d6e0640fac0d084629c224bec5ce0276c123) | ✅ latest |
| **fs-integration** | 1/1 | [`76ecdfc`](https://github.com/piraho/fs-integration/commit/76ecdfce1ae99aee354efd1b85b8252da0f75316) | ✅ latest |
<!-- LIVE:END -->

---

## ⚙️ Pipelines (build → push → deploy, per service)

Each service's **`cd`**: build & test → build `linux/arm64` image → push to GHCR → `helm upgrade` on OKE.
🟢 green = the latest `main` push built, pushed, and deployed OK. The **Image** link is the GHCR package (its *Published* time = when the image was last pushed).

| Service | Port | Build → Push → Deploy | Image (GHCR) |
|---------|:----:|-----------------------|--------------|
| **fs-identity**     | 8081 | [![cd](https://github.com/piraho/fs-identity/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-identity/actions/workflows/cd.yml)         | [package](https://github.com/piraho/fs-identity/pkgs/container/fs-identity) |
| **fs-family**       | 8082 | [![cd](https://github.com/piraho/fs-family/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-family/actions/workflows/cd.yml)             | [package](https://github.com/piraho/fs-family/pkgs/container/fs-family) |
| **fs-sharing**      | 8083 | [![cd](https://github.com/piraho/fs-sharing/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-sharing/actions/workflows/cd.yml)           | [package](https://github.com/piraho/fs-sharing/pkgs/container/fs-sharing) |
| **fs-profile**      | 8084 | [![cd](https://github.com/piraho/fs-profile/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-profile/actions/workflows/cd.yml)           | [package](https://github.com/piraho/fs-profile/pkgs/container/fs-profile) |
| **fs-calendar**     | 8085 | [![cd](https://github.com/piraho/fs-calendar/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-calendar/actions/workflows/cd.yml)         | [package](https://github.com/piraho/fs-calendar/pkgs/container/fs-calendar) |
| **fs-escalation**   | 8086 | [![cd](https://github.com/piraho/fs-escalation/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-escalation/actions/workflows/cd.yml)     | [package](https://github.com/piraho/fs-escalation/pkgs/container/fs-escalation) |
| **fs-notification** | 8087 | [![cd](https://github.com/piraho/fs-notification/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-notification/actions/workflows/cd.yml) | [package](https://github.com/piraho/fs-notification/pkgs/container/fs-notification) |
| **fs-media**        | 8088 | [![cd](https://github.com/piraho/fs-media/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-media/actions/workflows/cd.yml)               | [package](https://github.com/piraho/fs-media/pkgs/container/fs-media) |
| **fs-integration**  | 8089 | [![cd](https://github.com/piraho/fs-integration/actions/workflows/cd.yml/badge.svg?branch=main)](https://github.com/piraho/fs-integration/actions/workflows/cd.yml)   | [package](https://github.com/piraho/fs-integration/pkgs/container/fs-integration) |

## Handy links
- **All images at a glance** (with *Published* times): <https://github.com/orgs/piraho/packages>
- **Refresh live status now**: <https://github.com/piraho/fs-infra/actions/workflows/status-sync.yml> → **Run workflow**
- **E2E smoke lint** (fs-e2e): <https://github.com/piraho/fs-e2e/actions>

_A push to any service's `main` re-runs its `cd`; the badge flips green when the new image is built, pushed, and rolled out — then `status-sync` shows it live above._
