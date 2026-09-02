-- Round 3765 — admin_dashboard_stats()'s active_repair_jobs count omits
-- the 'en_route' job_status label.
--
-- Found continuing the same bug-class sweep as round3760-3764: confirmed
-- via the live enum (pg_enum on the type backing repair_jobs.status)
-- that job_status has 7 real labels — requested / assigned / en_route /
-- in_progress / completed / cancelled / disputed — but
-- admin_dashboard_stats (current body: round459,
-- 20260715800000_round459_ist_timezone_bundle.sql) counts
-- `status IN ('requested','assigned','in_progress')`, silently skipping
-- 'en_route' from the founder dashboard's "active jobs" KPI.
--
-- Currently ZERO practical impact (verified live: `en_route` is a
-- write-target for NO function anywhere in supabase/migrations — grepped
-- the entire directory for `status = 'en_route'` and got no hits;
-- engineer_check_in_with_geo, the only place that transitions a job past
-- 'assigned', writes straight to 'in_progress'). So no repair_jobs row
-- has ever actually held 'en_route', and this dashboard undercount has
-- never fired in practice. Fixed anyway for the same reason round3763
-- (dormant engineer_id_guard bypass) was fixed despite zero live impact:
-- a defensive/correctness gap that would silently misreport the moment
-- any future code path (a distinct "engineer started driving" transition,
-- for instance) starts writing 'en_route' for real.
--
-- Fix: add 'en_route' to the active-jobs status list. Function body
-- otherwise byte-identical to round459.
BEGIN;

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
DECLARE
  v_ist_today_start timestamptz := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';
  v_ist_today_date date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM public.engineers WHERE coalesce(verification_status,'pending') = 'pending'),
      (SELECT count(*)::int FROM public.seller_verification_requests WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.content_reports WHERE status = 'pending'),
      (SELECT count(*)::int FROM public.spare_part_orders WHERE created_at >= v_ist_today_start),
      (SELECT count(*)::int FROM public.device_integrity_checks WHERE created_at >= v_ist_today_start AND coalesce(pass, true) = false),
      (SELECT count(*)::int FROM auth.users WHERE created_at >= v_ist_today_start),
      -- Round 3765: was ('requested','assigned','in_progress') — silently
      -- excluded the valid 'en_route' label. See migration header.
      (SELECT count(*)::int FROM public.repair_jobs WHERE status IN ('requested','assigned','en_route','in_progress')),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'active'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'expired'),
      (SELECT count(*)::int
         FROM public.amc_contracts
        WHERE status = 'active'
          AND end_date IS NOT NULL
          AND end_date >= v_ist_today_date
          AND end_date <= v_ist_today_date + interval '30 days'),
      (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'paused'),
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

COMMENT ON FUNCTION public.admin_dashboard_stats IS
  'Round 3765 (was round459) — founder dashboard KPI snapshot. active_repair_jobs now includes en_route alongside requested/assigned/in_progress (previously silently excluded — zero live impact since no code path has ever written en_route, but would have undercounted the moment one did).';

COMMIT;
