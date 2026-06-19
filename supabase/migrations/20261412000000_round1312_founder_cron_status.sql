BEGIN;
-- r1312 — Founder cron status summary. Pulls pg_cron.job_run_details to surface
-- last-run state of every cron job (DPDP routing, spot-audit auto-invite,
-- founder_auto_create_incidents, AMC reapers, etc.).
--
-- pg_cron is in the cron schema; SECURITY DEFINER lets the founder query it
-- without needing per-table grants on cron.*.

DROP FUNCTION IF EXISTS public.founder_cron_status_summary();
CREATE OR REPLACE FUNCTION public.founder_cron_status_summary()
RETURNS TABLE (
  total_jobs              bigint,
  active_jobs             bigint,
  inactive_jobs           bigint,
  recent_runs_24h         bigint,
  recent_failures_24h     bigint,
  recent_successes_24h    bigint,
  failure_rate_24h_pct    numeric,
  oldest_job_no_recent_run bigint,
  longest_running_job_seconds numeric,
  jobs_with_recent_failure_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_runs_24h bigint;
  v_fail_24h bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total FROM cron.job;
  IF v_total IS NULL THEN v_total := 0; END IF;
  SELECT count(*)::bigint INTO v_runs_24h FROM cron.job_run_details WHERE start_time >= now() - interval '24 hours';
  IF v_runs_24h IS NULL THEN v_runs_24h := 0; END IF;
  SELECT count(*)::bigint INTO v_fail_24h FROM cron.job_run_details
    WHERE start_time >= now() - interval '24 hours' AND status <> 'succeeded';
  IF v_fail_24h IS NULL THEN v_fail_24h := 0; END IF;

  RETURN QUERY
  SELECT
    v_total,
    coalesce((SELECT count(*)::bigint FROM cron.job WHERE active = true), 0),
    coalesce((SELECT count(*)::bigint FROM cron.job WHERE active = false), 0),
    v_runs_24h,
    v_fail_24h,
    v_runs_24h - v_fail_24h,
    CASE WHEN v_runs_24h = 0 THEN 0::numeric ELSE round(100.0 * v_fail_24h / v_runs_24h, 1) END,
    coalesce((SELECT count(*)::bigint FROM cron.job j
              WHERE j.active = true AND NOT EXISTS (
                SELECT 1 FROM cron.job_run_details rd
                WHERE rd.jobid = j.jobid AND rd.start_time >= now() - interval '24 hours'
              )), 0),
    coalesce((SELECT extract(epoch from max(end_time - start_time))::numeric FROM cron.job_run_details
              WHERE start_time >= now() - interval '24 hours' AND end_time IS NOT NULL), 0),
    coalesce((SELECT count(DISTINCT jobid)::bigint FROM cron.job_run_details
              WHERE start_time >= now() - interval '24 hours' AND status <> 'succeeded'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cron_status_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cron_status_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_cron_jobs_recent(int);
CREATE OR REPLACE FUNCTION public.founder_cron_jobs_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  jobid       bigint,
  jobname     text,
  schedule    text,
  active      boolean,
  last_run_at timestamptz,
  last_status text,
  last_duration_seconds numeric,
  recent_failure_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    j.jobid,
    coalesce(j.jobname, ('job_' || j.jobid::text))::text,
    j.schedule::text,
    j.active,
    (SELECT max(rd.start_time) FROM cron.job_run_details rd WHERE rd.jobid = j.jobid),
    (SELECT rd.status FROM cron.job_run_details rd
      WHERE rd.jobid = j.jobid ORDER BY rd.start_time DESC LIMIT 1)::text,
    (SELECT extract(epoch from (rd.end_time - rd.start_time))::numeric FROM cron.job_run_details rd
      WHERE rd.jobid = j.jobid AND rd.end_time IS NOT NULL ORDER BY rd.start_time DESC LIMIT 1),
    coalesce((SELECT count(*)::bigint FROM cron.job_run_details rd
              WHERE rd.jobid = j.jobid AND rd.start_time >= now() - interval '24 hours' AND rd.status <> 'succeeded'), 0)
  FROM cron.job j
  ORDER BY j.active DESC, j.jobid
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cron_jobs_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cron_jobs_recent(int) TO authenticated;
COMMIT;
