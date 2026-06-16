-- =====================================================================
-- Round 599 — Founder cron status RPC (ops visibility)
-- =====================================================================
--
-- We have ~10 scheduled jobs across the platform (daily ladder compute,
-- retention sweeps, AMC renewal reaper, supervised assignment reaper,
-- demand-signal cleanup, etc). Today there's NO single founder-facing
-- view of "which crons ran today and did they succeed?" — silent
-- breakage is invisible until a downstream surface reports stale data.
--
-- r599 ships a founder-only SECDEF RPC that joins cron.job + cron.
-- job_run_details (pg_cron's history) and returns the most recent run
-- per job. If pg_cron isn't enabled at all (some Supabase tiers), the
-- function returns an empty set — the Web Console page degrades to a
-- "pg_cron not enabled" notice.
--
-- The function deliberately doesn't expose job-level commands or
-- node-level details — only job_name + schedule + last_start +
-- last_status + last_runtime_ms — enough to spot drift without
-- leaking platform internals.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_cron_status();

CREATE OR REPLACE FUNCTION public.founder_cron_status()
RETURNS TABLE (
  job_name        text,
  schedule        text,
  active          boolean,
  last_start_time timestamptz,
  last_status     text,
  last_runtime_ms numeric,
  total_runs_24h  bigint,
  failed_runs_24h bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_has_cron boolean := false;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
    INTO v_has_cron;

  IF NOT v_has_cron THEN
    -- pg_cron not installed — return empty (UI shows the "not enabled"
    -- notice). Skip the cron.* references entirely to avoid 42P01.
    RETURN;
  END IF;

  -- Wrap in EXCEPTION so a malformed cron schema (e.g., during a
  -- pg_cron upgrade) doesn't kill the dashboard. Empty result is OK.
  BEGIN
    RETURN QUERY
    WITH latest AS (
      SELECT DISTINCT ON (jobid)
        jobid,
        start_time,
        status,
        end_time,
        return_message
      FROM cron.job_run_details
      ORDER BY jobid, start_time DESC
    ),
    counts AS (
      SELECT
        jobid,
        count(*)::bigint                              AS total_runs_24h,
        count(*) FILTER (WHERE status = 'failed')::bigint AS failed_runs_24h
      FROM cron.job_run_details
      WHERE start_time >= now() - interval '24 hours'
      GROUP BY jobid
    )
    SELECT
      j.jobname                                                 AS job_name,
      j.schedule                                                AS schedule,
      j.active                                                  AS active,
      l.start_time                                              AS last_start_time,
      l.status                                                  AS last_status,
      CASE
        WHEN l.end_time IS NOT NULL AND l.start_time IS NOT NULL
          THEN extract(epoch FROM (l.end_time - l.start_time)) * 1000.0
        ELSE NULL
      END                                                       AS last_runtime_ms,
      coalesce(c.total_runs_24h, 0)                             AS total_runs_24h,
      coalesce(c.failed_runs_24h, 0)                            AS failed_runs_24h
    FROM cron.job j
    LEFT JOIN latest l ON l.jobid = j.jobid
    LEFT JOIN counts c ON c.jobid = j.jobid
    ORDER BY
      coalesce(c.failed_runs_24h, 0) DESC,    -- broken jobs first
      l.start_time DESC NULLS LAST;
  EXCEPTION WHEN OTHERS THEN
    -- Don't blow up the cockpit if pg_cron schema shifts.
    RETURN;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cron_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cron_status() TO authenticated;

COMMENT ON FUNCTION public.founder_cron_status() IS
  'r599: founder-only ops view of pg_cron registered jobs + latest run + 24h failure count. Returns empty when pg_cron is not enabled.';

COMMIT;
