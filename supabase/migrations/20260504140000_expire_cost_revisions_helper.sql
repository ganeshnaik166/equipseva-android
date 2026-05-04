-- Standalone helper that tombstones cost-revision proposals older than
-- 24h. Designed to be invoked from either pg_cron (if the extension is
-- enabled on this Supabase project) OR a scheduled Supabase Edge
-- Function — we do NOT call cron.schedule directly here because the
-- repo has no prior pg_cron usage to confirm the extension is loaded,
-- and a missing extension would fail the whole migration.
--
-- After this migration applies, pick ONE wiring:
--   (a) pg_cron (preferred, lower ops):
--       SELECT cron.schedule(
--         'expire-stale-cost-revisions',
--         '*/15 * * * *',
--         'SELECT public.expire_stale_cost_revisions();'
--       );
--   (b) Supabase Edge Function: create
--       supabase/functions/expire-cost-revisions/index.ts that calls
--       this RPC every 15 min via the platform scheduler.
--
-- Idempotent: re-runs are no-ops once a row is already 'expired'.

CREATE OR REPLACE FUNCTION public.expire_stale_cost_revisions()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH expired AS (
    UPDATE public.repair_job_cost_revisions
       SET status = 'expired',
           decided_at = now()
     WHERE status = 'proposed'
       AND created_at < now() - interval '24 hours'
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM expired;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.expire_stale_cost_revisions() OWNER TO postgres;

REVOKE ALL ON FUNCTION public.expire_stale_cost_revisions() FROM PUBLIC, anon, authenticated;
-- Keep service-role + postgres callers only — this is an ops job, not
-- something we want triggered by client code.
