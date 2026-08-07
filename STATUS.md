# FamilyShare — CI/CD & Production Status

**Live API:** `https://163-192-201-183.sslip.io`  ·  **Cluster:** OCI OKE `us-chicago-1` (Always‑Free)

---

## 🟢 Live production status (what's actually running on OKE)

Auto-refreshed hourly by the [`status-sync`](https://github.com/piraho/fs-infra/actions/workflows/status-sync.yml) workflow (run it manually for an instant refresh). It reads the running image tag (the deployed **git SHA**, linked to its commit) straight from the cluster, and compares its digest to the newest image built from `main` (GHCR `:latest`).

- **Running in prod** = the commit currently serving traffic.
- **Matches latest build?** — ✅ `latest` = prod is on the newest image built from `main`; ⬆️ `behind` = a newer image exists that prod hasn't rolled out yet.

<!-- LIVE:START -->
_Live status — last synced 2026-08-07 07:46 UTC (auto). Trigger `status-sync` to refresh now._

| Service | Ready | Running in prod (image) | Matches latest build? |
|---------|:-----:|-------------------------|:---------------------:|
| **fs-identity** | 1/1 | [`0e7036f`](https://github.com/piraho/fs-identity/commit/0e7036f5f8279f574df4ccbf0f68c6d86fae09e4) | ✅ latest |
| **fs-family** | 1/1 | [`5903973`](https://github.com/piraho/fs-family/commit/5903973dd53fe42b5c0b15a075bd9f8fe4370418) | ✅ latest |
| **fs-sharing** | 1/1 | [`be4712d`](https://github.com/piraho/fs-sharing/commit/be4712dd275be9afcfadc74436f9ec58fdd0f5e6) | ✅ latest |
| **fs-profile** | 1/1 | [`eda61bd`](https://github.com/piraho/fs-profile/commit/eda61bd82b9b55214274a6dae44feeb5362dd8de) | ✅ latest |
| **fs-calendar** | 1/1 | [`e883ea0`](https://github.com/piraho/fs-calendar/commit/e883ea0358d2774d6ae7b1e0ebc7ffa491633037) | ✅ latest |
| **fs-escalation** | 1/1 | [`71d5f98`](https://github.com/piraho/fs-escalation/commit/71d5f989abb5d60f2563aaf36191d6462601826e) | ✅ latest |
| **fs-notification** | 1/1 | [`84ab958`](https://github.com/piraho/fs-notification/commit/84ab958648d5d0efbccf812aa9a297754fd5fb90) | ✅ latest |
| **fs-media** | 1/1 | [`a0017e8`](https://github.com/piraho/fs-media/commit/a0017e820c045ce3f0f6dfa2d852c68e1032fa8b) | ✅ latest |
| **fs-integration** | 1/1 | [`5431b2b`](https://github.com/piraho/fs-integration/commit/5431b2b8236af584b70571c7783e00bad810ef1f) | ✅ latest |
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
