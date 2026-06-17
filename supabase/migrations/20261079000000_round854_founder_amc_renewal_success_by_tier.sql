BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_success_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_success_by_tier()
RETURNS TABLE (
  tier            text,
  attempted_90d   bigint,
  succeeded_90d   bigint,
  failed_90d      bigint,
  success_pct     numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status <> 'pending'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status = 'succeeded'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status = 'failed'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status <> 'pending'), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status = 'succeeded')
           / (SELECT count(*)::numeric FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
             WHERE c.amc_tier = t.tier
               AND a.attempted_at >= now() - interval '90 days'
               AND a.status <> 'pending')
           * 100.0, 1)
    END
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_success_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_success_by_tier() TO authenticated;
COMMIT;
