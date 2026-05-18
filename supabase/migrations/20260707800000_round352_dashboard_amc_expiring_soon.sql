-- Round 352 — extend admin_dashboard_stats() with `amc_contracts_expiring_soon`
-- (active contracts ending within 30 days). Founder needs forward
-- visibility to plan renewal outreach BEFORE the contract lapses.
-- "amc_contracts_expired" (round 343) is reactive — by then the AMC
-- has already churned.

DROP FUNCTION IF EXISTS public.admin_dashboard_stats();

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS TABLE (
  pending_kyc int,
  pending_sellers int,
  pending_reports int,
  orders_today int,
  integrity_failures_today int,
  new_signups_today int,
  active_repair_jobs int,
  amc_contracts_active int,
  amc_contracts_expired int,
  amc_contracts_expiring_soon int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM public.engineers WHERE coalesce(verification_status,'pending') = 'pending'),
      (SELECT count(*)::int FROM public.seller_verification_requests WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.content_reports WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.spare_part_orders WHERE created_at >= date_trunc('day', now())),
      (SELECT count(*)::int FROM public.device_integrity_checks WHERE created_at >= date_trunc('day', now()) AND coalesce(pass, true) = false),
      (SELECT count(*)::int FROM auth.users WHERE created_at >= date_trunc('day', now())),
      (SELECT count(*)::int FROM public.repair_jobs WHERE status IN ('requested','assigned','in_progress')),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'active'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'expired'),
      -- Round 352 — active contracts ending in the next 30 days.
      (SELECT count(*)::int
         FROM public.amc_contracts
        WHERE status = 'active'
          AND end_date IS NOT NULL
          AND end_date >= current_date
          AND end_date <= current_date + interval '30 days');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
