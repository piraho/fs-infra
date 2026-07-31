# FamilyShare — CI/CD Status

**Live API:** `https://163-192-201-183.sslip.io`  ·  **Cluster:** OCI OKE `us-chicago-1` (Always‑Free)

Each service's **`cd`** pipeline runs: **build & test → build `linux/arm64` image → push to GHCR → `helm upgrade` on OKE.**

- 🟢 **Green badge** = latest run built the image, pushed it to GHCR, and deployed it successfully.
- 🔴 Red badge → click it to see which step failed (build / push / deploy).
- **Image** link = that service's GHCR package — its **tags** and **“Published” timestamp** are the proof the new image was pushed.

> Badges render for anyone signed in with access to the (private) service repos.

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
- **E2E smoke lint** (fs-e2e): <https://github.com/piraho/fs-e2e/actions>
- **This chart source**: [`fs-infra`](https://github.com/piraho/fs-infra) · [`deploy/`](./deploy)

_A push to any service's `main` re-runs its `cd`; the badge flips green when the new image is built, pushed, and rolled out._
