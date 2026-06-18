BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_leaderboard_30d();
CREATE OR REPLACE FUNCTION public.founder_engineer_leaderboard_30d()
RETURNS TABLE (
  engineer_name      text,
  city               text,
  completed_jobs     bigint,
  total_earnings_inr numeric,
  avg_rating         numeric,
  tier               text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(p.full_name, '(no name)')::text                                  AS engineer_name,
    coalesce(e.city, '(unknown)')::text                                       AS city,
    count(j.id)::bigint                                                       AS completed_jobs,
    coalesce(sum(j.engineer_amount), 0)::numeric                              AS total_earnings_inr,
    coalesce(round(avg(j.hospital_rating)::numeric, 2), 0)::numeric           AS avg_rating,
    coalesce(e.cached_highest_tier, 'none')::text                                            AS tier
  FROM public.repair_jobs j
  JOIN public.engineers e ON e.id = j.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE j.status = 'completed'
    AND j.completed_at >= now() - interval '30 days'
  GROUP BY p.full_name, e.city, e.cached_highest_tier
  ORDER BY count(j.id) DESC, sum(j.engineer_amount) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_leaderboard_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_leaderboard_30d() TO authenticated;
COMMIT;
