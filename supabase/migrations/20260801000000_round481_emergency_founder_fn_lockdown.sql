-- =====================================================================
-- Round 481 — EMERGENCY — founder/admin SECDEF function lockdown
-- =====================================================================
--
-- Audit-10 surfaced a CRITICAL exposure: 7 SECURITY DEFINER functions in
-- the founder/admin namespace lacked is_founder() gates AND were
-- callable by `anon` and/or `authenticated` PostgREST roles due to
-- Supabase's default GRANTs on the public schema.
--
-- The 3 mutators are the worst — they were intended to be Razorpay
-- webhook callbacks invoked with service_role, but Postgres' default
-- behavior layered a "GRANT EXECUTE TO anon" on top of the explicit
-- "GRANT TO service_role" in round 418. The original migration's
-- REVOKE FROM PUBLIC did NOT remove the per-role default grants —
-- same Supabase gotcha as round 467 (column REVOKE inert under
-- table grant).
--
-- Verified against prod via `has_function_privilege('anon', ...)`:
--
--   admin_record_amc_subscription_charge   anon=true authenticated=true  ← CRITICAL: credits AMC pool
--   admin_record_amc_subscription_failure  anon=true authenticated=true  ← CRITICAL: writes failure rows
--   admin_update_amc_subscription_state    anon=true authenticated=true  ← CRITICAL: flips status
--   founder_razorpay_binding_health        anon=false authenticated=true ← HIGH: leaks ops metrics
--   founder_payment_verify_failures        anon=false authenticated=true ← HIGH: leaks verify-event log
--   founder_engineer_payouts_no_method_summary  anon=false authenticated=true ← HIGH
--   founder_payouts_dead_letter_summary    anon=false authenticated=true ← HIGH
--
-- The exploit on the mutators: ANY caller (no auth required!) could POST
-- to /rest/v1/rpc/admin_record_amc_subscription_charge with a victim's
-- subscription_id + a fake razorpay_payment_id + an arbitrary amount,
-- and the function would CREDIT THE AMC POOL with fake money. The
-- UNIQUE constraint on razorpay_payment_id only prevents replaying
-- the same fake id — generating new fake ids is trivial.
--
-- Fix (two-layer defense):
--   1. REVOKE EXECUTE FROM anon, authenticated on all 7 functions.
--   2. Add `IF NOT public.is_founder() THEN RAISE EXCEPTION` to the
--      4 founder_* read-only functions for the case where the webhook
--      path would otherwise need to keep calling them. The 3 admin_*
--      mutators KEEP their no-auth-gate body (they're webhook handlers,
--      service_role bypasses RLS + is_founder()) — only the grant
--      change locks them down.
--
-- Verification queries below the migration confirm post-state.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. CRITICAL mutators — webhook-only, lock to service_role
-- ---------------------------------------------------------------------
-- These 3 functions implement Razorpay subscription-charge webhook
-- handling: they credit the AMC pool + flip subscription state. The
-- Razorpay-webhook edge function calls them with service_role. No
-- user-facing flow ever needs to invoke them directly.

REVOKE EXECUTE ON FUNCTION public.admin_record_amc_subscription_charge(
  uuid, text, text, numeric, timestamptz, timestamptz
) FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_record_amc_subscription_failure(
  uuid, text, numeric, timestamptz, timestamptz, text
) FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_update_amc_subscription_state(
  uuid, text, text, text, text, timestamptz, timestamptz, timestamptz, text
) FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. HIGH read-only founders — add is_founder() gate + revoke
-- ---------------------------------------------------------------------
-- These leak operational metrics (pending payment counts, verify
-- failure logs, payout dead-letter summaries). Belt-and-braces:
-- revoke the role AND add the body gate so a future GRANT regression
-- doesn't re-open the hole.

