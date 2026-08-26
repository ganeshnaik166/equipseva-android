-- Round 3755 — Enable RLS on 6 tables (3 ships) that shipped without it.
--
-- Found via an exhaustive workflow audit (16 parallel agents + adversarial
-- verify pass) of all 613 ops-dashboard batches / 756 migration files / 5016
-- founder_r####_* RPCs, checking: (a) every RPC's is_founder() guard is
-- unconditionally the first statement in its body, and (b) every ship
-- table has RLS enabled with zero policies (the established convention —
-- access is meant to flow ONLY through the SECURITY DEFINER RPCs, which
-- bypass RLS via their own elevated privileges after their own guard
-- check passes).
--
-- 116 of 119 raw findings were false positives (cosmetic phrasing
-- differences, RLS-policy lines mis-flagged as guard-order issues, etc.).
-- 3 were confirmed real: these tables were created with NO
-- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and NO `CREATE POLICY`
-- anywhere in their migration file at all — a plain omission, not a
-- deliberate design choice (every other one of the ~1500+ ship tables in
-- the corpus does have RLS enabled). All 8-9 RPCs in each of these 3
-- files DO have a correct, unconditional is_founder() guard as their first
-- statement, so the SECURITY DEFINER RPC path was never actually
-- vulnerable — but with RLS disabled, these 6 tables would be exposed to
-- direct PostgREST/table-level access bypassing the RPC layer entirely,
-- for any role that has (or is ever granted) direct table privileges.
-- Defense-in-depth: close that gap regardless of whether any such grant
-- currently exists.
--
--   r3107 (round3107_engineer_founder_insurance_claims_recovery_pipeline_tracker.sql):
--     public.insurance_claims_pipeline_r3107
--     public.insurance_claim_recovery_actions_r3107
--   r3135 (round3135_founder_board_observer_advisory_governance_cadence.sql):
--     board_advisory_members_r3135
--     board_cadence_sessions_r3135
--   r3137 (round3137_founder_executive_coach_peer_ceo_circle_tracker.sql):
--     founder_exec_coach_sessions_r3137
--     founder_peer_ceo_circle_feedback_r3137
--
-- Adding ENABLE ROW LEVEL SECURITY only, no policies — matches the
-- zero-policy convention used by every other ship, and doesn't touch the
-- RPCs (which already correctly gate on is_founder() and are unaffected
-- by RLS since they run SECURITY DEFINER).

BEGIN;

ALTER TABLE public.insurance_claims_pipeline_r3107 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_claim_recovery_actions_r3107 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.board_advisory_members_r3135 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_cadence_sessions_r3135 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.founder_exec_coach_sessions_r3137 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_peer_ceo_circle_feedback_r3137 ENABLE ROW LEVEL SECURITY;

COMMIT;
