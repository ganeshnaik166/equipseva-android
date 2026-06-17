BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_coverage();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_coverage()
RETURNS TABLE (
  bucket       text,
  cnt          bigint,
  share_pct    numeric,
  ord          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.amc_contracts WHERE status = 'active';
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (p.amc_contract_id)
      p.amc_contract_id,
      p.balance_after
    FROM public.amc_payment_pool p
    ORDER BY p.amc_contract_id, p.created_at DESC
  ),
  classed AS (
    SELECT
      c.id,
      coalesce(l.balance_after, 0) AS balance,
      c.monthly_fee_rupees AS fee
    FROM public.amc_contracts c
    LEFT JOIN latest l ON l.amc_contract_id = c.id
    WHERE c.status = 'active'
  )
  SELECT
    label, cnt,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(cnt::numeric / v_total::numeric * 100.0, 1)
    END,
    ord
  FROM (
    SELECT 'Healthy (≥2× fee)'::text AS label,
      count(*) FILTER (WHERE balance >= 2 * fee)::bigint AS cnt,
      1 AS ord
      FROM classed
    UNION ALL
    SELECT 'Caution (1×–2× fee)', count(*) FILTER (WHERE balance >= fee AND balance < 2 * fee)::bigint, 2 FROM classed
    UNION ALL
    SELECT 'Low (0–1× fee)', count(*) FILTER (WHERE balance > 0 AND balance < fee)::bigint, 3 FROM classed
    UNION ALL
    SELECT 'Negative / zero', count(*) FILTER (WHERE balance <= 0)::bigint, 4 FROM classed
  ) t
  ORDER BY ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_coverage() TO authenticated;
COMMIT;
