BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_rate_by_week();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_rate_by_week()
RETURNS TABLE (
  week_start      date,
  due_cnt         bigint,
  renewed_cnt     bigint,
  expired_cnt     bigint,
  renewal_pct     numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('week', c.end_date)::date = w.week_start), 0) AS due_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('week', c.end_date)::date = w.week_start
                AND c.status = 'active'), 0) AS renewed_cnt,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.end_date IS NOT NULL
                AND date_trunc('week', c.end_date)::date = w.week_start
                AND c.status = 'expired'), 0) AS expired_cnt,
    CASE WHEN coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
                        WHERE c.end_date IS NOT NULL
                          AND date_trunc('week', c.end_date)::date = w.week_start), 0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                                      WHERE c.end_date IS NOT NULL
                                        AND date_trunc('week', c.end_date)::date = w.week_start
                                        AND c.status = 'active'), 0)
                    / coalesce((SELECT count(*)::numeric FROM public.amc_contracts c
                                WHERE c.end_date IS NOT NULL
                                  AND date_trunc('week', c.end_date)::date = w.week_start), 1), 1)
    END AS renewal_pct
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_rate_by_week() TO authenticated;
COMMIT;
