BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_failures_aging();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_failures_aging()
RETURNS TABLE (
  bucket         text,
  cnt            bigint,
  mrr_rupees     numeric,
  oldest_days    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT c.monthly_fee_rupees, c.end_date,
           extract(epoch FROM (now()::date - c.end_date)) / 86400.0 AS days_old
    FROM public.amc_contracts c
    WHERE c.status = 'renewal_failed'
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('< 7d'::text,   1, 0::numeric,   7::numeric),
      ('7-30d',        2, 7::numeric,  30::numeric),
      ('30-60d',       3, 30::numeric, 60::numeric),
      ('60-90d',       4, 60::numeric, 90::numeric),
      ('>90d',         5, 90::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi)::bigint,
    coalesce(sum(base.monthly_fee_rupees) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric,
    coalesce(max(base.days_old) FILTER (WHERE base.days_old >= b.lo AND base.days_old < b.hi), 0)::numeric
  FROM buckets b LEFT JOIN base ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_failures_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_failures_aging() TO authenticated;
COMMIT;
