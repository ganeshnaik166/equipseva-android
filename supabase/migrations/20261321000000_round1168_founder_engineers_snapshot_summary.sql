BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineers_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_engineers_snapshot_summary()
RETURNS TABLE (
  total_all_time         bigint,
  verified_cnt           bigint,
  pending_kyc_cnt        bigint,
  pending_kyc_over_7d    bigint,
  tier_gold              bigint,
  tier_silver            bigint,
  tier_bronze            bigint,
  tier_none              bigint,
  active_30d             bigint,
  active_7d              bigint,
  paid_30d               bigint,
  new_signups_30d        bigint,
  new_signups_today      bigint,
  avg_jobs_per_active_30d numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_active_30d  bigint;
  v_jobs_30d    bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(DISTINCT engineer_id)::bigint INTO v_active_30d
    FROM public.repair_jobs
    WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days';
  IF v_active_30d IS NULL THEN v_active_30d := 0; END IF;
  SELECT count(*)::bigint INTO v_jobs_30d
    FROM public.repair_jobs
    WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days';
  IF v_jobs_30d IS NULL THEN v_jobs_30d := 0; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineers), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE verification_status = 'verified'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(verification_status, 'pending') = 'pending'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(verification_status, 'pending') = 'pending' AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'gold'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'silver'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'bronze'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'none'), 0),
    v_active_30d,
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_user_id)::bigint FROM public.engineer_payouts
              WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    CASE WHEN v_active_30d = 0 THEN 0::numeric
         ELSE round(v_jobs_30d::numeric / v_active_30d, 2) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_snapshot_summary() TO authenticated;
COMMIT;
