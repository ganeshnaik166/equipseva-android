BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_signups_by_week_13wk()
RETURNS TABLE (
  week_start         date,
  engineer_signups   bigint,
  hospital_signups   bigint,
  other_signups      bigint,
  total              bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS engineer_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS hospital_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role NOT IN ('engineer','hospital')
                AND date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS other_signups,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE date_trunc('week', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)            AS total
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_week_13wk() TO authenticated;
COMMIT;
