# FamilyShare — Deployment Runbook (free-tier: OCI OKE + GHCR + Neon + Vercel)

Exact commands to run the whole project for **$0** on free tiers.
Org `github.com/piraho`. Backend on **OCI Always-Free OKE** (Ampere A1 / **arm64**), images in **GHCR**,
DB on **Neon (free)**, frontend on **Vercel (Hobby)**, CI/CD on **GitHub Actions (free)**.

> 🔐 The Neon connection string shared earlier is exposed — **rotate the Neon password** and use the new one below.
> Never commit real secret values; they only go into Kubernetes Secrets / GitHub secrets.

## What's free vs. what to watch
- Free: OKE control plane (**Basic**), 2× Ampere **A1** nodes within the always-free **4 OCPU / 24 GB** grant, one always-free **10 Mbps** LB, GHCR, GitHub Actions, Neon, Vercel Hobby.
- Watch: **A1 capacity** ("Out of host capacity" on `apply` — retry / try another AD/region); 9 JVMs on 24 GB is tight (fine for demo/staging, not load); `fs-identity` runs **1 replica**.

## Prerequisites
Local tools: `git`, `gh`, `terraform`, `oci` CLI, `kubectl`, `helm`, `docker`.
Accounts: OCI (with a compartment + API signing key), the **piraho** GitHub org, Neon, Vercel, and a **domain** you control.

---

## 1 · Push all repos to `github.com/piraho`
`fs-infra` must be on `main` first (the reusable workflow + Helm chart are pulled from it).
```bash
cd familyshare-complete/code
for r in fs-infra fs-identity fs-family fs-sharing fs-profile fs-calendar fs-escalation \
         fs-notification fs-media fs-integration fs-web fs-e2e; do
  gh repo create piraho/$r --private --source "$r" --remote origin --push
done
```

## 2 · Provision OKE (Terraform, free tier)
```bash
cd fs-infra/terraform
cp terraform.tfvars.example terraform.tfvars      # fill tenancy/compartment/user/fingerprint/private_key_path/region
# verify a supported k8s version: oci ce cluster-options get --cluster-option-id all --query 'data."kubernetes-versions"'
terraform init && terraform apply                 # BASIC cluster + 2× A1 (4 OCPU/24GB) + VCN  → all free
terraform output                                  # note cluster_id (= OKE_CLUSTER_OCID) and region
oci ce cluster create-kubeconfig --cluster-id "$(terraform output -raw cluster_id)" \
  --region "$(terraform output -raw region)" --file ~/.kube/config --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT
kubectl get nodes                                 # 2 Arm nodes Ready (retry apply if A1 capacity was unavailable)
```

## 3 · Ingress + TLS (one free LB, free certs)
```bash
kubectl create namespace familyshare
# ingress-nginx — its Service becomes the single always-free 10 Mbps OCI LB
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
  -f fs-infra/deploy/ingress/ingress-nginx-values.yaml
# cert-manager (Let's Encrypt)
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true
# edit fs-infra/deploy/ingress/clusterissuer.yaml -> your ACME email, then:
kubectl apply -f fs-infra/deploy/ingress/clusterissuer.yaml
```

## 4 · Create the app Secrets (before deploying — pods envFrom these)
```bash
# Postgres (Neon) — use the ROTATED password and the -pooler host:
kubectl -n familyshare create secret generic fs-db \
  --from-literal=DATABASE_URL='jdbc:postgresql://<neon-POOLER-host>/neondb?sslmode=require' \
  --from-literal=DATABASE_USER='neondb_owner' --from-literal=DATABASE_PASSWORD='<ROTATED_PASSWORD>'

# JWT signing key (stable across restarts/replicas) — generate from a local build, no image needed yet:
docker run --rm -v "$PWD/fs-identity":/app -w /app gradle:8.10-jdk21 \
  bash -c 'gradle bootJar -q --no-daemon && java -jar build/libs/*.jar gen-jwk' > jwk.json
kubectl -n familyshare create secret generic fs-jwt --from-file=FAMILYSHARE_JWT_SIGNING_KEY=jwk.json && rm -f jwk.json

# Object storage (OCI Object Storage, S3-compatible — create a bucket + a Customer Secret Key):
kubectl -n familyshare create secret generic fs-media-s3 \
  --from-literal=S3_ENDPOINT='https://<namespace>.compat.objectstorage.<region>.oraclecloud.com' \
  --from-literal=S3_PUBLIC_ENDPOINT='https://<namespace>.compat.objectstorage.<region>.oraclecloud.com' \
  --from-literal=S3_BUCKET='familyshare-media' \
  --from-literal=S3_ACCESS_KEY='<access-key>' --from-literal=S3_SECRET_KEY='<secret-key>'

# Email (OCI Email Delivery or any SMTP):
kubectl -n familyshare create secret generic fs-smtp \
  --from-literal=SMTP_HOST='<smtp-host>' --from-literal=SMTP_PORT='587' \
  --from-literal=SMTP_USER='<user>' --from-literal=SMTP_PASS='<pass>'
```

