-- =====================================================================
-- Round 3824 -- the founder console's own RPCs were never granted to
--               the role the console calls them with, so 26 of its
--               pages have been answering 42501 to the founder
-- =====================================================================
--
-- FOUND BY: a grants ratchet that joins every `.rpc("…")` call site in the
-- Android app, the Next.js console and the edge functions against the EXECUTE
-- privileges each API role actually holds (supabase/regression/). Of 15,565
-- distinct RPC names the clients call, 27 had no EXECUTE for the role their
-- caller runs as and 7 do not exist at all.
--
-- THE GAP: the console authenticates with the anon key plus the founder's own
-- session cookie (web/src/lib/supabase/server.ts), so every RPC it issues runs
-- as `authenticated`. These functions were left with `postgres=X/postgres
-- service_role=X/postgres` — EXECUTE for the service role only — so the founder
-- sees a failed panel on Disputes, Finance, Health, Refunds, Reconciliation,
-- Risk, DPDP, Referrals, Tiers, Chains, Investor and the engineer detail page.
-- The 195 sibling founder_* functions follow the house pattern instead: broad
-- EXECUTE, authorisation re-checked inside the body with is_founder().
--
-- WHAT THIS DOES
--   1. Grants EXECUTE to `authenticated` on the 26 of those 27 whose body
--      already re-checks is_founder()/is_admin(). The gate below refuses to run
--      if any of them stops being SECURITY DEFINER or loses that internal
--      check, so the grant can never outlive the thing that makes it safe.
--   2. The 27th, founder_payouts_dead_letter_summary(), had NO internal check,
--      so granting it as-is would have exposed failed-payout amounts and
--      reasons to every signed-in user. It is re-created with the house gate
--      (and keeps its SQL body verbatim) before being granted.
--   3. Revokes EXECUTE from PUBLIC, anon and authenticated on
--      founder_clv_snapshot_all_hospitals(), a SECURITY DEFINER function that
--      loops over every AMC hospital and INSERTs a snapshot row per hospital,
--      swallowing errors. It is reachable by `anon` today, i.e. an
--      unauthenticated caller can pump rows into
--      founder_customer_lifetime_value_snapshots at will. Nothing calls it (no
--      cron slot, no client), so service_role keeps it and every other role
--      loses it.
--
-- WHY GRANTS AND NOT A CLIENT CHANGE: the console is the founder's own UI and
-- every one of these bodies re-derives the caller's identity from the JWT, so
-- `authenticated` is the correct audience. No body's authorisation is relaxed
-- here; the one function whose authorisation was missing gains it.
--
-- ROLLBACK (exact):
--   BEGIN;
--   -- 1. undo the grants
--   REVOKE EXECUTE ON FUNCTION public.approve_refund_authorization(uuid,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.engineer_sla_board(integer,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_certification_tier_distribution() FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_decide_dispute_pack(uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_dispute_queue(integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_dpdp_grievances_list(text,integer,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_gst_summary(text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_kyc_renewal_queue(text,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_list_hospital_chains(text,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_list_investor_share_tokens(integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_mint_investor_share_token(text,integer,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_open_duplicate_flags(text,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_pending_refund_authorizations(integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_promote_engineer_tier(uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_anomalies_open(integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_recent(integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_referral_dashboard() FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_register_hospital_chain(text,uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_resolve_duplicate_flag(uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_resolve_grievance(uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_revoke_investor_share_token(uuid,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_revoke_referral_bounty(uuid,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_set_amc_tier(uuid,text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_suspicious_attendance_recent(integer,integer) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.founder_tds_quarterly_summary(text,text) FROM authenticated;
--   REVOKE EXECUTE ON FUNCTION public.reject_refund_authorization(uuid,text) FROM authenticated;
--   -- 2. restore the ungated summary (body unchanged, gate removed) and its ACL
--   --    see the original definition quoted in the DO block below.
--   REVOKE EXECUTE ON FUNCTION public.founder_payouts_dead_letter_summary() FROM authenticated;
--   -- 3. restore the snapshot function's previous ACL
--   GRANT EXECUTE ON FUNCTION public.founder_clv_snapshot_all_hospitals() TO anon, authenticated;
--   COMMIT;

BEGIN;

-- ---------------------------------------------------------------------
-- PRECONDITION GATE -- refuse to grant if the thing that makes the grant
-- safe is not there. Drift raises rather than silently widening access.
-- ---------------------------------------------------------------------
DO $gate$
DECLARE
  v_sigs text[] := ARRAY[
    'approve_refund_authorization(uuid,text)',
    'engineer_sla_board(integer,integer)',
    'founder_certification_tier_distribution()',
    'founder_decide_dispute_pack(uuid,text,text)',
    'founder_dispute_queue(integer)',
    'founder_dpdp_grievances_list(text,integer,integer)',
    'founder_gst_summary(text,text)',
    'founder_kyc_renewal_queue(text,integer)',
    'founder_list_hospital_chains(text,integer)',
    'founder_list_investor_share_tokens(integer)',
    'founder_mint_investor_share_token(text,integer,integer)',
    'founder_open_duplicate_flags(text,integer)',
    'founder_pending_refund_authorizations(integer)',
    'founder_promote_engineer_tier(uuid,text,text)',
    'founder_reconciliation_anomalies_open(integer)',
    'founder_reconciliation_recent(integer)',
    'founder_referral_dashboard()',
    'founder_register_hospital_chain(text,uuid,text,text)',
    'founder_resolve_duplicate_flag(uuid,text,text)',
    'founder_resolve_grievance(uuid,text,text)',
    'founder_revoke_investor_share_token(uuid,text)',
    'founder_revoke_referral_bounty(uuid,text)',
    'founder_set_amc_tier(uuid,text,text)',
    'founder_suspicious_attendance_recent(integer,integer)',
    'founder_tds_quarterly_summary(text,text)',
    'reject_refund_authorization(uuid,text)'
  ];
  v_sig      text;
  v_oid      oid;
  v_checked  int := 0;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := pg_catalog.to_regprocedure('public.' || v_sig);
    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'round 3824 PRECONDITION FAILED: % does not exist', v_sig
        USING ERRCODE = '55000';
    END IF;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
      RAISE EXCEPTION 'round 3824 PRECONDITION FAILED: % is not SECURITY DEFINER', v_sig
        USING ERRCODE = '55000';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc WHERE oid = v_oid
        AND prosrc ~* 'is_founder\(\)|is_admin\(|founder only|admin only'
    ) THEN
      RAISE EXCEPTION 'round 3824 PRECONDITION FAILED: % has no internal founder/admin check, refusing to grant', v_sig
        USING ERRCODE = '55000';
    END IF;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'round 3824 PRECONDITION FAILED: % is already anon-executable, investigate before granting', v_sig
        USING ERRCODE = '55000';
    END IF;
    v_checked := v_checked + 1;
  END LOOP;

  -- A gate that can pass while proving nothing is worse than no gate.
  IF v_checked <> 26 THEN
    RAISE EXCEPTION 'round 3824 PRECONDITION FAILED: checked % of 26 functions', v_checked;
  END IF;
  RAISE NOTICE 'round 3824: 26 functions verified SECURITY DEFINER + internally gated + not anon-executable';
END;
$gate$;

-- ---------------------------------------------------------------------
-- 1. The grants the console has always needed
-- ---------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.approve_refund_authorization(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineer_sla_board(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_certification_tier_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_decide_dispute_pack(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dispute_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dpdp_grievances_list(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_gst_summary(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_kyc_renewal_queue(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_list_hospital_chains(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_list_investor_share_tokens(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_mint_investor_share_token(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_open_duplicate_flags(text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pending_refund_authorizations(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_promote_engineer_tier(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_reconciliation_anomalies_open(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_reconciliation_recent(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_referral_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_register_hospital_chain(text,uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_resolve_duplicate_flag(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_resolve_grievance(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_revoke_investor_share_token(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_revoke_referral_bounty(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_set_amc_tier(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_suspicious_attendance_recent(integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_tds_quarterly_summary(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_refund_authorization(uuid,text) TO authenticated;

-- ---------------------------------------------------------------------
-- 2. The one function whose authorisation was missing entirely.
--    Body is the original, verbatim, wrapped in plpgsql so the house gate
--    can raise before any row is computed. Original definition, for rollback:
--
--      CREATE OR REPLACE FUNCTION public.founder_payouts_dead_letter_summary()
--       RETURNS TABLE(category text, count_rows bigint, total_paise bigint,
--                     oldest_at timestamp with time zone)
--       LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
--      AS $f$ <the SELECT below, unchanged> $f$;
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_payouts_dead_letter_summary()
RETURNS TABLE(
  category    text,
  count_rows  bigint,
  total_paise bigint,
  oldest_at   timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Failed-payout amounts and provider failure reasons are founder-only; this
  -- function is SECURITY DEFINER, so without this check the grant below would
  -- hand them to every signed-in user.
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    CASE
      WHEN p.failure_reason LIKE 'reaper:%'
        THEN 'reaper_dead_letter'
      WHEN p.failure_reason ILIKE '%5xx%' OR p.failure_reason ILIKE '%cashfree 5%'
        THEN 'provider_5xx_stuck'
      WHEN p.failure_reason ILIKE '%invalid%' OR p.failure_reason ILIKE '%kyc%'
        THEN 'engineer_needs_fix'
      ELSE 'other'
    END AS category,
    count(*)::bigint AS count_rows,
    coalesce(sum(p.amount_paise), 0)::bigint AS total_paise,
    min(p.updated_at) AS oldest_at
  FROM public.engineer_payouts p
  WHERE p.status = 'failed'
  GROUP BY 1
  ORDER BY 2 DESC;
END;
$$;

COMMENT ON FUNCTION public.founder_payouts_dead_letter_summary() IS
  'Founder-only summary of dead-lettered engineer payouts, grouped by failure class. Gated on is_founder() because it is SECURITY DEFINER over engineer_payouts and the founder console calls it as `authenticated`.';

-- Supabase''s default privileges publish EXECUTE on a freshly created function
-- to PUBLIC, so revoke before granting the intended audience.
REVOKE ALL ON FUNCTION public.founder_payouts_dead_letter_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_payouts_dead_letter_summary() TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Close the unauthenticated write path
-- ---------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.founder_clv_snapshot_all_hospitals() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- VERIFY (inside the transaction; the non-founder probe is rolled back)
-- ---------------------------------------------------------------------
DO $verify$
DECLARE
  v_sig      text;
  v_oid      oid;
  v_granted  int := 0;
  v_rows     int;
  v_refused  boolean := false;
  v_sigs text[] := ARRAY[
    'approve_refund_authorization(uuid,text)',
    'engineer_sla_board(integer,integer)',
    'founder_certification_tier_distribution()',
    'founder_decide_dispute_pack(uuid,text,text)',
    'founder_dispute_queue(integer)',
    'founder_dpdp_grievances_list(text,integer,integer)',
    'founder_gst_summary(text,text)',
    'founder_kyc_renewal_queue(text,integer)',
    'founder_list_hospital_chains(text,integer)',
    'founder_list_investor_share_tokens(integer)',
    'founder_mint_investor_share_token(text,integer,integer)',
    'founder_open_duplicate_flags(text,integer)',
    'founder_pending_refund_authorizations(integer)',
    'founder_promote_engineer_tier(uuid,text,text)',
    'founder_reconciliation_anomalies_open(integer)',
    'founder_reconciliation_recent(integer)',
    'founder_referral_dashboard()',
    'founder_register_hospital_chain(text,uuid,text,text)',
    'founder_resolve_duplicate_flag(uuid,text,text)',
    'founder_resolve_grievance(uuid,text,text)',
    'founder_revoke_investor_share_token(uuid,text)',
    'founder_revoke_referral_bounty(uuid,text)',
    'founder_set_amc_tier(uuid,text,text)',
    'founder_suspicious_attendance_recent(integer,integer)',
    'founder_tds_quarterly_summary(text,text)',
    'reject_refund_authorization(uuid,text)'
  ];
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_oid := pg_catalog.to_regprocedure('public.' || v_sig);
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'round 3824 VERIFY FAILED: % still not executable by authenticated', v_sig;
    END IF;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'round 3824 VERIFY FAILED: % became anon-executable', v_sig;
    END IF;
    v_granted := v_granted + 1;
  END LOOP;
  IF v_granted <> 26 THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: verified % of 26 grants', v_granted;
  END IF;

  -- The re-created summary must be callable by authenticated, must REFUSE a
  -- non-founder caller, and must still answer for the founder.
  IF NOT has_function_privilege('authenticated', 'public.founder_payouts_dead_letter_summary()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: dead-letter summary not granted to authenticated';
  END IF;
  IF has_function_privilege('anon', 'public.founder_payouts_dead_letter_summary()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: dead-letter summary is anon-executable';
  END IF;

  -- is_founder() reads auth.email() out of request.jwt.claims, so a claims
  -- override exercises the real gate. Transaction-local; nothing persists.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-000000000001',
                      'role', 'authenticated',
                      'email', 'not-the-founder@example.invalid')::text, true);
  BEGIN
    PERFORM count(*) FROM public.founder_payouts_dead_letter_summary();
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: a non-founder got rows from the dead-letter summary';
  EXCEPTION
    WHEN SQLSTATE '42501' THEN
      v_refused := true;
  END;
  IF NOT v_refused THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: the non-founder probe never ran';
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', '756a3373-1077-470e-bc0a-79b8d6673ef4',
                      'role', 'authenticated',
                      'email', 'ganesh1431.dhanavath@gmail.com')::text, true);
  SELECT count(*) INTO v_rows FROM public.founder_payouts_dead_letter_summary();
  RAISE NOTICE 'round 3824: dead-letter summary refuses a non-founder and returns % row(s) for the founder', v_rows;
  PERFORM set_config('request.jwt.claims', NULL, true);

  -- And the unauthenticated write path is closed.
  IF has_function_privilege('anon', 'public.founder_clv_snapshot_all_hospitals()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.founder_clv_snapshot_all_hospitals()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: the snapshot writer is still reachable by a client role';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.founder_clv_snapshot_all_hospitals()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 3824 VERIFY FAILED: service_role lost the snapshot writer';
  END IF;

  RAISE NOTICE 'round 3824 verified: 26 console RPCs executable by authenticated, dead-letter summary gated, snapshot writer no longer client-reachable';
END;
$verify$;

COMMIT;
