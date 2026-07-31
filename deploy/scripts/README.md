# Operational scripts

## Data reset — start fresh

Wipes **all application data** from the single Neon Postgres database (`neondb`) shared by every
FamilyShare service, while keeping schemas + Flyway history so **no restart or re-migration** is
needed. All 9 service schemas are truncated: `identity, family, sharing, profile, media, calendar,
escalation, notification, integration`.

> ⚠️ **Destructive and irreversible.** Snapshot first — on Neon the fastest is *Create branch* in
> the dashboard (instant). Or a portable dump:
> ```bash
> pg_dump "host=<neon-host> dbname=neondb user=neondb_owner sslmode=require" -Fc -f pre-reset.dump
> ```

### Option A — run the SQL directly (local psql)

```bash
PGPASSWORD='<pw>' psql \
  "host=<neon-pooler-host> dbname=neondb user=neondb_owner sslmode=require" \
  -v ON_ERROR_STOP=1 -f reset-data.sql
```

Credentials come from the Neon dashboard, or from the cluster secret:

```bash
kubectl -n familyshare get secret fs-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

### Option B — run it in-cluster as a Job (no local psql; uses the `fs-db` secret)

```bash
kubectl -n familyshare create configmap fs-reset-data-sql --from-file=reset-data.sql=./reset-data.sql
kubectl -n familyshare apply -f reset-data.job.yaml
kubectl -n familyshare logs -f job/fs-reset-data                              # watch it run
kubectl -n familyshare delete job/fs-reset-data configmap/fs-reset-data-sql   # cleanup
```

The Job reads DB credentials from the existing `fs-db` Secret — no credentials are stored in these
files.

### After a reset

- The app is immediately empty; **no pod restart required**.
- The first sign-up starts fresh; creating a family regenerates its default sharing groups.
- Uploaded image blobs in object storage are **not** removed (only their DB rows). Clear the media
  bucket separately if you want those gone too.
- `reset-data.sql` prints a per-table row count at the end — every app table should read `0`.
