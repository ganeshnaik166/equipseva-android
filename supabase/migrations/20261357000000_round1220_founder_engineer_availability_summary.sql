BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_availability_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_availability_summary()
RETURNS TABLE (
  verified_engineers        bigint,
  reachable_1h              bigint,
  reachable_24h             bigint,
  reachable_7d              bigint,
  reachable_24h_pct         numeric,
  open_repair_jobs          bigint,
  open_code_reds            bigint,
  unassigned_code_reds      bigint,
  bids_last_1h              bigint,
  bids_last_24h             bigint,
  supply_to_open_demand     numeric,
  hot_supply_share_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_verified bigint;
  v_r24h     bigint;
  v_open_demand bigint;
  v_open_jobs bigint;
  v_open_reds bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_verified
    FROM public.engineers e
    WHERE coalesce(e.verification_status,'pending') = 'verified';

  SELECT count(DISTINCT b.engineer_user_id)::bigint INTO v_r24h
    FROM public.repair_job_bids b
    WHERE b.created_at >= now() - interval '24 hours';

  SELECT count(*)::bigint INTO v_open_jobs
    FROM public.repair_jobs WHERE status IN ('open','posted');

  SELECT count(*)::bigint INTO v_open_reds
    FROM public.code_red_requests WHERE status = 'open';

  v_open_demand := coalesce(v_open_jobs,0) + coalesce(v_open_reds,0);

  RETURN QUERY
  SELECT
    coalesce(v_verified, 0),
    coalesce((SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '1 hour'), 0),
    coalesce(v_r24h, 0),
    coalesce((SELECT count(DISTINCT b.engineer_user_id)::bigint FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '7 days'), 0),
    CASE WHEN coalesce(v_verified,0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_r24h / v_verified, 1) END,
    coalesce(v_open_jobs, 0),
    coalesce(v_open_reds, 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status = 'open' AND accepted_engineer_user_id IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '1 hour'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE created_at >= now() - interval '24 hours'), 0),
    CASE WHEN v_open_demand = 0 THEN 0::numeric
         ELSE round(v_r24h::numeric / v_open_demand::numeric, 2) END,
    CASE WHEN coalesce(v_verified,0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(DISTINCT b.engineer_user_id) FROM public.repair_job_bids b WHERE b.created_at >= now() - interval '1 hour'), 0) / v_verified, 1) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_availability_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_availability_summary() TO authenticated;
COMMIT;
