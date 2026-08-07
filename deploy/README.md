# FamilyShare — Kubernetes deploy layer (Helm)

Manifests to run the FamilyShare backend on an **Oracle Cloud Always-Free**
Kubernetes cluster (4 OCPU / 24 GB Arm, shared by ~11 pods). Ten Spring Boot
services + an Envoy edge gateway, all in the `familyshare` namespace. The browser
app is on Vercel and proxies same-origin `/api/*` to the cluster's edge.

Retargeted from the original OKE/OCIR plan to run cheaply on free tier:

- **Images: GitHub Container Registry (GHCR), public.** Images resolve to
  `ghcr.io/piraho/fs-<svc>:<tag>`. Because they are public, **no image-pull
  secret is required** (the chart's `imagePullSecrets` defaults to `[]`).
- **Database: Neon (serverless Postgres).** All services share one Neon project
  via the **pooler** endpoint; each service keeps a tiny Hikari pool so the free
  tier's connection cap is respected.
- **Tight resource defaults** so ~11 pods co-exist on 4 OCPU / 24 GB (see below).

## Layout

```
deploy/
  chart/                 generic Helm chart "familyshare-service" (one release per svc)
  values/                per-service values (fs-identity.yaml ... fs-assistant.yaml)
  gateway/               Envoy gateway: configmap + deployment + service
  ingress/               cert-manager + ingress-nginx + Ingress (TLS lives here)
  base/                  namespace + secrets.example.yaml
  README.md              this file
```

One chart, ten releases. The **release name is the object name** — deploy as
`fs-identity`, `fs-family`, … so in-cluster DNS resolves to `http://fs-<svc>:<port>`.

| Service | Port | Secrets (envFrom) |
|---|---|---|
| fs-identity | 8081 | fs-db, fs-jwt |
| fs-family | 8082 | fs-db |
| fs-sharing | 8083 | fs-db |
| fs-profile | 8084 | fs-db |
| fs-calendar | 8085 | fs-db |
| fs-escalation | 8086 | fs-db |
| fs-notification | 8087 | fs-db, fs-smtp |
| fs-media | 8088 | fs-db, fs-media-s3 |
| fs-integration | 8089 | fs-db |
| fs-assistant | 8091 | fs-internal-auth |
| fs-gateway (Envoy) | 8080 | — |

## Prerequisites

- `kubectl` pointed at the cluster, and `helm` v3.
- A GHCR org `piraho` with **public** `fs-<svc>` packages. No registry login and
  no pull secret needed for a deploy.
- A Neon project (free tier). You need its **pooled** connection string.

## 1. Namespace

```bash
kubectl apply -f base/namespace.yaml
```

## 2. Secrets (never commit real values)

`base/secrets.example.yaml` is a TEMPLATE. Create the real Secrets imperatively
so credentials never touch git. Four Secrets back the stack: `fs-db`, `fs-jwt`,
`fs-media-s3`, `fs-smtp`.

> Security: the Neon connection string was pasted into chat and is considered
> **exposed** — rotate the Neon password before serving real data.

```bash
# fs-db : Neon Postgres — use the POOLER host and keep sslmode=require.
kubectl -n familyshare create secret generic fs-db \
  --from-literal=DATABASE_URL='jdbc:postgresql://<neon-pooler-host>/neondb?sslmode=require' \
  --from-literal=DATABASE_USER='neondb_owner' \
  --from-literal=DATABASE_PASSWORD='<rotate-me>'

# fs-jwt : EC P-256 (ES256) JWK signing key for fs-identity. Generate to a file
# (JSON is shell-hostile), then load the file as the secret key.
docker run --rm ghcr.io/piraho/fs-identity:latest gen-jwk > jwk.json
kubectl -n familyshare create secret generic fs-jwt \
  --from-file=FAMILYSHARE_JWT_SIGNING_KEY=jwk.json
rm -f jwk.json

# fs-media-s3 : OCI Object Storage, S3-compatible endpoint.
kubectl -n familyshare create secret generic fs-media-s3 \
  --from-literal=S3_ENDPOINT='https://<ns>.compat.objectstorage.<region>.oraclecloud.com' \
  --from-literal=S3_PUBLIC_ENDPOINT='https://<public-cdn-or-bucket>' \
  --from-literal=S3_BUCKET='familyshare-media' \
  --from-literal=S3_ACCESS_KEY='<access-key>' \
  --from-literal=S3_SECRET_KEY='<secret-key>'

# fs-smtp : email relay.
kubectl -n familyshare create secret generic fs-smtp \
  --from-literal=SMTP_HOST='<smtp-host>' \
  --from-literal=SMTP_PORT='587'
```

Each Secret's keys are projected verbatim as env vars (chart `envFrom`), so the
key names above are the contract the services read.

### Neon pooler + Hikari pool size

Neon's free tier limits total connections, so **every** service caps its pool at
`SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=3` (set in each `values/fs-*.yaml`).
Always connect through the Neon **pooler** host (the `-pooler` endpoint) with
`sslmode=require`, not the direct compute host.

### fs-jwt signing key

`fs-identity` signs ES256 access tokens with the EC P-256 JWK in `fs-jwt`
(`FAMILYSHARE_JWT_SIGNING_KEY`) and publishes the matching public key at
`/.well-known/jwks.json`. Generate a key with:

```bash
docker run --rm ghcr.io/piraho/fs-identity:latest gen-jwk
```

### No image-pull secret

GHCR images are public, so there is **nothing to create** for image pulls. The
chart's `imagePullSecrets` defaults to `[]`. (If you later switch to a private
registry, populate `imagePullSecrets` in values and create the secret per
namespace.)

