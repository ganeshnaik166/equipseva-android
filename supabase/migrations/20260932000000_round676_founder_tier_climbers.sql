BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_climbers();
CREATE OR REPLACE FUNCTION public.founder_tier_climbers()
RETURNS TABLE (
  engineer_user_id   uuid,
  display_name       text,
  current_tier       text,
  jobs_completed     int,
  dispute_rate_pct   numeric,
  last_computed_at   timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    cp.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    cp.current_tier,
    cp.jobs_completed,
    cp.dispute_rate_pct,
    cp.last_computed_at
  FROM public.engineer_certification_progress cp
  LEFT JOIN public.profiles p ON p.id = cp.engineer_user_id
  WHERE cp.current_tier <> 'gold'
  ORDER BY cp.jobs_completed DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_climbers() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_climbers() TO authenticated;
COMMIT;
