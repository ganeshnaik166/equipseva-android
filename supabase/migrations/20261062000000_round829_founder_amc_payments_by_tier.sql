BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_payments_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_payments_by_tier()
RETURNS TABLE (
  tier            text,
  paid_orders_90d bigint,
  paid_rupees_90d numeric,
  active_contracts bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_orders o
              JOIN public.amc_contracts c ON c.id = o.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              JOIN public.amc_contracts c ON c.id = o.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND o.status = 'paid'
               AND o.created_at >= now() - interval '90 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c2
              WHERE c2.amc_tier = t.tier AND c2.status = 'active'), 0)::bigint
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_payments_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_payments_by_tier() TO authenticated;
COMMIT;
