BEGIN;
DROP FUNCTION IF EXISTS public.founder_weekly_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.founder_weekly_kpi_snapshot()
RETURNS TABLE (
  week_start    date,
  signups       bigint,
  jobs_posted   bigint,
  jobs_done     bigint,
  bids          bigint,
  payouts_done  bigint,
  new_amcs      bigint,
  disputes      bigint,
  code_red      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE date_trunc('week', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('week', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE date_trunc('week', (b.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status='processed'
                AND date_trunc('week', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE date_trunc('week', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL
                AND date_trunc('week', (d.submitted_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE date_trunc('week', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_weekly_kpi_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_weekly_kpi_snapshot() TO authenticated;
COMMIT;
