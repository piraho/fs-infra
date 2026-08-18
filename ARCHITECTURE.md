# fs-infra — Architecture

> The **composition root**. Where twelve independently deployable services become one system — locally as a
> 16-container compose stack, in production as Helm releases on an OCI free-tier Kubernetes cluster behind
> an Envoy edge.
> Companion to [`README.md`](./README.md), [`DEPLOYMENT.md`](./DEPLOYMENT.md),
> [`DB-MIGRATIONS.md`](./DB-MIGRATIONS.md), and [`STATUS.md`](./STATUS.md).
> Governed by the [Architecture Documentation Standard](./docs/ARCHITECTURE-STANDARD.md) —
> every diagram is compiled in CI. **This repo is also the source of truth for that standard and its tooling.**

| | |
|---|---|
| **Local** | `docker compose` — 16 containers, one network, one front door on `:8080` |
| **Production** | OCI OKE (Ampere A1, **arm64**), 2 nodes within the always-free 4 OCPU / 24 GB grant |
| **Images** | GHCR (`ghcr.io/piraho`), public — no pull secret |
| **Database** | Neon (free tier), one database, **schema per service** |
| **Frontend** | Vercel (Hobby) for fs-web; also containerised behind Envoy locally |
| **Namespace** | `familyshare` |

---

## 1. Responsibility

**Owns.** The local compose stack · the Envoy edge configuration (JWT validation, public-route allowlist,
`/api/<svc>/*` routing, correlation-id injection) · the `familyshare-service` Helm chart and per-service
values · Terraform for the OKE cluster and VCN · ingress, cert-manager, external-secrets, and the
Loki/Grafana logging stack · database reset and migration jobs · **the Architecture Documentation Standard
and its `scripts/`**, which every other repo copies.

**Does not own.** Any business logic. fs-infra is wiring — and the one place where a change affects every
service at once.

---

## 2. System context

### 2.1 Local development

```mermaid
flowchart TB
  DEV[Developer<br/>make dev]

  subgraph compose[docker compose - one network]
    GW[gateway<br/>Envoy :8080<br/>THE front door]
    WEB[web<br/>Next.js]
    subgraph svcs[Java services, built in-container]
      S1[identity :8081]
      S2[family :8082]
      S3[sharing :8083]
      S4[profile :8084]
      S5[calendar :8085]
      S6[escalation :8086]
      S7[notification :8087]
      S8[media :8088]
      S9[integration :8089]
      S10[ai :8090]
      S11[assistant :8091]
    end
    PG[(postgres:16<br/>db familyshare)]
    MIN[(minio :9000<br/>console :9001)]
    MP[mailpit :8025<br/>catches every email]
  end

  DEV --> GW
  GW -->|"/"| WEB
  GW -->|"/api/identity/*"| S1
  GW -->|"/api/family/*"| S2
  GW -->|"/api/sharing/*"| S3
  GW -->|"/api/profile/*"| S4
  GW -->|"/api/calendar/*"| S5
  GW -->|"/api/escalation/*"| S6
  GW -->|"/api/notification/*"| S7
  GW -->|"/api/media/*"| S8
  GW -->|"/api/integration/*"| S9
  GW -->|"/api/ai/*"| S10
  GW -->|"/api/assistant/*"| S11
  S1 & S2 & S3 & S4 & S5 & S6 & S7 & S8 & S9 & S10 & S11 --> PG
  S8 --> MIN
  S7 --> MP

  linkStyle default stroke-width:1.5px
```

**One port, same origin.** Envoy serves the web app and every `/api/*` backend on `:8080`, so the frontend
needs no CORS handling and no per-environment API URL. The Java services build **inside** the containers via
a multi-stage Gradle build — no local JDK required, which is what makes `make dev` a single command on a
fresh machine.

### 2.2 Production

```mermaid
flowchart TB
  USER[Users]
  VERCEL[Vercel Hobby<br/>fs-web]
  DNS[DNS A record<br/>api host]

  subgraph oci[OCI Always-Free tenancy]
    LB[OCI Load Balancer<br/>10 Mbps always-free]
    subgraph oke[OKE cluster - namespace familyshare]
      ING[ingress-nginx<br/>+ cert-manager letsencrypt-prod]
      GWP[Envoy gateway<br/>Deployment + ConfigMap]
      subgraph pods[12 Helm releases - chart familyshare-service]
        P[fs-identity · fs-family · fs-sharing · fs-profile<br/>fs-calendar · fs-escalation · fs-notification<br/>fs-media · fs-integration · fs-ai · fs-assistant · fs-health]
      end
      ES[external-secrets]
      LOKI[Loki + Grafana]
    end
    BUCKET[(OCI Object Storage<br/>S3-compatible)]
  end

  NEON[(Neon Postgres<br/>schema per service)]
  GHCR[GHCR ghcr.io/piraho<br/>arm64 images, public]

  USER --> VERCEL
  USER --> DNS --> LB --> ING --> GWP --> P
  P --> NEON
  P --> BUCKET
  GHCR -.->|image pull| P
  ES -.->|secrets| P
  P -.->|logs| LOKI

  linkStyle default stroke-width:1.5px
```

