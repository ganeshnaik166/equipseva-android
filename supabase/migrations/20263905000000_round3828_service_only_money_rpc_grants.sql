-- Round 3828 — service-only money RPCs were executable by anon and authenticated.
--
-- Found by the owner-directed security audit of 26 September 2026; verified
-- against the production catalog snapshot (supabase/regression baseline,
-- 2026-09-18) and each function's latest defining migration.
--
-- CRITICAL. The project's default privileges grant EXECUTE on new functions
-- directly to anon and authenticated (recorded in round3791). The migrations
-- that created these nine SECURITY DEFINER functions only ran
-- `REVOKE ... FROM PUBLIC; GRANT ... TO service_role`, which leaves those
-- direct grants in place. Production shows exec_anon = true and
-- exec_authenticated = true for all nine, and none of their bodies checks the
-- caller. Consequences, with nothing but the public anon key:
--   * record_razorpay_payment_captured — flips repair_job_escrow 'pending' ->
--     'held', spare_part_orders -> paid/confirmed and amc_payment_orders ->
--     'paid' for any known razorpay_order_id (the app receives that id during
--     checkout), with no payment captured;
--   * apply_amc_pool_credit — credits the AMC pool for a paid order and
--     activates the contract;
--   * record_razorpay_refund — flips a held or released escrow to 'refunded';
--   * record_payment_verify_event — writes forged verification telemetry;
--   * pick_engineer_payouts_for_processing — claims every queued payout
--     (status -> 'processing') and RETURNS each engineer's UPI VPA, bank
--     holder, bank, IFSC and stored account number;
--   * record_engineer_payout_dispatch / record_engineer_payout_webhook —
--     rewrite payout status, provider ids and the cached beneficiary id the
--     worker later sends money to;
--   * requeue_stuck_engineer_payouts / process_due_repair_job_escrow_releases
--     — run the reaper and escrow release with caller-chosen thresholds.
--
-- Their only legitimate callers use the service-role key (razorpay-webhook,
-- verify-amc-payment's admin client, payouts-webhook, process-engineer-payouts,
-- cron-tick, _shared/payment_verify_telemetry) or run as the owner (pg_cron;
-- process_amc_renewal_outcome, which is SECURITY DEFINER and PERFORMs
-- apply_amc_pool_credit). None is called from the Android app or the web
-- console. Revoking client EXECUTE therefore changes nothing for legitimate
-- callers.
--
-- Deliberately NOT in this list although the call-site scanner labels them
-- service-only: check_and_reserve_nabh_export, nabh_bundle_for_equipment
-- (export_nabh_bundle) and get_repair_invoice_payload (generate_repair_invoice)
-- are called through a client that forwards the CALLER's JWT, so they must
-- keep authenticated EXECUTE.
--
-- Root cause left for a separate, owner-approved change: the default
-- privileges themselves (`ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON
-- FUNCTIONS FROM anon, authenticated`) would make every future function
-- private until granted, which changes how all new client RPCs must be
-- written. Recorded in the handoff as a founder decision.
--
-- The trailing DO block re-checks the result and aborts the whole migration
-- if any of the nine is still client-executable or service_role lost access.
-- Proven locally by supabase/tests/service_only_money_rpc_grants.test.mjs
-- (PGlite, loading the real round471 webhook migration). Not applied to
-- production by this commit.
BEGIN;

REVOKE ALL ON FUNCTION public.record_razorpay_payment_captured(text, text, text, text, bigint, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_razorpay_refund(text, text, text, text, text, bigint, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_amc_pool_credit(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_payment_verify_event(text, text, text, uuid, text, text, boolean, boolean, bigint, text, text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pick_engineer_payouts_for_processing(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_engineer_payout_dispatch(uuid, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_engineer_payout_webhook(text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.requeue_stuck_engineer_payouts(interval, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.process_due_repair_job_escrow_releases() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.record_razorpay_payment_captured(text, text, text, text, bigint, text, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_razorpay_refund(text, text, text, text, text, bigint, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_payment_verify_event(text, text, text, uuid, text, text, boolean, boolean, bigint, text, text, uuid, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_engineer_payout_dispatch(uuid, text, text, text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_engineer_payout_webhook(text, text, text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.process_due_repair_job_escrow_releases() TO service_role;

DO $$
DECLARE
  v_sig text;
  v_bad text[] := ARRAY[]::text[];
BEGIN
  FOREACH v_sig IN ARRAY ARRAY[
    'public.record_razorpay_payment_captured(text,text,text,text,bigint,text,jsonb)',
    'public.record_razorpay_refund(text,text,text,text,text,bigint,jsonb)',
    'public.apply_amc_pool_credit(uuid)',
    'public.record_payment_verify_event(text,text,text,uuid,text,text,boolean,boolean,bigint,text,text,uuid,jsonb)',
    'public.pick_engineer_payouts_for_processing(integer)',
    'public.record_engineer_payout_dispatch(uuid,text,text,text,text,text,text)',
    'public.record_engineer_payout_webhook(text,text,text,text,text,text)',
    'public.requeue_stuck_engineer_payouts(interval,integer)',
    'public.process_due_repair_job_escrow_releases()'
  ] LOOP
    IF has_function_privilege('anon', v_sig, 'EXECUTE')
       OR has_function_privilege('authenticated', v_sig, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_sig, 'EXECUTE') THEN
      v_bad := v_bad || v_sig;
    END IF;
  END LOOP;
  IF array_length(v_bad, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'round3828: grants not as intended for %', v_bad USING ERRCODE = '42501';
  END IF;
END $$;

COMMIT;
