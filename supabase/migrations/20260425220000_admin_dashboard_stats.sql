-- Founder admin dashboard stats RPC.
-- Returns headline counts the FounderDashboard hero strip surfaces in place of
-- the static "—" placeholders.

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS TABLE (
  pending_kyc int,
  pending_sellers int,
  pending_reports int,
  orders_today int,
  integrity_failures_today int
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
      (SELECT count(*)::int FROM public.device_integrity_checks WHERE created_at >= date_trunc('day', now()) AND coalesce(pass, true) = false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
