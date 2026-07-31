# FamilyShare — CI/CD & Production Status

**Live API:** `https://163-192-201-183.sslip.io`  ·  **Cluster:** OCI OKE `us-chicago-1` (Always‑Free)

---

## 🟢 Live production status (what's actually running on OKE)

Auto-refreshed hourly by the [`status-sync`](https://github.com/piraho/fs-infra/actions/workflows/status-sync.yml) workflow (run it manually for an instant refresh). It reads the running image tag (the deployed **git SHA**, linked to its commit) straight from the cluster, and compares its digest to the newest image built from `main` (GHCR `:latest`).

- **Running in prod** = the commit currently serving traffic.
- **Matches latest build?** — ✅ `latest` = prod is on the newest image built from `main`; ⬆️ `behind` = a newer image exists that prod hasn't rolled out yet.

<!-- LIVE:START -->
_Live status — last synced 2026-07-31 20:38 UTC (auto). Trigger `status-sync` to refresh now._

| Service | Ready | Running in prod (image) | Matches latest build? |
|---------|:-----:|-------------------------|:---------------------:|
| **fs-identity** | 1/1 | [`2cc7645`](https://github.com/piraho/fs-identity/commit/2cc7645d8dfbc146b12caee601a4aa452f0e3379) | ✅ latest |
| **fs-family** | 1/1 | [`de11307`](https://github.com/piraho/fs-family/commit/de113077494de360f8a4e08b02df47853ea6d17c) | ✅ latest |
| **fs-sharing** | 1/1 | [`1f2219d`](https://github.com/piraho/fs-sharing/commit/1f2219db6f17fcb5a25ceb7ce9234c381db5847c) | ✅ latest |
| **fs-profile** | 1/1 | [`95b4013`](https://github.com/piraho/fs-profile/commit/95b40138a4f1ff6f2c68115147c6387ab585e532) | ✅ latest |
| **fs-calendar** | 1/1 | [`e40477c`](https://github.com/piraho/fs-calendar/commit/e40477cc4779049077f91abb5efa8a1607f26f44) | ✅ latest |
| **fs-escalation** | 1/1 | [`84138d2`](https://github.com/piraho/fs-escalation/commit/84138d241e4508a706db0a5775a528612565eaca) | ✅ latest |
| **fs-notification** | 1/1 | [`bca709b`](https://github.com/piraho/fs-notification/commit/bca709b52490dfbd33072592acb10685e727d543) | ✅ latest |
| **fs-media** | 1/1 | [`a17f19e`](https://github.com/piraho/fs-media/commit/a17f19ecd6232385348527712f6a6b63e4c6a001) | ✅ latest |
| **fs-integration** | 1/1 | [`96b75d8`](https://github.com/piraho/fs-integration/commit/96b75d83e1db0bc8f3934cc1a92385a8ff9f7338) | ✅ latest |
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
