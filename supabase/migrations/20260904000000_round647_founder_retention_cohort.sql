BEGIN;
DROP FUNCTION IF EXISTS public.founder_retention_cohort();
CREATE OR REPLACE FUNCTION public.founder_retention_cohort()
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
      date_trunc('week', e.created_at)::date AS cohort_week,
      e.user_id
    FROM public.engineers e
    WHERE e.created_at >= now() - interval '12 weeks'
  ),
  active AS (
    SELECT DISTINCT b.engineer_user_id
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.completed_at >= now() - interval '30 days'
      AND rj.status = 'completed'
  )
  SELECT
    c.cohort_week,
    count(*)::bigint                                                  AS cohort_size,
    count(*) FILTER (WHERE a.engineer_user_id IS NOT NULL)::bigint    AS active_last_30d,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE a.engineer_user_id IS NOT NULL)::numeric
           / count(*)::numeric * 100.0, 1)
    END                                                                AS retention_pct
  FROM cohorts c
  LEFT JOIN active a ON a.engineer_user_id = c.user_id
  GROUP BY c.cohort_week
  ORDER BY c.cohort_week DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_retention_cohort() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_retention_cohort() TO authenticated;
COMMIT;
