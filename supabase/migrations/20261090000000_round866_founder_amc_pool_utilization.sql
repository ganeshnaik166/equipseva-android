BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_utilization();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_utilization()
RETURNS TABLE (
  bucket    text,
  cnt       bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH per_contract AS (
    SELECT
      c.id,
      coalesce(sum(p.amount_rupees) FILTER (WHERE p.ledger_kind='credit'), 0) AS credits,
      coalesce(sum(p.amount_rupees) FILTER (WHERE p.ledger_kind='debit'), 0)  AS debits
    FROM public.amc_contracts c
    LEFT JOIN public.amc_payment_pool p ON p.amc_contract_id = c.id
    WHERE c.status = 'active'
    GROUP BY c.id
  ),
  with_pct AS (
    SELECT CASE WHEN credits = 0 THEN -1::numeric
                ELSE round(debits::numeric / credits::numeric * 100.0, 1)
           END AS use_pct
    FROM per_contract
  ),
  buckets(label, ord, lo, hi) AS (
    VALUES
      ('No credits ever'::text, 1, -1::numeric, -1::numeric),
      ('0% used',                2, 0::numeric, 0.01::numeric),
      ('1-25% used',             3, 0.01::numeric, 25::numeric),
      ('25-50% used',            4, 25::numeric, 50::numeric),
      ('50-75% used',            5, 50::numeric, 75::numeric),
      ('75-100% used',           6, 75::numeric, 100::numeric),
      ('Over-spent (>100%)',     7, 100::numeric, 1e9::numeric)
  )
  SELECT b.label,
    count(*) FILTER (WHERE wp.use_pct >= b.lo AND wp.use_pct < b.hi OR (b.lo = -1 AND wp.use_pct = -1))::bigint,
    CASE WHEN (SELECT count(*) FROM with_pct) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE wp.use_pct >= b.lo AND wp.use_pct < b.hi OR (b.lo = -1 AND wp.use_pct = -1))::numeric
           / (SELECT count(*) FROM with_pct)::numeric * 100.0, 1)
    END
  FROM buckets b LEFT JOIN with_pct wp ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_utilization() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_utilization() TO authenticated;
COMMIT;
