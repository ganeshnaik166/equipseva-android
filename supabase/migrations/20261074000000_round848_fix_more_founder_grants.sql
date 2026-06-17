-- Round 848 — Batch-fix founder RPC grants that are called from web pages /
-- server actions but were created with service_role-only GRANT.
--
-- The pattern is the same as r847/r499: a founder SECDEF RPC with the
-- `is_founder()` body gate gets GRANT TO service_role only, but the
-- web ops console calls it from SSR with the founder's JWT — never
-- with the service-role key. Every page load throws permission_denied
-- and renders the Next error boundary instead of the data.
--
-- Audit found 8 more broken callers across /health, /risk, /supply,
-- /hospitals/[id], /ops, plus 2 form actions for /risk and disputes.
-- Add GRANT TO authenticated for each; the body's is_founder() check
-- still gates non-founders. The service_role grant stays in place for
-- edge-function callers.
BEGIN;

-- r481 (emergency founder-fn lockdown)
GRANT EXECUTE ON FUNCTION public.founder_razorpay_binding_health()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_payment_verify_failures(timestamptz)
  TO authenticated;

-- r498 (risk scoring + collusion flags)
GRANT EXECUTE ON FUNCTION public.founder_risk_top_n(text, text, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_open_collusion_flags(integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_resolve_collusion_flag(uuid, text, text)
  TO authenticated;

-- r500 (bonded parts provenance)
GRANT EXECUTE ON FUNCTION public.founder_bonded_parts_dashboard()
  TO authenticated;

-- r505 (escrow release polish)
GRANT EXECUTE ON FUNCTION public.founder_force_release_escrow(uuid, text)
  TO authenticated;

-- r507 (predictive PM calendar)
GRANT EXECUTE ON FUNCTION public.founder_pm_overdue_summary(integer)
  TO authenticated;

-- r508 (fleet MTBF/MTTR)
GRANT EXECUTE ON FUNCTION public.founder_fleet_red_flags(integer)
  TO authenticated;

-- r509 (code red emergency)
GRANT EXECUTE ON FUNCTION public.founder_code_red_recent(integer, integer)
  TO authenticated;

COMMIT;
