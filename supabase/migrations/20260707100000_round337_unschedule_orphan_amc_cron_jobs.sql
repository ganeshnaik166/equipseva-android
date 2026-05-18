-- Round 337 — unschedule orphan AMC pg_cron jobs left over from v2.1.
--
-- 20260511100000_v21_amc_cron_helpers.sql installed two jobs:
--   • amc-auto-create-visits  (09:00 UTC daily)
--   • amc-auto-renew          (06:00 UTC daily)
--
-- 20260705500000_round300_pg_cron_amc_schedules.sql later RE-SCHEDULED
-- the same two SQL functions under DIFFERENT job names:
--   • amc-create-due-visits     (hourly)
--   • amc-auto-renew-expiring   (daily 03:20 UTC)
--
-- pg_cron does NOT auto-unschedule the old names when a new schedule
-- with a different name is created. On Pro-tier projects that ran both
-- migrations, the database is now firing the same two SQL functions
-- TWICE per day on different schedules:
--   - auto_create_due_amc_visits()       — once at 09:00 (legacy)
--                                          + 24 times hourly (current)
--   - auto_renew_expiring_amc_contracts() — once at 06:00 (legacy)
--                                          + once at 03:20 (current)
--
-- Both functions are idempotent (FOR UPDATE SKIP LOCKED + dedup) so
-- duplicate runs don't cause data corruption, but they waste compute
-- and pollute cron job history. Drop the orphan schedules.

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Best-effort unschedule. cron.unschedule raises if the job name
    -- doesn't exist; swallow that case so a fresh deploy that never
    -- ran the v2.1 migration still applies cleanly.
    BEGIN
      PERFORM cron.unschedule('amc-auto-create-visits');
      RAISE NOTICE 'unscheduled legacy job amc-auto-create-visits';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'amc-auto-create-visits not present, skipping';
    END;

    BEGIN
      PERFORM cron.unschedule('amc-auto-renew');
      RAISE NOTICE 'unscheduled legacy job amc-auto-renew';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'amc-auto-renew not present, skipping';
    END;
  ELSE
    RAISE NOTICE 'pg_cron not present — nothing to unschedule';
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR undefined_function OR undefined_table THEN
    RAISE NOTICE 'pg_cron present but unschedule failed. SQLSTATE=%, message=%',
                 SQLSTATE, SQLERRM;
END
$cron$;
