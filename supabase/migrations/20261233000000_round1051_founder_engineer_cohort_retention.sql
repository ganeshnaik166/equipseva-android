BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_cohort_retention();
CREATE OR REPLACE FUNCTION public.founder_engineer_cohort_retention()
RETURNS TABLE (
  signup_month         date,
  cohort_size          bigint,
  active_30d_pct       numeric,
  active_60d_pct       numeric,
  active_90d_pct       numeric,
  active_180d_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS signup_month
  ),
  cohorts AS (
    SELECT
      m.signup_month,
      e.id                                       AS engineer_id,
      e.user_id,
      m.signup_month::timestamptz                AS cohort_start
    FROM months m
    JOIN public.engineers e
      ON date_trunc('month', e.created_at AT TIME ZONE 'Asia/Kolkata')::date = m.signup_month
  )
  SELECT
    c.signup_month,
    count(*)::bigint                                                          AS cohort_size,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           100.0 * count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_jobs j
               WHERE j.engineer_id = c.engineer_id
                 AND j.status = 'completed'
                 AND j.completed_at BETWEEN c.cohort_start AND c.cohort_start + interval '30 days'
             )
           )::numeric / count(*), 1) END                                       AS active_30d_pct,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           100.0 * count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_jobs j
               WHERE j.engineer_id = c.engineer_id
                 AND j.status = 'completed'
                 AND j.completed_at BETWEEN c.cohort_start AND c.cohort_start + interval '60 days'
             )
           )::numeric / count(*), 1) END                                       AS active_60d_pct,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           100.0 * count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_jobs j
               WHERE j.engineer_id = c.engineer_id
                 AND j.status = 'completed'
                 AND j.completed_at BETWEEN c.cohort_start AND c.cohort_start + interval '90 days'
             )
           )::numeric / count(*), 1) END                                       AS active_90d_pct,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(
           100.0 * count(*) FILTER (
             WHERE EXISTS (
               SELECT 1 FROM public.repair_jobs j
               WHERE j.engineer_id = c.engineer_id
                 AND j.status = 'completed'
                 AND j.completed_at BETWEEN c.cohort_start AND c.cohort_start + interval '180 days'
             )
           )::numeric / count(*), 1) END                                       AS active_180d_pct
  FROM cohorts c
  GROUP BY c.signup_month
  ORDER BY c.signup_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_cohort_retention() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_cohort_retention() TO authenticated;
COMMIT;
