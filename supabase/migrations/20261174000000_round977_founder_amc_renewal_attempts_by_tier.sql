BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_attempts_by_tier();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_attempts_by_tier()
RETURNS TABLE (
  tier        text,
  attempts    bigint,
  succeeded   bigint,
  failed      bigint,
  abandoned   bigint
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
                AND a.attempted_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
              WHERE c.amc_tier = t.tier
                AND a.status = 'succeeded'
                AND a.attempted_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
              WHERE c.amc_tier = t.tier
                AND a.status = 'failed'
                AND a.attempted_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_renewal_attempts a
              JOIN public.amc_contracts c ON c.id = a.amc_contract_id
              WHERE c.amc_tier = t.tier
                AND a.status = 'abandoned'
                AND a.attempted_at >= now() - interval '90 days'), 0)::bigint
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_by_tier() TO authenticated;
COMMIT;
