BEGIN;
DROP FUNCTION IF EXISTS public.founder_onboarding_velocity_summary();
CREATE OR REPLACE FUNCTION public.founder_onboarding_velocity_summary()
RETURNS TABLE (
  eng_cohort_90d                    bigint,
  eng_median_signup_to_verified_h   numeric,
  eng_p90_signup_to_verified_h      numeric,
  eng_median_signup_to_first_bid_h  numeric,
  eng_p90_signup_to_first_bid_h     numeric,
  eng_stalled_no_bid_over_7d        bigint,
  hosp_cohort_90d                   bigint,
  hosp_median_signup_to_first_job_h numeric,
  hosp_p90_signup_to_first_job_h    numeric,
  hosp_median_signup_to_first_amc_d numeric,
  hosp_stalled_no_job_over_7d       bigint,
  avg_signups_per_day_30d           numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH eng_cohort AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'engineer'
      AND p.created_at >= now() - interval '90 days'
  ),
  eng_verified AS (
    SELECT extract(epoch FROM (e.verified_at - ec.created_at)) / 3600.0 AS hours_to_verified
    FROM eng_cohort ec
    JOIN public.engineers e ON e.user_id = ec.id
    WHERE e.verified_at IS NOT NULL
      AND e.verified_at >= ec.created_at
  ),
  eng_first_bid AS (
    SELECT extract(epoch FROM (min(b.created_at) - ec.created_at)) / 3600.0 AS hours_to_first_bid
    FROM eng_cohort ec
    JOIN public.repair_job_bids b ON b.engineer_user_id = ec.id
    WHERE b.created_at >= ec.created_at
    GROUP BY ec.id, ec.created_at
  ),
  eng_stalled AS (
    SELECT count(*)::bigint AS n
    FROM eng_cohort ec
    WHERE ec.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.engineer_user_id = ec.id)
  ),
  hosp_cohort AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'hospital'
      AND p.created_at >= now() - interval '90 days'
  ),
  hosp_first_job AS (
    SELECT extract(epoch FROM (min(j.created_at) - hc.created_at)) / 3600.0 AS hours_to_first_job
    FROM hosp_cohort hc
    JOIN public.repair_jobs j ON j.hospital_user_id = hc.id
    WHERE j.created_at >= hc.created_at
    GROUP BY hc.id, hc.created_at
  ),
  hosp_first_amc AS (
    SELECT extract(epoch FROM (min(c.created_at) - hc.created_at)) / 86400.0 AS days_to_first_amc
    FROM hosp_cohort hc
    JOIN public.amc_contracts c ON c.hospital_user_id = hc.id
    WHERE c.created_at >= hc.created_at
      AND c.status IN ('active','paused','expired')
    GROUP BY hc.id, hc.created_at
  ),
  hosp_stalled AS (
    SELECT count(*)::bigint AS n
    FROM hosp_cohort hc
    WHERE hc.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = hc.id)
  ),
  signups_30d AS (
    SELECT count(*)::numeric / 30.0 AS avg_per_day
    FROM public.profiles p
    WHERE p.role IN ('engineer','hospital')
      AND p.created_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*)::bigint FROM eng_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT n FROM eng_stalled),
    (SELECT count(*)::bigint FROM hosp_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_first_amc))::numeric, 1), 0)::numeric FROM hosp_first_amc),
    (SELECT n FROM hosp_stalled),
    (SELECT round(avg_per_day, 1)::numeric FROM signups_30d);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_onboarding_velocity_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_onboarding_velocity_summary() TO authenticated;
COMMIT;