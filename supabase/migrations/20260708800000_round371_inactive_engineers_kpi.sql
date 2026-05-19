-- Round 371 — extend admin_dashboard_stats() with `inactive_engineers_30d`.
-- Verified engineers who haven't released a single repair_job_escrow row
-- in the last 30 days. Founder needs to spot the bottom of the supply
-- distribution: an engineer who signed up but isn't shipping. Reach out
-- before they churn off the platform entirely.

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
  amc_contracts_expiring_soon int,
  amc_contracts_paused int,
  inactive_engineers_30d int
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
      (SELECT count(*)::int
         FROM public.amc_contracts
        WHERE status = 'active'
          AND end_date IS NOT NULL
          AND end_date >= current_date
          AND end_date <= current_date + interval '30 days'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'paused'),
      -- Round 371 — verified engineers with no released-escrow activity
      -- in the trailing 30 days. Excludes newly-verified engineers
      -- (created within the last 7 days) so they aren't flagged before
      -- they've had a real chance to ship.
      (SELECT count(*)::int
         FROM public.engineers e
        WHERE coalesce(e.verification_status,'pending') = 'verified'
          AND e.created_at < now() - interval '7 days'
          AND NOT EXISTS (
            SELECT 1 FROM public.repair_job_escrow rje
             WHERE rje.engineer_user_id = e.user_id
               AND rje.status = 'released'
               AND rje.released_at >= now() - interval '30 days'
          ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
