BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_leaderboard_30d();
CREATE OR REPLACE FUNCTION public.founder_hospital_leaderboard_30d()
RETURNS TABLE (
  hospital_name      text,
  jobs_posted        bigint,
  jobs_completed     bigint,
  total_spend_inr    numeric,
  amc_count          bigint,
  last_active_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH posted AS (
    SELECT j.hospital_user_id,
           count(*)::bigint                              AS jobs_posted,
           count(*) FILTER (WHERE j.status = 'completed')::bigint AS jobs_completed,
           coalesce(sum(j.hospital_amount) FILTER (WHERE j.status = 'completed'), 0)::numeric AS spend,
           max(j.created_at)                             AS last_at
    FROM public.repair_jobs j
    WHERE j.hospital_user_id IS NOT NULL
      AND j.created_at >= now() - interval '30 days'
    GROUP BY j.hospital_user_id
  )
  SELECT
    coalesce(p2.full_name, '(no name)')::text                            AS hospital_name,
    pp.jobs_posted,
    pp.jobs_completed,
    pp.spend                                                              AS total_spend_inr,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.hospital_user_id = pp.hospital_user_id
                AND c.status IN ('active','paused')), 0)::bigint          AS amc_count,
    pp.last_at                                                            AS last_active_at
  FROM posted pp
  LEFT JOIN public.profiles p2 ON p2.id = pp.hospital_user_id
  ORDER BY pp.jobs_posted DESC, pp.spend DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_leaderboard_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_leaderboard_30d() TO authenticated;
COMMIT;
