BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_rate_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_rate_by_month()
RETURNS TABLE (
  month_ist        date,
  due_cnt          bigint,
  renewed_cnt      bigint,
  expired_cnt      bigint,
  renewal_pct      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '5 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('month', c.end_date)::date = m.month_ist), 0)                       AS due_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('month', c.end_date)::date = m.month_ist
                AND c.status = 'active'), 0)                                                       AS renewed_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('month', c.end_date)::date = m.month_ist
                AND c.status = 'expired'), 0)                                                      AS expired_cnt,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
                     WHERE c.end_date IS NOT NULL
                       AND date_trunc('month', c.end_date)::date = m.month_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                          WHERE c.end_date IS NOT NULL
                            AND date_trunc('month', c.end_date)::date = m.month_ist
                            AND c.status = 'active'), 0)
        / coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                    WHERE c.end_date IS NOT NULL
                      AND date_trunc('month', c.end_date)::date = m.month_ist), 1),
        1)
    END                                                                                            AS renewal_pct
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_month() TO authenticated;
COMMIT;
