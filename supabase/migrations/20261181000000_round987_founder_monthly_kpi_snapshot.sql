BEGIN;
DROP FUNCTION IF EXISTS public.founder_monthly_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.founder_monthly_kpi_snapshot()
RETURNS TABLE (
  month_ist     date,
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
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE date_trunc('month', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE date_trunc('month', (b.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status='processed'
                AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d
              WHERE d.submitted_at IS NOT NULL
                AND date_trunc('month', (d.submitted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_monthly_kpi_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_monthly_kpi_snapshot() TO authenticated;
COMMIT;
