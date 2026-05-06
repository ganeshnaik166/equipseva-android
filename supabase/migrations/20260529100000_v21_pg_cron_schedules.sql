-- v2.1 PR-D19: pg_cron schedules for time-based housekeeping.
--
-- Several functions across PR #251–PR-D11 are designed to run on a
-- schedule but only PR-C3 (AMC cron helpers) actually wired pg_cron.
-- This migration adds the rest. All gated behind extension presence:
-- self-installs on Pro+ (where pg_cron is available), no-ops on Free
-- (RAISE NOTICE'd via the EXCEPTION clause). When the project moves
-- to Pro, the schedules activate without a re-deploy.
--
-- Until a tier upgrade, operator must call these functions manually
-- or via a Supabase scheduled edge function. Without that, the 48h
-- escrow auto-release (PR-D4) never fires — so an early manual run
-- is OK but not great.
--
-- Schedules picked for cheap-but-fresh:
--   * escrow auto-release        — hourly (matches the 48h window
--                                  granularity; wasted runs are cheap
--                                  because of FOR UPDATE SKIP LOCKED)
--   * expire stale cost revisions — every 15 minutes (revisions sit
--                                    in 'proposed' for ~24h max,
--                                    quick decay matters for UX)
--   * TTL purges                  — daily 03:00 UTC (off-peak in IST)

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- PR-D4 escrow auto-release. Only flips 'held' rows past
    -- scheduled_release_at (set by the on-completion trigger to
    -- completed_at + 48h) — so this is harmless to run at any
    -- frequency. Hourly keeps the engineer's payout window tight.
    PERFORM cron.unschedule('repair-job-escrow-auto-release');
    PERFORM cron.schedule(
      'repair-job-escrow-auto-release',
      '0 * * * *',
      $job$SELECT public.process_due_repair_job_escrow_releases();$job$
    );

    -- PR #251 cost-revision expiry. Revisions auto-expire after the
    -- per-job hour budget; without the cron, expired revisions
    -- linger as 'proposed' on the hospital banner.
    PERFORM cron.unschedule('expire-stale-cost-revisions');
    PERFORM cron.schedule(
      'expire-stale-cost-revisions',
      '*/15 * * * *',
      $job$SELECT public.expire_stale_cost_revisions();$job$
    );

    -- PR #252 TTL purges. Daily at 03:00 UTC = 08:30 IST = before
    -- working hours so any incidental table-lock churn doesn't hit
    -- live traffic. Each function caps deletions at a row budget so
    -- they're individually fast.
    PERFORM cron.unschedule('purge-old-notifications');
    PERFORM cron.schedule(
      'purge-old-notifications',
      '0 3 * * *',
      $job$SELECT public.purge_old_notifications();$job$
    );
    PERFORM cron.unschedule('purge-old-content-reports');
    PERFORM cron.schedule(
      'purge-old-content-reports',
      '5 3 * * *',
      $job$SELECT public.purge_old_content_reports();$job$
    );
    PERFORM cron.unschedule('purge-old-device-integrity-checks');
    PERFORM cron.schedule(
      'purge-old-device-integrity-checks',
      '10 3 * * *',
      $job$SELECT public.purge_old_device_integrity_checks();$job$
    );
    PERFORM cron.unschedule('purge-old-virtual-call-sessions');
    PERFORM cron.schedule(
      'purge-old-virtual-call-sessions',
      '15 3 * * *',
      $job$SELECT public.purge_old_virtual_call_sessions();$job$
    );

    RAISE NOTICE 'pg_cron schedules installed/refreshed';
  ELSE
    RAISE NOTICE 'pg_cron extension not present — schedules not installed (Free tier?). Operator must run helpers manually or via scheduled edge function.';
  END IF;
EXCEPTION
  WHEN insufficient_privilege OR undefined_function OR undefined_table THEN
    RAISE NOTICE 'pg_cron present but cron.schedule failed — operator wires schedule manually. SQLSTATE=%, message=%', SQLSTATE, SQLERRM;
END
$cron$;
