-- FamilyShare - targeted data reset (TRUNCATE).
-- Empties application data only for health/profile/media schemas in the shared Neon DB.
-- Keeps schema structure and flyway history, so no restart or re-migration is needed.
-- Idempotent: safe to re-run.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT format('%I.%I', schemaname, tablename) AS t
    FROM pg_tables
    WHERE schemaname IN ('health','profile','media')
      AND tablename <> 'flyway_schema_history'
  LOOP
    EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', r.t);
  END LOOP;
END $$;

-- Verify: every table below should read 0 rows (flyway history intentionally retained).
SELECT schemaname, relname AS table_name, n_live_tup AS approx_rows
FROM pg_stat_user_tables
WHERE schemaname IN ('health','profile','media')
ORDER BY schemaname, relname;