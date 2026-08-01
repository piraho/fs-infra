# Logging — Loki + Promtail + Grafana (OKE Always Free)

Centralized logs for the `familyshare` namespace on the single-node Ampere A1 cluster.
Promtail tails every pod's stdout/stderr; Loki stores it (10-day retention); Grafana reads it.

> **This directory only holds config — nothing is deployed until you run the commands below.**

## What it is

| Piece    | Role                                    | Footprint (limits) |
|----------|-----------------------------------------|--------------------|
| Loki     | log store, single binary, 50Gi PVC      | 500m CPU / 512Mi   |
| Promtail | DaemonSet, tails node's container logs  | 200m CPU / 256Mi   |
| Grafana  | UI + pre-wired Loki datasource          | 300m CPU / 256Mi   |

Free-tier choices are documented inline in [`loki-values.yaml`](loki-values.yaml): single
replica, 50Gi (OCI Block Volume minimum), 10-day compactor retention, explicit resource limits.

## Install

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Release name MUST be "loki" (values assume service `loki` + secret `loki-grafana`).
helm upgrade --install loki grafana/loki-stack \
  --namespace logging \
  -f deploy/logging/loki-values.yaml

kubectl -n logging rollout status statefulset/loki --timeout=5m
```

## Access Grafana

Get the generated admin password:

```bash
kubectl -n logging get secret loki-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

**Default — port-forward (no public exposure, zero extra cost):**

```bash
kubectl -n logging port-forward svc/loki-grafana 3000:80
# open http://localhost:3000   (user: admin, password: from above)
```

**Optional — public HTTPS via the existing ingress-nginx:** apply
[`grafana-ingress.yaml`](grafana-ingress.yaml) (confirm the host/DNS first). This rides the
**same** ingress-nginx LoadBalancer the API already uses — it does **not** create a second LB,
so it stays within the one free flexible LB.

## Query

In Grafana → **Explore** → Loki datasource:

```logql
{namespace="familyshare"}                                  # everything
{namespace="familyshare", pod=~"fs-identity.*"}            # one service
{namespace="familyshare"} |= "x-correlation-id"            # trace one request across services
{namespace="familyshare"} | json | level="ERROR"           # errors only
```

The gateway stamps `x-correlation-id` on every request (Envoy Lua filter), so grepping that id
follows a request through fs-gateway → each service.

## Notes / gotchas

- **Storage:** 50Gi is the OCI Block Volume minimum — a smaller PVC is rounded up and wastes the
  request. `oci-bv` is `WaitForFirstConsumer`, so the volume binds when the Loki pod schedules.
- **Retention:** the compactor deletes chunks older than 240h (10 days). Change `retention_period`
  + `limits_config.retention_period` in the values together.
- **One LB rule:** Always Free includes exactly one flexible LoadBalancer, already held by
  ingress-nginx. Grafana uses that same ingress — never add a `type: LoadBalancer` Service here.
- **arm64:** loki-stack images are multi-arch; they schedule on the Ampere node as-is.

## Uninstall

```bash
helm -n logging uninstall loki
kubectl -n logging delete pvc -l release=loki   # PVCs are NOT removed by helm uninstall
```
