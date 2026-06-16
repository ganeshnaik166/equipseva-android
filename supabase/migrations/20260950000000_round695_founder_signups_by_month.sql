BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_month();
CREATE OR REPLACE FUNCTION public.founder_signups_by_month()
RETURNS TABLE (
  month_ist   date,
  signups     bigint,
  engineers   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce(
      (SELECT count(*)::bigint FROM auth.users u
       WHERE date_trunc('month', (u.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineers e
       WHERE date_trunc('month', (e.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_month() TO authenticated;
COMMIT;
