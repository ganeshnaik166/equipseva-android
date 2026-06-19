BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospitals_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_hospitals_snapshot_summary()
RETURNS TABLE (
  total_all_time         bigint,
  with_active_amc        bigint,
  without_amc            bigint,
  amc_coverage_pct       numeric,
  active_30d             bigint,
  active_7d              bigint,
  jobs_posted_30d        bigint,
  spend_30d_inr          numeric,
  avg_spend_per_active   numeric,
  loyalty_10_plus        bigint,
  never_posted_a_job     bigint,
  new_signups_30d        bigint,
  new_signups_today      bigint,
  posted_today           bigint,
  distinct_cities_30d    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total bigint;
  v_active_30d bigint;
  v_spend_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.profiles WHERE role = 'hospital';
  IF v_total IS NULL THEN v_total := 0; END IF;
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_active_30d
    FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  IF v_active_30d IS NULL THEN v_active_30d := 0; END IF;
  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_spend_30d
    FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  RETURN QUERY
  SELECT
    v_total,
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    v_total - coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(DISTINCT hospital_user_id)::numeric FROM public.amc_contracts WHERE status = 'active'), 0) / v_total, 1) END,
    v_active_30d,
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs WHERE created_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= now() - interval '30 days'), 0),
    v_spend_30d,
    CASE WHEN v_active_30d = 0 THEN 0::numeric
         ELSE round(v_spend_30d / v_active_30d, 2) END,
    coalesce((SELECT count(*)::bigint FROM (
              SELECT hospital_user_id FROM public.repair_jobs GROUP BY hospital_user_id HAVING count(*) >= 10
              ) t), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital'
              AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id)), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital' AND created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(DISTINCT lower(coalesce(p.city, '')))::bigint FROM public.profiles p
              WHERE p.role = 'hospital' AND coalesce(p.city, '') <> ''
              AND EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id AND j.created_at >= now() - interval '30 days')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospitals_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospitals_snapshot_summary() TO authenticated;
COMMIT;
