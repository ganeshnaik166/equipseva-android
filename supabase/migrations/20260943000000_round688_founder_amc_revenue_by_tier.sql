BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_revenue_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_tier()
RETURNS TABLE (
  tier             text,
  active_contracts bigint,
  monthly_mrr      numeric,
  annual_arr       numeric,
  share_pct        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total
    FROM public.amc_contracts WHERE status = 'active';
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  )
  SELECT
    t.tier,
    coalesce(count(c.id), 0)::bigint                       AS active_contracts,
    coalesce(sum(c.monthly_fee_rupees), 0)::numeric        AS monthly_mrr,
    coalesce(sum(c.monthly_fee_rupees) * 12, 0)::numeric   AS annual_arr,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(coalesce(sum(c.monthly_fee_rupees), 0)::numeric / v_total * 100.0, 1)
    END AS share_pct
  FROM tiers t
  LEFT JOIN public.amc_contracts c ON c.amc_tier = t.tier AND c.status = 'active'
  GROUP BY t.tier, t.display_order
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_by_tier() TO authenticated;
COMMIT;
