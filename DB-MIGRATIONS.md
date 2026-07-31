# Database migrations — deploy runbook

FamilyShare uses **schema-per-service** in one shared Postgres database. Each service owns its
own schema and its own [Flyway](https://flywaydb.org/) migration history; there is **no shared
migration set and no manual SQL step**.

## How it works (read this first)

- Every service runs `spring.jpa.hibernate.ddl-auto: validate` — Hibernate never creates or alters
  tables. **Flyway is the only thing that changes the schema.**
- On startup, Spring Boot runs Flyway **before** Hibernate validates the entities. Flyway applies any
  `V*.sql` files not yet recorded in that schema's `flyway_schema_history` table, then the app boots.
- Consequence: **a service will refuse to start if its schema is behind its entities** (validate
  fails). That's intentional — it prevents code/schema drift. The fix is always "deploy the image
  (which carries the migration)," never "hand-edit the DB."
- Migrations are per-schema and independent, so **deploy order does not matter** across services.

**To apply a migration: deploy the service image.** Nothing else.

## Full migration inventory

Each service migrates the schema named after it (`identity`, `family`, …). `flyway.schemas` /
`default-schema` are set per service in its `application.yml`.

| Service (schema) | Migrations (in order) |
|---|---|
| fs-identity (`identity`) | `V1__identity_core`, **`V2__user_profile`** |
| fs-family (`family`) | `V1__family_core`, `V2__invitations`, **`V3__member_dob_and_primary`**, **`V4__family_profile`** |
| fs-sharing (`sharing`) | `V1__sharing_core`, **`V2__default_audiences`** |
| fs-profile (`profile`) | `V1__posts`, `V2__fields`, **`V3__social`**, **`V4__post_tags_and_location`** |
| fs-media (`media`) | `V1__media` |
| fs-calendar (`calendar`) | `V1__med` |
| fs-escalation (`escalation`) | `V1__runs` |
| fs-notification (`notification`) | `V1__notifications` |
| fs-integration (`integration`) | `V1__integration` |

**Bold** = added in the core-requirements work; everything else was in the original build.

## What the new migrations do

| Migration | Change | Existing-data safety |
|---|---|---|
| fs-identity `V2__user_profile` | Adds `first_name, last_name, preferred_name, phone` to `identity.users` | **Expand-safe**: adds columns nullable → backfills existing rows → sets NOT NULL. ⚠️ existing users are backfilled with placeholders (`first_name` = email local-part, `last_name` = `"Member"`, `phone` = `+10000000000`) — they overwrite these by editing their profile. |
| fs-family `V3__member_dob_and_primary` | Adds `date_of_birth`, `guardian_member_id`, `is_primary` to `family.members`; partial unique index `members_one_primary … WHERE is_primary` | **Safe**: DOB/guardian nullable; `is_primary` NOT NULL DEFAULT false; backfills one existing admin per family as primary (`DISTINCT ON (family_id)`). |
| fs-family `V4__family_profile` | Adds `cover_url`, `description`, `icon` to `family.families` | **Safe**: all nullable. |
| fs-sharing `V2__default_audiences` | New table `sharing.default_audiences` (per-member, per-category default sharing audience) | **Safe**: new table. |
| fs-profile `V3__social` | New tables `profile.comments`, `profile.reactions` (`UNIQUE(post_id, author_member_id, emoji)`) | **Safe**: new tables. |
| fs-profile `V4__post_tags_and_location` | Adds `location`, `photo_url` to `profile.posts`; new table `profile.post_tags` | **Safe**: new/nullable. |

### Code-only changes (NO migration)
- **fs-media** — `GET /v1/files/{id}/view-url` (presigned inline URL) uses existing columns.
- **fs-calendar** — `GET /v1/med-schedules` (list schedules) uses the existing `calendar.med_schedules` table.
- **fs-family** — `GET /v1/me/families` uses the existing `family.members.user_id`.

## Deploying today's work

Redeploy these so their **migrations run**: **fs-identity, fs-family, fs-sharing, fs-profile**.
Also redeploy (changed, but **no migration**): **fs-calendar**, **fs-web**. All other services are
unchanged.

## Verifying / operating

```sql
-- What has actually been applied in a given schema:
SELECT installed_rank, version, description, success, installed_on
FROM family.flyway_schema_history ORDER BY installed_rank;   -- repeat per schema (identity, profile, …)
```

- **Backups first.** Take a snapshot / ensure PITR before deploying migrations to a populated DB.
- **Failed migration** ⇒ the service fails to start and Flyway records `success = false` for that
  version. Fix forward with a new `V*` (don't edit an already-applied file — the checksum won't match).
- **Expand/contract discipline** for zero-downtime: these migrations are all *expand* (add columns/
  tables, backfill, then constrain) — none drop or rename, so they are backward-compatible with the
  previously-running code.
- **No down-migrations.** Roll back by restoring the snapshot or shipping a compensating `V*`.

See also `PRODUCTION-READINESS.md` (bundle root) §1.1 and §5 for managed-Postgres and backup/restore
requirements.
