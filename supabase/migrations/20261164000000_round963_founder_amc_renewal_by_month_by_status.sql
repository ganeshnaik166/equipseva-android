BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_by_month_by_status();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_by_month_by_status()
RETURNS TABLE (
  month_ist   date,
  succeeded   bigint,
  failed      bigint,
  abandoned   bigint
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
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'succeeded'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'failed'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'abandoned'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_by_month_by_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_by_month_by_status() TO authenticated;
COMMIT;
