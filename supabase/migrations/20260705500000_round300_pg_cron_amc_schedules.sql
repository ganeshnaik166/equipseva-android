-- Round 300 — extend pg_cron schedules to include AMC cron helpers.
--
-- 20260529100000_v21_pg_cron_schedules wired escrow auto-release,
-- cost-revision expiry, and 4 purge functions. It did NOT wire the
-- AMC cron helpers from 20260511100000:
--   • auto_create_due_amc_visits
--   • auto_renew_expiring_amc_contracts
--
-- Round 296 (PR #749) wired both into the Free-tier cron-tick edge
-- function. When the project upgrades to Supabase Pro and pg_cron
-- activates the 20260529100000 schedules, the AMC helpers would
-- still be missing from pg_cron — only the edge-fn path would run
-- them. Acceptable but inconsistent: every other recurring job has
-- both Free-tier (edge fn) and Pro-tier (pg_cron) wiring.
--
-- Add the missing pair so the two cron paths stay synchronized.
-- Same gating pattern as 20260529100000 — gated behind extension
-- presence so Free-tier deploys still no-op cleanly.
--
-- Schedules:
--   * amc-create-due-visits — hourly so a maintenance visit lands
--                              within the hour of next_visit_at.
--   * amc-auto-renew        — daily at 03:20 UTC (after the TTL
--                              purges; same off-peak window).

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('amc-create-due-visits');
    PERFORM cron.schedule(
      'amc-create-due-visits',
      '0 * * * *',
      $job$SELECT public.auto_create_due_amc_visits();$job$
    );

    PERFORM cron.unschedule('amc-auto-renew-expiring');
    PERFORM cron.schedule(
      'amc-auto-renew-expiring',
      '20 3 * * *',
      $job$SELECT public.auto_renew_expiring_amc_contracts();$job$
    );

    RAISE NOTICE 'pg_cron AMC schedules installed/refreshed';
  ELSE
    RAISE NOTICE 'pg_cron extension not present — AMC schedules not installed (Free tier; cron-tick edge fn covers).';
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR undefined_function OR undefined_table THEN
    RAISE NOTICE 'pg_cron present but cron.schedule failed for AMC. SQLSTATE=%, message=%', SQLSTATE, SQLERRM;
END
$cron$;
