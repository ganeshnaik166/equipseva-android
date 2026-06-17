BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_mrr_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_mrr_by_tier()
RETURNS TABLE (
  tier         text,
  active_cnt   bigint,
  mrr_rupees   numeric,
  arr_rupees   numeric,
  avg_fee      numeric,
  share_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_mrr numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total_mrr
    FROM public.amc_contracts WHERE status='active';
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::numeric,
    coalesce((SELECT sum(c.monthly_fee_rupees * 12)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)::numeric,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active')
           / (SELECT count(*)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 2)
    END,
    CASE WHEN v_total_mrr = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c WHERE c.amc_tier = t.tier AND c.status='active'), 0)
           / v_total_mrr * 100.0, 1)
    END
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_mrr_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_mrr_by_tier() TO authenticated;
COMMIT;
