-- Round 3756 — CRITICAL: close a live, currently-exploitable direct-table
-- read on founder_payroll_batches.
--
-- Found via a corpus-wide RLS-hygiene sweep (following up on the r3755
-- ops-dashboard audit) that checks, for every table ever CREATEd anywhere
-- in the migration corpus, whether it EVER gets
-- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` anywhere. 39 tables surfaced;
-- 38 of them have ZERO grants to any client-facing role on the raw table
-- (access can only happen via their SECURITY DEFINER RPCs, or service_role)
-- so missing RLS there is a defense-in-depth gap, not a live hole (fixed
-- separately in the same round, see r3757).
--
-- This ONE table is different and genuinely critical:
-- 20261424000000_round1325_founder_payroll_bulk_authorize.sql shipped
--   REVOKE ALL ON public.founder_payroll_batches FROM PUBLIC, anon;
--   REVOKE INSERT, UPDATE, DELETE ON public.founder_payroll_batches FROM authenticated;
--   GRANT  SELECT ON public.founder_payroll_batches TO authenticated;
-- with NO RLS ever enabled on the table (confirmed corpus-wide, no later
-- migration adds it either). The intended access path is the
-- SECURITY DEFINER RPC founder_payroll_batches_recent(), which correctly
-- checks `IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only'`
-- — but the direct SELECT grant to `authenticated` bypasses that guard
-- entirely: ANY logged-in EquipSeva user (any hospital account, any
-- engineer account — not just the founder) could read this table straight
-- via PostgREST (`GET .../rest/v1/founder_payroll_batches`), exposing
-- aggregate company payroll batch data (total_amount_rupees,
-- total_payouts_count, period, status, payout_ids, failure_reasons) to
-- the entire authenticated user base.
--
-- Confirmed via grep that neither the Android app nor the web console
-- ever queries this table directly (web/src/app/founder-payroll-bulk-
-- authorize/page.tsx only calls the RPC) — the direct grant was dead
-- weight for legitimate use, purely an exposure surface. Revoking it is
-- a no-op for the actual product; RLS is added as a second, independent
-- layer so a future migration accidentally re-adding a grant doesn't
-- reopen this.

BEGIN;

REVOKE SELECT ON public.founder_payroll_batches FROM authenticated;
ALTER TABLE public.founder_payroll_batches ENABLE ROW LEVEL SECURITY;

COMMIT;
