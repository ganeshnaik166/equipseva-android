BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_dormancy();
CREATE OR REPLACE FUNCTION public.founder_engineer_dormancy()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  total_jobs        bigint,
  last_completed_at timestamptz,
  days_dormant      int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH last_job AS (
    SELECT b.engineer_user_id,
           count(*)::bigint               AS total_jobs,
           max(rj.completed_at)           AS last_completed_at
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
    GROUP BY b.engineer_user_id
  )
  SELECT
    l.engineer_user_id,
    coalesce(p.full_name, '(engineer)') AS display_name,
    l.total_jobs,
    l.last_completed_at,
    extract(day FROM (now() - l.last_completed_at))::int AS days_dormant
  FROM last_job l
  LEFT JOIN public.profiles p ON p.id = l.engineer_user_id
  WHERE l.last_completed_at < now() - interval '30 days'
    AND l.total_jobs >= 1
  ORDER BY l.last_completed_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_dormancy() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_dormancy() TO authenticated;
COMMIT;
