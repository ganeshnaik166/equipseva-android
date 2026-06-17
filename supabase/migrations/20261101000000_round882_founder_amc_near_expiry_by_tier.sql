BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_near_expiry_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_near_expiry_by_tier()
RETURNS TABLE (
  tier           text,
  expiring_30d   bigint,
  expiring_60d   bigint,
  expiring_90d   bigint,
  mrr_at_risk    numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.amc_tier = t.tier AND c.status='active'
                AND c.end_date <= (now() + interval '30 days')::date), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.amc_tier = t.tier AND c.status='active'
                AND c.end_date <= (now() + interval '60 days')::date), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.amc_tier = t.tier AND c.status='active'
                AND c.end_date <= (now() + interval '90 days')::date), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.amc_tier = t.tier AND c.status='active'
                AND c.end_date <= (now() + interval '30 days')::date), 0)::numeric
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_near_expiry_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_near_expiry_by_tier() TO authenticated;
COMMIT;
