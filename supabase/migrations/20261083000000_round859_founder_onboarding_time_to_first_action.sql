BEGIN;
DROP FUNCTION IF EXISTS public.founder_onboarding_time_to_first_action();
CREATE OR REPLACE FUNCTION public.founder_onboarding_time_to_first_action()
RETURNS TABLE (
  role            text,
  cohort_size     bigint,
  median_minutes  numeric,
  p90_minutes     numeric,
  within_24h      bigint,
  within_7d       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH cohort AS (
    SELECT p.id, p.role::text, p.created_at
    FROM public.profiles p
    WHERE p.role IN ('engineer','hospital')
      AND p.created_at >= now() - interval '90 days'
  ),
  first_action AS (
    SELECT
      c.id, c.role, c.created_at,
      CASE c.role
        WHEN 'engineer' THEN (
          SELECT min(b.created_at) FROM public.repair_job_bids b WHERE b.engineer_user_id = c.id
        )
        WHEN 'hospital' THEN (
          SELECT min(rj.created_at) FROM public.repair_jobs rj WHERE rj.hospital_user_id = c.id
        )
      END AS first_at
    FROM cohort c
  ),
  with_delta AS (
    SELECT role, created_at, first_at,
           extract(epoch FROM (first_at - created_at)) / 60.0 AS delta_min
    FROM first_action
    WHERE first_at IS NOT NULL
  )
  SELECT
    wd.role,
    count(*)::bigint,
    coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY wd.delta_min))::numeric, 1), 0)::numeric,
    coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY wd.delta_min))::numeric, 1), 0)::numeric,
    count(*) FILTER (WHERE wd.delta_min <= 1440)::bigint,
    count(*) FILTER (WHERE wd.delta_min <= 10080)::bigint
  FROM with_delta wd
  GROUP BY wd.role
  ORDER BY wd.role;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_onboarding_time_to_first_action() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_onboarding_time_to_first_action() TO authenticated;
COMMIT;
