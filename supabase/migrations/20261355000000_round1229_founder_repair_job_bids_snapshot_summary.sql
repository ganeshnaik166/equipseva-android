BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_job_bids_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_repair_job_bids_snapshot_summary()
RETURNS TABLE (
  total_all_time          bigint,
  pending_now             bigint,
  accepted_30d            bigint,
  rejected_30d            bigint,
  withdrawn_30d           bigint,
  acceptance_pct_30d      numeric,
  active_engineers_30d    bigint,
  avg_amount_30d_inr      numeric,
  max_amount_30d_inr      numeric,
  created_today           bigint,
  accepted_today          bigint,
  avg_bids_per_open_job   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_settled_30d bigint;
  v_accepted_30d bigint;
  v_open_jobs bigint;
  v_pending_bids bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_accepted_30d FROM public.repair_job_bids WHERE status = 'accepted' AND created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_settled_30d FROM public.repair_job_bids WHERE status IN ('accepted','rejected','withdrawn') AND created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_open_jobs FROM public.repair_jobs WHERE status IN ('open','posted');
  SELECT count(*)::bigint INTO v_pending_bids FROM public.repair_job_bids WHERE status IN ('pending','submitted');
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids), 0),
    v_pending_bids,
    v_accepted_30d,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'rejected' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'withdrawn' AND created_at >= now() - interval '30 days'), 0),
    CASE WHEN coalesce(v_settled_30d, 0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_accepted_30d / v_settled_30d, 1) END,
    coalesce((SELECT count(DISTINCT engineer_user_id)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(amount_rupees)::numeric, 2) FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT max(amount_rupees)::numeric FROM public.repair_job_bids WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status = 'accepted' AND created_at >= v_today_start AND created_at < v_today_end), 0),
    CASE WHEN coalesce(v_open_jobs, 0) = 0 THEN 0::numeric
         ELSE round(v_pending_bids::numeric / v_open_jobs, 2) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_job_bids_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_job_bids_snapshot_summary() TO authenticated;
COMMIT;
