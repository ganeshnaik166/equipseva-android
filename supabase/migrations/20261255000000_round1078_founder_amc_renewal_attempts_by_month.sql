BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_attempts_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_attempts_by_month()
RETURNS TABLE (
  month_ist        date,
  total_attempts   bigint,
  succeeded        bigint,
  failed           bigint,
  abandoned        bigint,
  pending          bigint,
  success_pct      numeric
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
              WHERE date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)             AS total_attempts,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'succeeded'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)             AS succeeded,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'failed'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)             AS failed,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'abandoned'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)             AS abandoned,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              WHERE a.status = 'pending'
                AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)             AS pending,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
                     WHERE date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.amc_renewal_attempts a
                          WHERE a.status = 'succeeded'
                            AND date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
        / coalesce((SELECT count(*)::numeric FROM public.amc_renewal_attempts a
                    WHERE date_trunc('month', (a.attempted_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 1),
        1)
    END                                                                                                                    AS success_pct
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_by_month() TO authenticated;
COMMIT;