## 5 · GitHub org secrets (Settings → Secrets → Actions, org-level)
Only OCI (for OKE access) — **no registry secrets** (GHCR uses the built-in `GITHUB_TOKEN`):
`OCI_CLI_USER`, `OCI_CLI_TENANCY`, `OCI_CLI_FINGERPRINT`, `OCI_CLI_KEY_CONTENT`, `OCI_CLI_REGION`, `OKE_CLUSTER_OCID`.
For the Vercel workflow (optional): `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`.
> Private repos: allow `fs-infra` Actions access to the other repos (Settings → Actions → Access), or add a PAT — the service CD checks out `piraho/fs-infra` for the chart.

## 6 · First backend rollout (build arm64 images → push GHCR → helm deploy)
Trigger CI/CD (push each service to `main`, or run **fs-infra → Actions → deploy-all**). Each run cross-builds a `linux/arm64` image to `ghcr.io/piraho/fs-<svc>`, then `helm upgrade`s it.
- **First time only:** GHCR packages default to **private**; the cluster pulls anonymously (no pull secret). After the first push, make each `piraho/fs-<svc>` package **Public** (repo → Packages → Package settings → Change visibility), then re-run `deploy-all`.
- Deploy the gateway (Envoy) — it's a ClusterIP behind ingress:
```bash
kubectl apply -f fs-infra/deploy/gateway/
kubectl -n familyshare get pods            # all fs-* + fs-gateway Running
```

## 7 · DNS + certificate
```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller   # copy EXTERNAL-IP (the free OCI LB)
```
- Create an **A record**: `api.<domain>` → that EXTERNAL-IP.
- Edit `fs-infra/deploy/ingress/ingress.yaml` → set the host to `api.<domain>` (in `rules` and `tls`), then:
```bash
kubectl apply -f fs-infra/deploy/ingress/ingress.yaml
kubectl -n familyshare get certificate -w                    # api-familyshare-tls -> Ready=True (HTTP-01, needs DNS live)
curl https://api.<domain>/.well-known/jwks.json              # backend up, TLS valid
```

## 8 · Frontend on Vercel
- Import `piraho/fs-web` into Vercel (Next.js auto-detected).
- Set env var (Production): **`BACKEND_API_ORIGIN = https://api.<domain>`** — `/api/*` is rewritten there (same-origin, no CORS). Redeploy.
- Point `familyshare.<domain>` (or your apex) at Vercel per its domain setup. Open it and sign up (password ≥10 chars, incl. a letter + a non-letter, e.g. `correct horse 9`).

---

## Day-2
- Ship a service: merge to its `main` → `cd.yml` → auto build(arm64)+push+`helm upgrade`. Rollback: `helm rollback fs-<svc>` or redeploy an older SHA.
- Config change: edit `deploy/values/fs-<svc>.yaml` in `fs-infra`, push, redeploy that service.
- Neon: all 9 services share one `neondb`, each in its own schema (Flyway auto-creates them). Keep the tiny Hikari pool (`SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=3`) — Neon free tier limits connections; always use the `-pooler` host.

## Known caveats (by design on free tier)
- `fs-identity` = 1 replica (memory + JWT key). It now loads a **stable** key from `fs-jwt`, so restarts don't invalidate tokens; scaling >1 is safe once you raise the resource budget.
- JWT **issuer must match**: `FAMILYSHARE_JWT_ISSUER` (`deploy/values/fs-identity.yaml`) == Envoy `jwt_authn` issuer (`deploy/gateway/configmap.yaml`) = `https://auth.familyshare.com`.
- Edge hardening in place: login/register **rate-limit** + **HSTS** at Envoy; frontend HSTS/CSP in `fs-web/vercel.json`.
- A1 capacity is the most common `apply` blocker — retry or switch AD/region.
```
