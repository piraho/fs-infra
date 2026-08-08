-- FamilyShare — full data reset (TRUNCATE).
-- Empties every application table across all 10 service schemas in the single Neon DB (neondb).
-- Keeps each schema's structure AND flyway_schema_history, so services do NOT re-migrate and
-- do NOT need a restart — they simply serve an empty app on the next request.
-- Safe: no Flyway migration seeds reference data (all migrations are pure DDL), so nothing but
-- user/app data is removed. Idempotent — re-running is harmless.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT format('%I.%I', schemaname, tablename) AS t
    FROM pg_tables
    WHERE schemaname IN
      ('identity','family','sharing','profile','media',
       'calendar','escalation','notification','integration','health')
      AND tablename <> 'flyway_schema_history'
  LOOP
    EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', r.t);
  END LOOP;
END $$;

-- Verify: every app table should read 0 (flyway_schema_history is intentionally retained).
SELECT schemaname, relname AS table_name, n_live_tup AS approx_rows
FROM pg_stat_user_tables
WHERE schemaname IN
  ('identity','family','sharing','profile','media',
  'calendar','escalation','notification','integration','health')
ORDER BY schemaname, relname;