-- 2a. founder_razorpay_binding_health — add gate + revoke
CREATE OR REPLACE FUNCTION public.founder_razorpay_binding_health()
RETURNS TABLE(
  table_name           text,
  duplicate_count      bigint,
  null_binding_count   bigint,
  oldest_null_at       timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT 'spare_part_orders'::text,
    (SELECT count(*) FROM (
      SELECT razorpay_order_id FROM public.spare_part_orders
       WHERE razorpay_order_id IS NOT NULL
       GROUP BY razorpay_order_id HAVING count(*) > 1
    ) x)::bigint,
    (SELECT count(*) FROM public.spare_part_orders WHERE razorpay_order_id IS NULL AND payment_status='pending')::bigint,
    (SELECT min(created_at) FROM public.spare_part_orders WHERE razorpay_order_id IS NULL AND payment_status='pending')
  UNION ALL
  SELECT 'repair_job_escrow'::text,
    (SELECT count(*) FROM (
      SELECT razorpay_order_id FROM public.repair_job_escrow
       WHERE razorpay_order_id IS NOT NULL
       GROUP BY razorpay_order_id HAVING count(*) > 1
    ) x)::bigint,
    (SELECT count(*) FROM public.repair_job_escrow WHERE razorpay_order_id IS NULL AND status='pending')::bigint,
    (SELECT min(created_at) FROM public.repair_job_escrow WHERE razorpay_order_id IS NULL AND status='pending')
  UNION ALL
  SELECT 'amc_payment_orders'::text,
    (SELECT count(*) FROM (
      SELECT razorpay_order_id FROM public.amc_payment_orders
       WHERE razorpay_order_id IS NOT NULL
       GROUP BY razorpay_order_id HAVING count(*) > 1
    ) x)::bigint,
    (SELECT count(*) FROM public.amc_payment_orders WHERE razorpay_order_id IS NULL AND status='pending')::bigint,
    (SELECT min(created_at) FROM public.amc_payment_orders WHERE razorpay_order_id IS NULL AND status='pending');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_binding_health() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_binding_health() TO service_role;

-- 2b. founder_payment_verify_failures — add gate + revoke
CREATE OR REPLACE FUNCTION public.founder_payment_verify_failures(
  p_since timestamptz DEFAULT (now() - interval '7 days')
)
RETURNS TABLE(
  event_id              uuid,
  occurred_at           timestamptz,
  verify_fn             text,
  order_kind            text,
  order_id              uuid,
  razorpay_order_id     text,
  razorpay_payment_id   text,
  outcome               text,
  error_code            text,
  error_message         text,
  amount_paise          bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT id, occurred_at, verify_fn, order_kind, order_id,
         razorpay_order_id, razorpay_payment_id, outcome,
         error_code, error_message, amount_paise
    FROM public.payment_verify_events
   WHERE occurred_at >= p_since
     AND outcome NOT IN ('success','idempotent_success')
   ORDER BY occurred_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_payment_verify_failures(timestamptz) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_payment_verify_failures(timestamptz) TO service_role;

-- 2c. founder_engineer_payouts_no_method_summary — revoke (body untouched, just lock role)
-- 2d. founder_payouts_dead_letter_summary — revoke

-- Both of these are reports the founder UI calls. They lack is_founder()
-- but the simpler fix is REVOKE FROM authenticated — the founder UI
-- talks via service_role-impersonated requests when needed, OR we can
-- patch the founder UI to talk via founder-gated wrapper. For this
-- emergency hotfix we go with the REVOKE; subsequent rounds may
-- re-introduce a gated wrapper.

DO $$
DECLARE
  v_oid oid;
BEGIN
  -- founder_engineer_payouts_no_method_summary
  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace
       AND p.proname = 'founder_engineer_payouts_no_method_summary'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated;', v_oid::regprocedure);
    EXECUTE format('GRANT  EXECUTE ON FUNCTION %s TO service_role;', v_oid::regprocedure);
  END LOOP;
  -- founder_payouts_dead_letter_summary
  FOR v_oid IN
    SELECT p.oid FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace
       AND p.proname = 'founder_payouts_dead_letter_summary'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated;', v_oid::regprocedure);
    EXECUTE format('GRANT  EXECUTE ON FUNCTION %s TO service_role;', v_oid::regprocedure);
  END LOOP;
END;
$$;

COMMIT;

-- ---------------------------------------------------------------------
-- 3. Post-condition assertions
-- ---------------------------------------------------------------------
-- These RAISE on regression — a botched re-apply (or future migration
-- that re-grants) is caught at deploy time rather than in production.

DO $$
DECLARE
  v_proname text;
BEGIN
  FOREACH v_proname IN ARRAY ARRAY[
    'admin_record_amc_subscription_charge',
    'admin_record_amc_subscription_failure',
    'admin_update_amc_subscription_state',
    'founder_razorpay_binding_health',
    'founder_payment_verify_failures',
    'founder_engineer_payouts_no_method_summary',
    'founder_payouts_dead_letter_summary'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_proc p
       WHERE p.pronamespace = 'public'::regnamespace
         AND p.proname = v_proname
         AND (
           has_function_privilege('anon', p.oid, 'execute') OR
           has_function_privilege('authenticated', p.oid, 'execute')
         )
    ) THEN
      RAISE EXCEPTION 'round 481 regression: % is still callable by anon or authenticated', v_proname;
    END IF;
  END LOOP;
  RAISE NOTICE 'round 481 lockdown verified: all 7 functions service_role-only';
END;
$$;
