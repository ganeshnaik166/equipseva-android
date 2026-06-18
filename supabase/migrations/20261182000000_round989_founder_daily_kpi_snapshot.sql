BEGIN;
DROP FUNCTION IF EXISTS public.founder_daily_kpi_snapshot();
CREATE OR REPLACE FUNCTION public.founder_daily_kpi_snapshot()
RETURNS TABLE (
  day_ist       date,
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
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 89,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE (rj.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids b
              WHERE (b.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
              WHERE p.status='processed'
                AND (p.queued_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs d2
              WHERE d2.submitted_at IS NOT NULL
                AND (d2.submitted_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_daily_kpi_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_daily_kpi_snapshot() TO authenticated;
COMMIT;
