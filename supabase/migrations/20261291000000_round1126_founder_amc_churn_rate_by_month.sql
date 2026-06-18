BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_churn_rate_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_churn_rate_by_month()
RETURNS TABLE (
  month_ist             date,
  active_start_of_month bigint,
  expired_in_month      bigint,
  newly_paused_in_month bigint,
  churn_pct             numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.created_at < m.month_ist::timestamptz
                AND (c.end_date IS NULL OR c.end_date >= m.month_ist)), 0)::bigint                          AS active_start_of_month,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'expired'
                AND c.end_date IS NOT NULL
                AND date_trunc('month', c.end_date)::date = m.month_ist), 0)::bigint                       AS expired_in_month,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'paused'
                AND date_trunc('month', (c.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS newly_paused_in_month,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
                     WHERE c.created_at < m.month_ist::timestamptz
                       AND (c.end_date IS NULL OR c.end_date >= m.month_ist)), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * (
          coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                    WHERE c.status = 'expired'
                      AND c.end_date IS NOT NULL
                      AND date_trunc('month', c.end_date)::date = m.month_ist), 0)
          + coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                      WHERE c.status = 'paused'
                        AND date_trunc('month', (c.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
        )
        / coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                    WHERE c.created_at < m.month_ist::timestamptz
                      AND (c.end_date IS NULL OR c.end_date >= m.month_ist)), 1),
        2)
    END                                                                                                    AS churn_pct
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_rate_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_rate_by_month() TO authenticated;
COMMIT;
