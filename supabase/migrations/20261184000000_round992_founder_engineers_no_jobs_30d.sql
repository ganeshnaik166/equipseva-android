BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineers_no_jobs_30d();
CREATE OR REPLACE FUNCTION public.founder_engineers_no_jobs_30d()
RETURNS TABLE (
  total_engineers          bigint,
  no_jobs_30d              bigint,
  no_jobs_30d_pct          numeric,
  no_jobs_60d              bigint,
  no_jobs_60d_pct          numeric,
  no_jobs_90d              bigint,
  no_jobs_90d_pct          numeric,
  never_had_a_job          bigint,
  never_had_a_job_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO tot FROM public.profiles WHERE role = 'engineer';
  IF tot IS NULL OR tot = 0 THEN
    tot := 0;
  END IF;

  RETURN QUERY
  WITH e AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'engineer'
  ),
  last_job AS (
    SELECT j.engineer_id, max(j.completed_at) AS last_completed_at
    FROM public.repair_jobs j
    WHERE j.engineer_id IS NOT NULL
      AND j.status = 'completed'
    GROUP BY j.engineer_id
  )
  SELECT
    tot                                                                   AS total_engineers,
    count(*) FILTER (
      WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '30 days'
    )::bigint                                                              AS no_jobs_30d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '30 days'
         ) / tot, 1) END                                                   AS no_jobs_30d_pct,
    count(*) FILTER (
      WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '60 days'
    )::bigint                                                              AS no_jobs_60d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '60 days'
         ) / tot, 1) END                                                   AS no_jobs_60d_pct,
    count(*) FILTER (
      WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '90 days'
    )::bigint                                                              AS no_jobs_90d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_completed_at IS NULL OR l.last_completed_at < now() - interval '90 days'
         ) / tot, 1) END                                                   AS no_jobs_90d_pct,
    count(*) FILTER (WHERE l.last_completed_at IS NULL)::bigint            AS never_had_a_job,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_completed_at IS NULL) / tot, 1)
    END                                                                    AS never_had_a_job_pct
  FROM e
  LEFT JOIN last_job l ON l.engineer_id = e.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_no_jobs_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_no_jobs_30d() TO authenticated;
COMMIT;
