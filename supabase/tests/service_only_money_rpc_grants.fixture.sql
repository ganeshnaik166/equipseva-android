-- Fixture for service_only_money_rpc_grants.test.mjs, applied after
-- engineer_location_privacy.fixture.sql (roles, auth.uid(), is_founder()).
--
-- 1. Reproduces the project's default privileges (round3791 records
--    `ALTER DEFAULT PRIVILEGES ... GRANT EXECUTE ON FUNCTIONS TO anon,
--    authenticated`), so functions created afterwards carry the same direct
--    grants production shows.
-- 2. Creates the three order tables the real round471 webhook functions
--    update (columns taken from round471's UPDATE statements).
-- 3. Creates signature-exact stand-ins for the other seven functions, each
--    recording its invocation in a canary table, followed by the same
--    `REVOKE ... FROM PUBLIC; GRANT ... TO service_role` their real
--    migrations ran. Their bodies are not under test; their grants are.

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

CREATE TABLE public.repair_job_escrow (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_order_id text,
  razorpay_payment_id text,
  status text,
  paid_at timestamptz,
  refunded_at timestamptz,
  updated_at timestamptz
);
CREATE TABLE public.spare_part_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_order_id text,
  payment_id text,
  payment_status text,
  order_status text,
  updated_at timestamptz
);
CREATE TABLE public.amc_payment_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_order_id text,
  razorpay_payment_id text,
  status text,
  paid_at timestamptz,
  updated_at timestamptz
);

CREATE TABLE public.service_rpc_canary (fn text, called_by text, at timestamptz DEFAULT now());

CREATE FUNCTION public.apply_amc_pool_credit(p_payment_order_id uuid) RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('apply_amc_pool_credit', current_user) RETURNING NULL::uuid $$;
REVOKE EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO service_role;

CREATE FUNCTION public.record_payment_verify_event(
  a text, b text, c text, d uuid, e text, f text, g boolean, h boolean, i bigint, j text, k text, l uuid, m jsonb
) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('record_payment_verify_event', current_user) $$;
REVOKE EXECUTE ON FUNCTION public.record_payment_verify_event(text,text,text,uuid,text,text,boolean,boolean,bigint,text,text,uuid,jsonb) FROM PUBLIC;

CREATE FUNCTION public.pick_engineer_payouts_for_processing(p_limit integer) RETURNS SETOF text
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('pick_engineer_payouts_for_processing', current_user) RETURNING 'bank-details' $$;
REVOKE EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(integer) FROM PUBLIC;

CREATE FUNCTION public.record_engineer_payout_dispatch(a uuid, b text, c text, d text, e text, f text, g text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('record_engineer_payout_dispatch', current_user) $$;
REVOKE EXECUTE ON FUNCTION public.record_engineer_payout_dispatch(uuid,text,text,text,text,text,text) FROM PUBLIC;

CREATE FUNCTION public.record_engineer_payout_webhook(a text, b text, c text, d text, e text, f text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('record_engineer_payout_webhook', current_user) $$;
REVOKE EXECUTE ON FUNCTION public.record_engineer_payout_webhook(text,text,text,text,text,text) FROM PUBLIC;

CREATE FUNCTION public.requeue_stuck_engineer_payouts(p_age interval, p_max integer) RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('requeue_stuck_engineer_payouts', current_user) RETURNING 0 $$;
REVOKE EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval,integer) FROM PUBLIC;

CREATE FUNCTION public.process_due_repair_job_escrow_releases() RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ INSERT INTO public.service_rpc_canary(fn, called_by) VALUES ('process_due_repair_job_escrow_releases', current_user) RETURNING 0 $$;
REVOKE EXECUTE ON FUNCTION public.process_due_repair_job_escrow_releases() FROM PUBLIC;

-- An owner-run internal caller, like process_amc_renewal_outcome (SECURITY
-- DEFINER, PERFORMs apply_amc_pool_credit). Must keep working after the fix.
CREATE FUNCTION public.internal_definer_caller(p_order uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ BEGIN PERFORM public.apply_amc_pool_credit(p_order); END $$;
REVOKE EXECUTE ON FUNCTION public.internal_definer_caller(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.internal_definer_caller(uuid) TO authenticated;
