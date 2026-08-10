# Operational scripts

## Data reset — start fresh

Wipes **all application data** from the single Neon Postgres database (`neondb`) shared by every
FamilyShare service, while keeping schemas + Flyway history so **no restart or re-migration** is
needed. All 10 service schemas are truncated: `identity, family, sharing, profile, media, calendar,
escalation, notification, integration, health`.

> ⚠️ **Destructive and irreversible.** Snapshot first — on Neon the fastest is _Create branch_ in
> the dashboard (instant). Or a portable dump:
>
> ```bash
> pg_dump "host=<neon-host> dbname=neondb user=neondb_owner sslmode=require" -Fc -f pre-reset.dump
> ```

### Option A — run the SQL directly (local psql)

```bash
PGPASSWORD='<pw>' psql \
  "host=<neon-pooler-host> dbname=neondb user=neondb_owner sslmode=require" \
  -v ON_ERROR_STOP=1 -f reset-data.sql
```

Credentials come from the Neon dashboard, or from the cluster secret. No local `psql`? Use your
local Docker (it can pull Docker Hub images even though the arm64 OKE nodes can't):

```bash
NS=familyshare
URL=$(kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_URL}'      | base64 -d)
USR=$(kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_USER}'     | base64 -d)
PW=$( kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d)
HOST=$(printf '%s' "$URL" | sed -E 's#jdbc:postgresql://([^/]+)/.*#\1#')
docker run --rm -e PGPASSWORD="$PW" -v "$PWD/reset-data.sql:/reset-data.sql:ro" \
  postgres:16-alpine \
  psql "host=$HOST dbname=neondb user=$USR sslmode=require" -v ON_ERROR_STOP=1 -f /reset-data.sql
```

### Option B — run it in-cluster as a Job (no local psql; uses the `fs-db` secret)

**One-time prerequisite:** the OKE nodes are arm64 and pull anonymously from `ghcr.io/piraho`, so the
psql image must be mirrored there and made public — a Docker Hub image gives `ImageInspectError` on
the node. Run the mirror workflow once:

1. GitHub → **fs-infra → Actions → "mirror-psql" → Run workflow** (defaults mirror `postgres:16-alpine`
   → `ghcr.io/piraho/fs-psql:16`, arm64 included).
2. Make the new package **public**: piraho packages → `fs-psql` → _Package settings → Change
   visibility → Public_ (the cluster pulls with no imagePullSecret).

Then run the Job:

```bash
kubectl -n familyshare create configmap fs-reset-data-sql --from-file=reset-data.sql=./reset-data.sql
kubectl -n familyshare apply -f reset-data.job.yaml
kubectl -n familyshare logs -f job/fs-reset-data                              # watch it run
kubectl -n familyshare delete job/fs-reset-data configmap/fs-reset-data-sql   # cleanup
```

The Job reads DB credentials from the existing `fs-db` Secret and pulls `ghcr.io/piraho/fs-psql:16`
— no credentials are stored in these files.

### After a reset

- The app is immediately empty; **no pod restart required**.
- The first sign-up starts fresh; creating a family regenerates its default sharing groups.
- Uploaded blobs in object storage are **not** removed (only their DB rows).
  - Clear the media bucket separately if you want media file bytes gone.
  - Clear the clinical bucket (for `fs-health` documents) separately if you want health document bytes gone.
- `reset-data.sql` prints a per-table row count at the end — every app table should read `0`.

## Targeted reset - health/profile/media only

Wipes only these schemas in Neon: `health, profile, media`.
Use this when you want to clear profile fields/posts/lists, health records/documents, and media metadata
without resetting identity/family/calendar/etc.

> Warning: destructive for the targeted schemas. Snapshot first.

### Option A - run the SQL directly (local psql)

```bash
PGPASSWORD='<pw>' psql \
  "host=<neon-pooler-host> dbname=neondb user=neondb_owner sslmode=require" \
  -v ON_ERROR_STOP=1 -f reset-health-profile-media.sql
```

Or with credentials from `fs-db` and local Docker psql:

```bash
NS=familyshare
URL=$(kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_URL}'      | base64 -d)
USR=$(kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_USER}'     | base64 -d)
PW=$( kubectl -n $NS get secret fs-db -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d)
HOST=$(printf '%s' "$URL" | sed -E 's#jdbc:postgresql://([^/]+)/.*#\1#')
docker run --rm -e PGPASSWORD="$PW" -v "$PWD/reset-health-profile-media.sql:/reset-health-profile-media.sql:ro" \
  postgres:16-alpine \
  psql "host=$HOST dbname=neondb user=$USR sslmode=require" -v ON_ERROR_STOP=1 -f /reset-health-profile-media.sql
```

### Option B - run in-cluster as a Job

```bash
kubectl -n familyshare create configmap fs-reset-health-profile-media-sql \
  --from-file=reset-health-profile-media.sql=./reset-health-profile-media.sql
kubectl -n familyshare apply -f reset-health-profile-media.job.yaml
kubectl -n familyshare logs -f job/fs-reset-health-profile-media
kubectl -n familyshare delete job/fs-reset-health-profile-media configmap/fs-reset-health-profile-media-sql
```

### After targeted reset

- APIs on those schemas are immediately empty; pod restart is not required.
- Object storage bytes are not deleted by DB truncate:
  - clear the clinical bucket (health documents) if you need those bytes gone,
  - clear the media bucket if you need media blobs gone.