**Everything here is free-tier, and the constraints show.** Two A1 nodes hold 24 GB for twelve JVMs, so
memory sizing is not a tuning exercise — it is the binding constraint on how many services can run at all.

---

## 3. Component structure

```mermaid
flowchart TB
  subgraph local[Local]
    DC[docker-compose.yml<br/>16 services]
    OV[docker-compose.override.yml<br/>port remaps]
    MK[Makefile<br/>make dev · make e2e]
  end

  subgraph edge[Edge]
    ENV[gateway/envoy.yaml<br/>JWT · allowlist · routing · Lua correlation-id]
    GWD[deploy/gateway/<br/>Deployment · Service · ConfigMap]
  end

  subgraph k8s[Kubernetes]
    CHART[deploy/chart/<br/>familyshare-service]
    VALS[deploy/values/fs-*.yaml<br/>one per service]
    INGR[deploy/ingress/<br/>ingress · nginx values · clusterissuer]
    SEC[deploy/secrets/<br/>external-secrets]
    LOG[deploy/logging/<br/>loki · grafana]
    JOBS[deploy/scripts/<br/>reset-data jobs]
  end

  subgraph iac[Terraform]
    OKE[oke.tf<br/>cluster + A1 node pool]
    NET[network.tf<br/>VCN, public + private subnets]
    VAULT[vault.tf]
  end

  subgraph std[Documentation standard - copied to every repo]
    AS[docs/ARCHITECTURE-STANDARD.md]
    CM[scripts/check-mermaid.sh + lint-mermaid.mjs]
    CD[scripts/check-docs-in-sync.sh]
  end

  MK --> DC --> OV
  DC --> ENV
  CHART --> VALS
  GWD --> ENV
  OKE --> NET
  AS --> CM & CD
```

---

## 4. Data model

**Not applicable — fs-infra owns no schema.** It owns the *topology* of everyone else's:

```mermaid
erDiagram
  DATABASE ||--o{ SCHEMA : "contains"
  SCHEMA   ||--o| SERVICE : "owned by exactly one"

  DATABASE {
    string name    "familyshare - ONE database"
    string host    "postgres:16 local · Neon in production"
  }
  SCHEMA {
    string name        "identity · family · sharing · profile · calendar · escalation"
    string more        "notification · media · integration · ai · health · mail"
    string migrated_by "each service's own Flyway"
  }
  SERVICE {
    string name
    string port
    string ddl "Hibernate validate - Flyway owns DDL"
  }
```

**One database, schema per service (DEC-0024/0035).** Free-tier Neon gives one database; isolation is by
schema, and each service migrates only its own. The rules that keep this honest:

- **No cross-schema foreign keys.** Cross-service references are by value (`members.user_id`,
  `person_identity.ref_id`). An FK would weld two services into one migration unit.
- **`mail` is the one shared schema**, written by fs-identity and drained by the dreamlit provider.
- **Every service is `ddl-auto=validate`** — Flyway owns DDL; a drifted mapping fails at boot, not in prod.

---

## 5. Request flows

### 5.1 Edge request handling

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant E as Envoy
  participant S as Backend service

  C->>+E: request
  E->>E: is the path on the PUBLIC allowlist?
  alt public route (login, register, JWKS, verifications)
    E->>S: forward, no JWT required
  else protected
    E->>E: validate ES256 against the cached JWKS
    alt invalid or missing
      E-->>C: 401 - the service is never reached
    else valid
      E->>E: Lua: inject X-Correlation-Id
      E->>S: forward + claims + correlation id
    end
  end
  S-->>C: response
  deactivate E
  Note over E,S: the allowlist is the highest-risk config in the platform:<br/>too narrow blocks sign-up, too wide exposes an endpoint.
