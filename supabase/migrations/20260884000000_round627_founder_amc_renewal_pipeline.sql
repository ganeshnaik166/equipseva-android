BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_pipeline();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_pipeline()
RETURNS TABLE (
  window_label        text,
  expiring_count      bigint,
  auto_renew_count    bigint,
  manual_count        bigint,
  monthly_mrr_rupees  numeric,
  annual_arr_rupees   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      c.id,
      c.end_date,
      c.auto_renew,
      c.monthly_fee_rupees,
      c.renewal_term_months,
      (c.end_date - v_today) AS days_left
    FROM public.amc_contracts c
    WHERE c.status = 'active'
      AND c.end_date >= v_today
  ),
  buckets AS (
    SELECT 1 AS ord, '0-30d'::text  AS label, * FROM base WHERE days_left <= 30
    UNION ALL
    SELECT 2 AS ord, '31-60d'::text AS label, * FROM base WHERE days_left > 30 AND days_left <= 60
    UNION ALL
    SELECT 3 AS ord, '61-90d'::text AS label, * FROM base WHERE days_left > 60 AND days_left <= 90
    UNION ALL
    SELECT 4 AS ord, '>90d'::text   AS label, * FROM base WHERE days_left > 90
  )
  SELECT
    b.label,
    count(*)::bigint,
    count(*) FILTER (WHERE b.auto_renew)::bigint,
    count(*) FILTER (WHERE NOT b.auto_renew)::bigint,
    coalesce(sum(b.monthly_fee_rupees), 0)::numeric,
    coalesce(sum(b.monthly_fee_rupees * 12), 0)::numeric
  FROM buckets b
  GROUP BY b.ord, b.label
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline() TO authenticated;
COMMIT;
