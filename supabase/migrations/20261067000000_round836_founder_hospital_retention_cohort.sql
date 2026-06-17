BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_retention_cohort();
CREATE OR REPLACE FUNCTION public.founder_hospital_retention_cohort()
RETURNS TABLE (
  cohort_week_start date,
  cohort_size       bigint,
  active_last_30d   bigint,
  retention_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH cohorts AS (
    SELECT
      date_trunc('week', p.created_at)::date AS cohort_week,
      p.id AS user_id
    FROM public.profiles p
    WHERE p.role = 'hospital'
      AND p.created_at >= now() - interval '12 weeks'
  ),
  active AS (
    SELECT DISTINCT rj.hospital_user_id
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '30 days'
  )
  SELECT
    c.cohort_week,
    count(*)::bigint,
    count(*) FILTER (WHERE a.hospital_user_id IS NOT NULL)::bigint,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE a.hospital_user_id IS NOT NULL)::numeric
           / count(*)::numeric * 100.0, 1)
    END
  FROM cohorts c
  LEFT JOIN active a ON a.hospital_user_id = c.user_id
  GROUP BY c.cohort_week
  ORDER BY c.cohort_week DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_retention_cohort() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_retention_cohort() TO authenticated;
COMMIT;