```

**This is where a real bug lived.** `/v1/verifications` was missing from the allowlist, so Envoy 401'd
email verification — every service's own tests passed, and sign-up was broken in the browser. It was caught
by fs-e2e, which is precisely why that suite drives everything through the edge.

### 5.2 Deploy

```mermaid
sequenceDiagram
  autonumber
  actor D as Maintainer
  participant G as Git - main
  participant CI as Build (arm64)
  participant GH as GHCR
  participant H as Helm
  participant K as OKE

  D->>G: merge to main
  G->>CI: build arm64 image
  CI->>GH: push ghcr.io/piraho/fs-<svc>:<tag>
  D->>H: helm upgrade --install fs-<svc> chart -f values/fs-<svc>.yaml --set image.tag
  H->>K: apply Deployment + Service
  K->>K: rolling update, probes must pass
  K->>GH: pull image
  Note over D,CI: GitHub Actions on this org stopped firing (minutes exhausted).<br/>Backend builds and deploys currently run LOCALLY - see DEPLOYMENT.md.
  Note over H,K: the Helm RELEASE NAME becomes the in-cluster DNS name,<br/>so fs-family is reachable at http://fs-family - rename at your peril.
```

### 5.3 Migration on deploy

```mermaid
sequenceDiagram
  autonumber
  participant K as Pod starting
  participant F as Flyway
  participant N as Neon
  participant H as Hibernate

  K->>F: run migrations for THIS service's schema only
  F->>N: apply pending V*.sql
  F-->>K: schema at target version
  K->>H: ddl-auto = validate
  H->>N: compare mappings to the migrated schema
  alt mismatch
    H-->>K: FAIL FAST - pod does not start
  else match
    K->>K: serve traffic
  end
```

---

## 6. State machines

```mermaid
stateDiagram-v2
  direction LR
  [*] --> Pending : Deployment applied
  Pending --> Starting : image pulled
  Starting --> Migrating : Flyway runs
  Migrating --> Validating : Hibernate validate
  Validating --> Ready : probes pass
  Validating --> CrashLoop : mapping drift
  Migrating --> CrashLoop : migration failure
  Starting --> OOMKilled : heap over the limit
  OOMKilled --> Starting : restart
  Ready --> Terminating : rolling update
  Terminating --> [*]
  note right of OOMKilled
    Twelve JVMs on 24 GB. Memory limits and
    MaxRAMPercentage are load-bearing config,
    not tuning preferences.
  end note
```

---

## 7. Failure modes & invariants

| Invariant | Rule |
|---|---|
| One front door | All client traffic goes through Envoy — never a service port |
| Allowlist is explicit | Public routes are enumerated; everything else needs a valid JWT |
| Correlation everywhere | `X-Correlation-Id` is injected at the edge and propagated |
| Schema per service | No cross-schema FKs; each service migrates only its own |
| Flyway owns DDL | Every service is `ddl-auto=validate` |
| Release name = DNS name | Renaming a Helm release renames the in-cluster host |
| arm64 | A1 nodes are ARM — an amd64 image will not run |

| Failure | Blast radius | Notes |
|---|---|---|
| **Envoy misconfigured** | **Total** | Highest-risk config on the platform. A missing allowlist entry breaks sign-up; an over-broad one exposes an endpoint |
| **JVM heap over the limit** | Per service, restarts | Resolved by 512→768Mi + `MaxRAMPercentage=60`; zero restarts since |
| Neon unavailable | Total | Single free-tier database |
| A1 capacity exhausted | Cannot provision | "Out of host capacity" on `terraform apply` — retry, or another AD/region |
| GHCR unreachable | New pods cannot start | Running pods unaffected |
| Signing key not shared | Intermittent 401s platform-wide | `FAMILYSHARE_JWT_SIGNING_KEY` **must** be one shared secret |

### The network posture, stated plainly

The cluster runs the **flannel** CNI, which does **not enforce NetworkPolicies**. Every `/internal/*`
endpoint is therefore protected by a **shared `X-Internal-Key`**, not by network isolation — an interim
control (H4), not the intended end state. Anyone reasoning about the security of `/internal/*` should start
from that fact rather than assuming pod-level segmentation exists.

---

## 8. Change protocol

| When you change… | Redraw / update |
|---|---|
| `docker-compose.yml` | §2.1 · README service table |
| `gateway/envoy.yaml` | §2.1 · §5.1 · §7 — **run fs-e2e**, the allowlist is where sign-up breaks |
| `deploy/chart/**` or `deploy/values/**` | §2.2 · §3 · §6 |
| `terraform/**` | §2.2 · `DEPLOYMENT.md` |
| a new service | §2.1 **and** §2.2 · §4 (its schema) · a values file · an Envoy route |
| resource limits | §6 · §7 — the memory envelope is a hard constraint |
| **the Architecture Standard or `scripts/`** | re-distribute to **every** repo — this repo is the source of truth |

CI enforces this: `scripts/check-docs-in-sync.sh` (`deploy/**`, `gateway/**`, `terraform/**` are all
architecture-significant here) + `scripts/check-mermaid.sh`.