## 3. Deploy one service

The chart defaults `image.registry=ghcr.io/piraho`, so a normal deploy only needs
the per-service values file and the image tag:

```bash
helm upgrade --install fs-identity ./chart \
  -n familyshare \
  -f values/fs-identity.yaml \
  --set image.tag=<sha>
```

Repeat per service (`fs-family`, `fs-sharing`, …), each with its own values file.
`image.tag` defaults to `latest`; pass the built image SHA per deploy. This is
the "values-bump PR" model — CI bumps `image.tag` and re-runs the upgrade.

Deploy everything in one pass:

```bash
for svc in identity family sharing profile calendar escalation notification media integration assistant; do
  helm upgrade --install fs-$svc ./chart -n familyshare \
    -f values/fs-$svc.yaml \
    --set image.tag=<sha>
done
```

### Resource sizing (free tier)

Chart defaults are tuned for the 4 OCPU / 24 GB Arm cluster shared by ~11 pods:

- requests: `cpu: 100m`, `memory: 256Mi`
- limits:   `cpu: 500m`, `memory: 512Mi`
- `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=70.0` (chart-wide default env) keeps
  each JVM heap (~358Mi max) inside the 512Mi memory limit.
- HPA is **disabled by default** (no autoscaling headroom on free tier); it stays
  templated so a specific service can opt in later.

### fs-identity constraint (must read)

`fs-identity` runs **replicas=1** and its **HPA and PDB are disabled** — for both
memory economy on the free tier and because tokens are signed with a single JWK.
The signing key now comes from the `fs-jwt` Secret (`FAMILYSHARE_JWT_SIGNING_KEY`),
so it is shared/stable rather than generated per instance; still keep identity at
one replica until autoscaling headroom exists.

`FAMILYSHARE_JWT_ISSUER` in `values/fs-identity.yaml` **must match** the `issuer`
in `gateway/configmap.yaml` (both currently `https://auth.familyshare.com`).

## 4. Deploy the gateway (Envoy)

```bash
kubectl apply -f gateway/configmap.yaml
kubectl apply -f gateway/deployment.yaml
kubectl apply -f gateway/service.yaml
```

The gateway validates ES256 JWTs at the edge (public routes excepted) and proxies
`/api/<svc>/*` → the matching Service, plus `/.well-known/` → identity. Edit the
ConfigMap and bump the `fs.familyshare.com/config-revision` pod annotation to roll
Envoy on config changes.

## 5. Ingress / DNS / TLS

TLS and public routing live in the **`ingress/`** dir (added by a separate
change), not in this chart. That change:

- adds **cert-manager** (ACME/Let's Encrypt) and **ingress-nginx**,
- adds an **Ingress** that fronts the Envoy gateway and terminates TLS, and
- makes the Envoy gateway `Service` **ClusterIP** (no per-service LoadBalancer —
  free tier has a single LB, owned by ingress-nginx).

See `ingress/` for those manifests and their README. Point the
`*.familyshare.com` (or single-host) DNS record at the ingress-nginx LB address.

## What you must fill in

- Image tags/SHAs (GHCR packages must be public).
- The Neon **pooler** connection string for `fs-db` (rotate the exposed password).
- The `fs-jwt` signing key (`gen-jwk`), plus `fs-media-s3` and `fs-smtp` values
  (and `SMTP_USER`/`SMTP_PASS` for a real relay).
- The production JWT issuer (keep identity + gateway in sync).
- DNS + cert-manager issuer config for TLS (see `ingress/`).
```
