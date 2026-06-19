BEGIN;

DROP FUNCTION IF EXISTS public.founder_signups_funnel_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_signups_funnel_snapshot_summary()
RETURNS TABLE (
  total_all_time              bigint,
  signups_today               bigint,
  signups_7d                  bigint,
  signups_30d                 bigint,
  engineer_signups_30d        bigint,
  hospital_signups_30d        bigint,
  engineers_with_bid_in_7d_30d bigint,
  hospitals_with_job_in_7d_30d bigint,
  engineer_first_action_pct   numeric,
  hospital_first_action_pct   numeric,
  signups_with_city_30d       bigint,
  stuck_no_action_over_14d    bigint,
  distinct_cities_30d         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_eng_30d     bigint;
  v_hos_30d     bigint;
  v_eng_act     bigint;
  v_hos_act     bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_eng_30d
    FROM public.profiles p
    WHERE p.role = 'engineer' AND p.created_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_hos_30d
    FROM public.profiles p
    WHERE p.role = 'hospital' AND p.created_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_eng_act
    FROM public.profiles p
    WHERE p.role = 'engineer'
      AND p.created_at >= now() - interval '30 days'
      AND EXISTS (SELECT 1 FROM public.repair_job_bids b
                  WHERE b.engineer_user_id = p.id
                    AND b.created_at BETWEEN p.created_at AND p.created_at + interval '7 days');

  SELECT count(*)::bigint INTO v_hos_act
    FROM public.profiles p
    WHERE p.role = 'hospital'
      AND p.created_at >= now() - interval '30 days'
      AND EXISTS (SELECT 1 FROM public.repair_jobs j
                  WHERE j.hospital_user_id = p.id
                    AND j.created_at BETWEEN p.created_at AND p.created_at + interval '7 days');

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.profiles), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE created_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE created_at >= now() - interval '30 days'), 0),
    v_eng_30d,
    v_hos_30d,
    v_eng_act,
    v_hos_act,
    CASE WHEN v_eng_30d > 0
         THEN round((v_eng_act::numeric * 100.0) / v_eng_30d::numeric, 1)
         ELSE 0::numeric END,
    CASE WHEN v_hos_30d > 0
         THEN round((v_hos_act::numeric * 100.0) / v_hos_30d::numeric, 1)
         ELSE 0::numeric END,
    coalesce((SELECT count(*)::bigint FROM public.profiles
              WHERE created_at >= now() - interval '30 days'
                AND coalesce(trim(city), '') <> ''), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role IN ('engineer','hospital')
                AND p.created_at < now() - interval '14 days'
                AND p.created_at >= now() - interval '60 days'
                AND NOT EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.engineer_user_id = p.id)
                AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id)), 0),
    coalesce((SELECT count(DISTINCT nullif(trim(city), ''))::bigint FROM public.profiles
              WHERE created_at >= now() - interval '30 days'
                AND coalesce(trim(city), '') <> ''), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_signups_funnel_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_funnel_snapshot_summary() TO authenticated;

COMMIT;
