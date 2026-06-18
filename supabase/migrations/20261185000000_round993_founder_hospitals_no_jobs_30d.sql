BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospitals_no_jobs_30d();
CREATE OR REPLACE FUNCTION public.founder_hospitals_no_jobs_30d()
RETURNS TABLE (
  total_hospitals          bigint,
  no_jobs_30d              bigint,
  no_jobs_30d_pct          numeric,
  no_jobs_60d              bigint,
  no_jobs_60d_pct          numeric,
  no_jobs_90d              bigint,
  no_jobs_90d_pct          numeric,
  never_posted_a_job       bigint,
  never_posted_a_job_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO tot FROM public.profiles WHERE role = 'hospital';
  IF tot IS NULL THEN tot := 0; END IF;

  RETURN QUERY
  WITH h AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'hospital'
  ),
  last_post AS (
    SELECT j.hospital_user_id, max(j.created_at) AS last_posted_at
    FROM public.repair_jobs j
    WHERE j.hospital_user_id IS NOT NULL
    GROUP BY j.hospital_user_id
  )
  SELECT
    tot                                                                   AS total_hospitals,
    count(*) FILTER (
      WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '30 days'
    )::bigint                                                              AS no_jobs_30d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '30 days'
         ) / tot, 1) END                                                   AS no_jobs_30d_pct,
    count(*) FILTER (
      WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '60 days'
    )::bigint                                                              AS no_jobs_60d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '60 days'
         ) / tot, 1) END                                                   AS no_jobs_60d_pct,
    count(*) FILTER (
      WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '90 days'
    )::bigint                                                              AS no_jobs_90d,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (
            WHERE l.last_posted_at IS NULL OR l.last_posted_at < now() - interval '90 days'
         ) / tot, 1) END                                                   AS no_jobs_90d_pct,
    count(*) FILTER (WHERE l.last_posted_at IS NULL)::bigint               AS never_posted_a_job,
    CASE WHEN tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE l.last_posted_at IS NULL) / tot, 1)
    END                                                                    AS never_posted_a_job_pct
  FROM h
  LEFT JOIN last_post l ON l.hospital_user_id = h.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospitals_no_jobs_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospitals_no_jobs_30d() TO authenticated;
COMMIT;
