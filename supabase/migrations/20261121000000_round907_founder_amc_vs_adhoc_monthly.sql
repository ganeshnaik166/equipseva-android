BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_vs_adhoc_monthly();
CREATE OR REPLACE FUNCTION public.founder_amc_vs_adhoc_monthly()
RETURNS TABLE (
  month_ist     date,
  amc_jobs      bigint,
  adhoc_jobs    bigint,
  amc_share_pct numeric
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
  ),
  per_month AS (
    SELECT
      date_trunc('month', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date AS m,
      count(*) FILTER (WHERE rj.amc_contract_id IS NOT NULL) AS amc_cnt,
      count(*) FILTER (WHERE rj.amc_contract_id IS NULL)     AS adhoc_cnt
    FROM public.repair_jobs rj
    WHERE rj.created_at >= now() - interval '12 months'
    GROUP BY 1
  )
  SELECT
    months.month_ist,
    coalesce(pm.amc_cnt, 0)::bigint,
    coalesce(pm.adhoc_cnt, 0)::bigint,
    CASE WHEN coalesce(pm.amc_cnt, 0) + coalesce(pm.adhoc_cnt, 0) = 0 THEN 0::numeric
         ELSE round(coalesce(pm.amc_cnt, 0)::numeric
                    / (coalesce(pm.amc_cnt, 0) + coalesce(pm.adhoc_cnt, 0))::numeric * 100.0, 1)
    END
  FROM months
  LEFT JOIN per_month pm ON pm.m = months.month_ist
  ORDER BY months.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_vs_adhoc_monthly() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_vs_adhoc_monthly() TO authenticated;
COMMIT;
