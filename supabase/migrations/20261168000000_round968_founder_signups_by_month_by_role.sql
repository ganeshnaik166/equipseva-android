BEGIN;
DROP FUNCTION IF EXISTS public.founder_signups_by_month_by_role();
CREATE OR REPLACE FUNCTION public.founder_signups_by_month_by_role()
RETURNS TABLE (
  month_ist   date,
  total       bigint,
  engineers   bigint,
  hospitals   bigint
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
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role='engineer'
                AND date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role='hospital'
                AND date_trunc('month', (p.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_signups_by_month_by_role() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_signups_by_month_by_role() TO authenticated;
COMMIT;
