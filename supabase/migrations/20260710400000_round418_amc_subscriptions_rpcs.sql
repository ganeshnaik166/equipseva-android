-- Round 418 — AMC auto-charge phase 2: RPCs.
--
-- Builds on r417's schema. Adds:
--   * Hospital-callable setup + cancel RPCs.
--   * SECDEF RPCs for the (forthcoming) razorpay-subscription-webhook
--     edge fn to record state transitions + charge outcomes.
--   * Read-side list RPCs for hospital + engineer + admin.
--
-- The edge fn that actually calls Razorpay /subscriptions is r419+. This
-- phase wires the server-side state machine so the edge fn has somewhere
-- to write outcomes when it lands.

-- =====================================================================
-- request_amc_subscription_setup — hospital opts in
-- =====================================================================
-- Idempotent: re-calling for a contract that already has an in-flight
-- subscription returns the existing row id.
CREATE OR REPLACE FUNCTION public.request_amc_subscription_setup(
  p_amc_contract_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_contract record;
  v_existing uuid;
  v_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  -- Hospital-only — engineer / admin can read but not request setup.
  SELECT id, hospital_user_id, status, monthly_fee_rupees
    INTO v_contract
    FROM public.amc_contracts
    WHERE id = p_amc_contract_id;

  IF v_contract.id IS NULL THEN
    RAISE EXCEPTION 'amc contract not found' USING ERRCODE = '02000';
  END IF;
  IF v_contract.hospital_user_id <> v_caller THEN
    RAISE EXCEPTION 'only the contract hospital can set up auto-pay' USING ERRCODE = '42501';
  END IF;
  IF v_contract.status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'contract not eligible (status %)', v_contract.status
      USING ERRCODE = '22023';
  END IF;
  IF v_contract.monthly_fee_rupees IS NULL OR v_contract.monthly_fee_rupees <= 0 THEN
    RAISE EXCEPTION 'contract has no monthly fee' USING ERRCODE = '22023';
  END IF;

  -- Idempotency: re-use an in-flight pending/authenticated/active/paused row.
  SELECT id INTO v_existing
    FROM public.amc_subscriptions
    WHERE amc_contract_id = p_amc_contract_id
      AND status IN ('pending','authenticated','active','paused')
    LIMIT 1;
  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  INSERT INTO public.amc_subscriptions (amc_contract_id, status, created_by)
  VALUES (p_amc_contract_id, 'pending', v_caller)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.request_amc_subscription_setup(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.request_amc_subscription_setup(uuid) TO authenticated;

-- =====================================================================
-- cancel_amc_subscription — hospital opts out
-- =====================================================================
CREATE OR REPLACE FUNCTION public.cancel_amc_subscription(
  p_subscription_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_sub record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT s.id, s.status, s.amc_contract_id, c.hospital_user_id
    INTO v_sub
    FROM public.amc_subscriptions s
    JOIN public.amc_contracts c ON c.id = s.amc_contract_id
    WHERE s.id = p_subscription_id
    FOR UPDATE;

  IF v_sub.id IS NULL THEN
    RAISE EXCEPTION 'subscription not found' USING ERRCODE = '02000';
  END IF;
  IF v_sub.hospital_user_id <> v_caller
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF v_sub.status IN ('cancelled','completed','expired') THEN
    -- Already terminal; idempotent no-op.
    RETURN;
  END IF;

  UPDATE public.amc_subscriptions
     SET status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = v_caller,
         next_charge_at = NULL
   WHERE id = p_subscription_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cancel_amc_subscription(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.cancel_amc_subscription(uuid) TO authenticated;

-- =====================================================================
-- admin_update_amc_subscription_state — webhook state transitions
-- =====================================================================
-- Called by the (forthcoming) razorpay-subscription-webhook edge fn when
-- it receives a subscription.activated / paused / halted / completed
-- event. Service-role only.
CREATE OR REPLACE FUNCTION public.admin_update_amc_subscription_state(
  p_subscription_id uuid,
  p_status text,
  p_razorpay_subscription_id text DEFAULT NULL,
  p_razorpay_plan_id text DEFAULT NULL,
  p_razorpay_customer_id text DEFAULT NULL,
  p_current_period_start timestamptz DEFAULT NULL,
  p_current_period_end timestamptz DEFAULT NULL,
  p_next_charge_at timestamptz DEFAULT NULL,
  p_mandate_summary text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_status NOT IN ('pending','authenticated','active','paused','cancelled','completed','halted','expired') THEN
    RAISE EXCEPTION 'invalid status %', p_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.amc_subscriptions
     SET status = p_status,
         razorpay_subscription_id =
           coalesce(p_razorpay_subscription_id, razorpay_subscription_id),
         razorpay_plan_id =
           coalesce(p_razorpay_plan_id, razorpay_plan_id),
         razorpay_customer_id =
           coalesce(p_razorpay_customer_id, razorpay_customer_id),
         current_period_start =
           coalesce(p_current_period_start, current_period_start),
         current_period_end =
           coalesce(p_current_period_end, current_period_end),
         next_charge_at =
           CASE WHEN p_status IN ('cancelled','completed','expired','halted')
                THEN NULL
                ELSE coalesce(p_next_charge_at, next_charge_at) END,
         mandate_summary =
           coalesce(p_mandate_summary, mandate_summary)
   WHERE id = p_subscription_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'subscription % not found', p_subscription_id
      USING ERRCODE = '02000';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_update_amc_subscription_state(
  uuid, text, text, text, text, timestamptz, timestamptz, timestamptz, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_update_amc_subscription_state(
  uuid, text, text, text, text, timestamptz, timestamptz, timestamptz, text
) TO service_role;

-- =====================================================================
-- admin_record_amc_subscription_charge — webhook charge recording
-- =====================================================================
-- Atomic: records the charge row + credits amc_payment_pool + bumps
-- counters on the subscription. Idempotent on razorpay_payment_id so
-- a webhook retry doesn't double-credit.
CREATE OR REPLACE FUNCTION public.admin_record_amc_subscription_charge(
  p_subscription_id uuid,
  p_razorpay_payment_id text,
  p_razorpay_invoice_id text,
  p_amount_rupees numeric,
  p_period_start timestamptz,
  p_period_end timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sub record;
  v_existing_charge uuid;
  v_charge_id uuid;
  v_balance numeric(10,2);
  v_pool_ledger_id uuid;
BEGIN
  IF p_razorpay_payment_id IS NULL OR length(p_razorpay_payment_id) = 0 THEN
    RAISE EXCEPTION 'razorpay_payment_id required' USING ERRCODE = '22023';
  END IF;
  IF p_amount_rupees <= 0 THEN
    RAISE EXCEPTION 'amount must be positive' USING ERRCODE = '22023';
  END IF;

  -- Lock the subscription row so concurrent webhook deliveries serialize.
  SELECT id, amc_contract_id, total_charges_succeeded
    INTO v_sub
    FROM public.amc_subscriptions
    WHERE id = p_subscription_id
    FOR UPDATE;

  IF v_sub.id IS NULL THEN
    RAISE EXCEPTION 'subscription % not found', p_subscription_id
      USING ERRCODE = '02000';
  END IF;

  -- Idempotency: if a charge row already exists for this razorpay_payment_id,
  -- return its id (no double-credit). The UNIQUE constraint on
  -- razorpay_payment_id is the hard guard.
  SELECT id INTO v_existing_charge
    FROM public.amc_subscription_charges
    WHERE razorpay_payment_id = p_razorpay_payment_id
    LIMIT 1;
  IF v_existing_charge IS NOT NULL THEN
    RETURN v_existing_charge;
  END IF;

  -- Compute running balance the same way apply_amc_pool_credit does.
  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       + p_amount_rupees
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = v_sub.amc_contract_id;

  -- Credit the pool.
  INSERT INTO public.amc_payment_pool (
    amc_contract_id, ledger_kind, amount_rupees, balance_after,
    description
  ) VALUES (
    v_sub.amc_contract_id, 'credit', p_amount_rupees, v_balance,
    'Auto-debit ' || coalesce(p_razorpay_payment_id, 'unknown')
  ) RETURNING id INTO v_pool_ledger_id;

  -- Record the charge.
  INSERT INTO public.amc_subscription_charges (
    subscription_id, amc_contract_id, razorpay_payment_id,
    razorpay_invoice_id, amount_rupees, status,
    period_start, period_end, pool_ledger_id, settled_at
  ) VALUES (
    p_subscription_id, v_sub.amc_contract_id, p_razorpay_payment_id,
    p_razorpay_invoice_id, p_amount_rupees, 'succeeded',
    p_period_start, p_period_end, v_pool_ledger_id, now()
  ) RETURNING id INTO v_charge_id;

  -- Bump subscription counters + clear any prior failure.
  UPDATE public.amc_subscriptions
     SET last_charged_at = now(),
         total_charges_succeeded = total_charges_succeeded + 1,
         last_failure_reason = NULL,
         last_failure_at = NULL,
         current_period_start = p_period_start,
         current_period_end = p_period_end
   WHERE id = p_subscription_id;

  -- A new credit may bring a paused contract back to life (matches
  -- apply_amc_pool_credit's behavior).
  UPDATE public.amc_contracts
     SET status = 'active', updated_at = now()
   WHERE id = v_sub.amc_contract_id AND status = 'paused';

  RETURN v_charge_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_record_amc_subscription_charge(
  uuid, text, text, numeric, timestamptz, timestamptz
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_record_amc_subscription_charge(
  uuid, text, text, numeric, timestamptz, timestamptz
) TO service_role;

-- =====================================================================
-- admin_record_amc_subscription_failure — webhook failure recording
-- =====================================================================
CREATE OR REPLACE FUNCTION public.admin_record_amc_subscription_failure(
  p_subscription_id uuid,
  p_razorpay_payment_id text,
  p_amount_rupees numeric,
  p_period_start timestamptz,
  p_period_end timestamptz,
  p_failure_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sub record;
  v_existing_charge uuid;
  v_charge_id uuid;
  v_reason text;
BEGIN
  v_reason := coalesce(left(p_failure_reason, 500), 'unspecified');

  SELECT id, amc_contract_id
    INTO v_sub
    FROM public.amc_subscriptions
    WHERE id = p_subscription_id
    FOR UPDATE;

  IF v_sub.id IS NULL THEN
    RAISE EXCEPTION 'subscription % not found', p_subscription_id
      USING ERRCODE = '02000';
  END IF;

  -- Idempotency on razorpay_payment_id (when present). NULL means
  -- attempted-but-not-yet-issued (rare); we still record a row for ops.
  IF p_razorpay_payment_id IS NOT NULL THEN
    SELECT id INTO v_existing_charge
      FROM public.amc_subscription_charges
      WHERE razorpay_payment_id = p_razorpay_payment_id
      LIMIT 1;
    IF v_existing_charge IS NOT NULL THEN
      RETURN v_existing_charge;
    END IF;
  END IF;

  INSERT INTO public.amc_subscription_charges (
    subscription_id, amc_contract_id, razorpay_payment_id,
    amount_rupees, status,
    period_start, period_end, failure_reason
  ) VALUES (
    p_subscription_id, v_sub.amc_contract_id, p_razorpay_payment_id,
    p_amount_rupees, 'failed',
    p_period_start, p_period_end, v_reason
  ) RETURNING id INTO v_charge_id;

  UPDATE public.amc_subscriptions
     SET total_charges_failed = total_charges_failed + 1,
         last_failure_reason = v_reason,
         last_failure_at = now()
   WHERE id = p_subscription_id;

  RETURN v_charge_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_record_amc_subscription_failure(
  uuid, text, numeric, timestamptz, timestamptz, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_record_amc_subscription_failure(
  uuid, text, numeric, timestamptz, timestamptz, text
) TO service_role;

-- =====================================================================
-- get_amc_subscription_for_contract — read-side for hospital UI
-- =====================================================================
-- RLS-aware: returns NULL when the caller isn't authorized to see the
-- subscription (matches v2.1 amc_subscriptions RLS).
CREATE OR REPLACE FUNCTION public.get_amc_subscription_for_contract(
  p_amc_contract_id uuid
)
RETURNS TABLE (
  id uuid,
  status text,
  razorpay_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  next_charge_at timestamptz,
  last_charged_at timestamptz,
  total_charges_succeeded int,
  total_charges_failed int,
  mandate_summary text,
  last_failure_reason text,
  last_failure_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  -- security_invoker so the caller's RLS policies on amc_subscriptions
  -- apply transparently. Hospital owns the contract → sees row; engineer
  -- party → sees row; otherwise empty.
  SELECT s.id, s.status, s.razorpay_subscription_id,
         s.current_period_start, s.current_period_end, s.next_charge_at,
         s.last_charged_at, s.total_charges_succeeded, s.total_charges_failed,
         s.mandate_summary, s.last_failure_reason, s.last_failure_at
    FROM public.amc_subscriptions s
   WHERE s.amc_contract_id = p_amc_contract_id
   ORDER BY s.created_at DESC
   LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_amc_subscription_for_contract(uuid) TO authenticated;

-- =====================================================================
-- list_amc_subscription_charges_for_contract — charge ledger read
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_amc_subscription_charges_for_contract(
  p_amc_contract_id uuid,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  razorpay_payment_id text,
  amount_rupees numeric,
  status text,
  period_start timestamptz,
  period_end timestamptz,
  failure_reason text,
  attempted_at timestamptz,
  settled_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT id, razorpay_payment_id, amount_rupees, status,
         period_start, period_end, failure_reason, attempted_at, settled_at
    FROM public.amc_subscription_charges
   WHERE amc_contract_id = p_amc_contract_id
   ORDER BY attempted_at DESC
   LIMIT greatest(1, least(p_limit, 200));
$$;
GRANT EXECUTE ON FUNCTION public.list_amc_subscription_charges_for_contract(uuid, int) TO authenticated;
