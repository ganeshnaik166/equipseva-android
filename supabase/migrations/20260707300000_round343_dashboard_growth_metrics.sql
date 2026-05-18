-- Round 343 — extend admin_dashboard_stats() with 4 new growth metrics
-- the founder needs for post-launch operational visibility.
--
-- Before: pending_kyc, pending_sellers, pending_reports, orders_today,
--         integrity_failures_today
--
-- After (additions):
--   * new_signups_today     — auth.users.created_at >= today
--   * active_repair_jobs    — status IN ('requested','assigned','in_progress')
--   * amc_contracts_active  — status = 'active'
--   * amc_contracts_expired — status = 'expired'
--
-- All counts piggyback on indexes the round-342 migration added.
-- Backward compatible: existing fields kept in same order so the
-- Kotlin DashboardStats default-0 fields tolerate older RPC responses
-- during the staged client rollout.

-- PG rejects CREATE OR REPLACE with a changed return signature; we
-- have to DROP first. is_founder() check inside the body still gates
-- the rebuilt function.
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
  amc_contracts_expired int
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
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'expired');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
