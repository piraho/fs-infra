# fs-infra — local development & deployment ledger

## Run everything
```bash
make dev      # postgres + identity (8081) + family (8082) + web (3000)
make e2e      # API smoke + Playwright golden journey
make down
```
Java services build inside Docker (Gradle multi-stage) — no local JDK needed.
Production posture (Terraform/EKS/Argo CD) follows docs/13 + docs/18 of the product package;
this repo is also where every service's deploy manifests will live (values-bump PR model).
