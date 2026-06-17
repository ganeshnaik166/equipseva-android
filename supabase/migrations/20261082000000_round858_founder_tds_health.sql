-- Round 858 — TDS deductions health surface: monthly count of tds_deductions
-- rows + total processed payouts in same month. If payouts exist but TDS
-- rows don't, the r490 trigger is broken (likely the same amount_rupees
-- column reference that r856 may have just fixed).
BEGIN;
DROP FUNCTION IF EXISTS public.founder_tds_health();
CREATE OR REPLACE FUNCTION public.founder_tds_health()
RETURNS TABLE (
  month_at         date,
  tds_rows         bigint,
  processed_payouts bigint,
  coverage_pct     numeric
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
    )::date AS month_at
  ),
  tds AS (
    SELECT date_trunc('month', t.created_at)::date AS m, count(*)::bigint AS cnt
    FROM public.tds_deductions t
    WHERE t.created_at >= now() - interval '12 months'
    GROUP BY 1
  ),
  pays AS (
    SELECT date_trunc('month', p.processed_at)::date AS m, count(*)::bigint AS cnt
    FROM public.engineer_payouts p
    WHERE p.status = 'processed'
      AND p.processed_at >= now() - interval '12 months'
    GROUP BY 1
  )
  SELECT
    m.month_at,
    coalesce(tds.cnt, 0)::bigint,
    coalesce(pays.cnt, 0)::bigint,
    CASE WHEN coalesce(pays.cnt, 0) = 0 THEN 0::numeric
         ELSE round(coalesce(tds.cnt, 0)::numeric / pays.cnt::numeric * 100.0, 1)
    END
  FROM months m
  LEFT JOIN tds  ON tds.m  = m.month_at
  LEFT JOIN pays ON pays.m = m.month_at
  ORDER BY m.month_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tds_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tds_health() TO authenticated;
COMMIT;
