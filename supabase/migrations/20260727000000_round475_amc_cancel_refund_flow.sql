-- Round 475 — cancel_amc_contract refund-intent flow.
--
-- Closes audit-7 HIGH #7: when a hospital cancels an AMC contract
-- mid-period, the unspent balance in amc_payment_pool was silently
-- forfeited — no refund was queued, no ledger row reflected the
-- amount owed back, no ops dashboard surfaced the gap.
--
-- This round adds the RECORD side: cancel_amc_contract now computes
-- the remaining balance + stamps refund_owed_paise + refund_initiated_at
-- on the contract row. A founder ops view surfaces pending refunds
-- for manual Razorpay-dashboard processing.
--
-- Future round (when payout volume warrants): build dispatch-amc-refunds
-- edge fn + pg_cron schedule that drains the queue via the
-- _shared/razorpay_refund.ts helper from round 473.
--
-- For now (sole-prop low volume): founder triggers refund manually via
-- Razorpay dashboard after seeing the row in founder_amc_pending_refunds().
-- Once refunded, founder calls mark_amc_refund_dispatched() to close out.

-- ---------------------------------------------------------------------
-- 1. New columns on amc_contracts to track the refund lifecycle.
--
-- All nullable — only populated for contracts with refund intent.
-- ---------------------------------------------------------------------

ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS refund_owed_paise         bigint,
  ADD COLUMN IF NOT EXISTS refund_initiated_at       timestamptz,
  ADD COLUMN IF NOT EXISTS refund_dispatched_at      timestamptz,
  ADD COLUMN IF NOT EXISTS refund_razorpay_refund_id text,
  ADD COLUMN IF NOT EXISTS refund_failure_reason     text;

-- Sanity: refund_owed_paise must be positive when set.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'amc_contracts_refund_owed_positive'
  ) THEN
    ALTER TABLE public.amc_contracts
      ADD CONSTRAINT amc_contracts_refund_owed_positive
      CHECK (refund_owed_paise IS NULL OR refund_owed_paise > 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS amc_contracts_refund_pending_idx
  ON public.amc_contracts (refund_initiated_at)
  WHERE refund_owed_paise IS NOT NULL
    AND refund_dispatched_at IS NULL;

COMMENT ON COLUMN public.amc_contracts.refund_owed_paise IS
  'Round 475: when contract is cancelled with positive pool balance, the unspent paise are recorded here. NULL until cancel_amc_contract sees a positive balance. Cleared (NULL) is the no-refund-needed state.';
COMMENT ON COLUMN public.amc_contracts.refund_initiated_at IS
  'Round 475: when cancel_amc_contract recorded the refund intent. Pairs with refund_owed_paise.';
COMMENT ON COLUMN public.amc_contracts.refund_dispatched_at IS
  'Round 475: when mark_amc_refund_dispatched fired — the refund actually moved at Razorpay. NULL = still pending in founder triage queue.';

-- ---------------------------------------------------------------------
-- 2. Extend cancel_amc_contract to compute + record the refund intent.
--
-- Return-type changes from `void` (round 454) to `jsonb` so the caller
-- can see refund_owed_paise immediately. Postgres requires DROP before
-- CREATE on return-type change (CREATE OR REPLACE rejects it).
-- Android caller (AmcRepository.cancelContract) currently ignores the
-- response with `Unit` — non-breaking for clients.
-- ---------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.cancel_amc_contract(uuid, text);

CREATE FUNCTION public.cancel_amc_contract(
  p_contract_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller                    uuid := auth.uid();
  v_hospital_id               uuid;
  v_primary_engineer_user_id  uuid;
  v_current_status            text;
  v_balance                   numeric(10,2);
  v_refund_paise              bigint;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT c.hospital_user_id, e.user_id, c.status::text
    INTO v_hospital_id, v_primary_engineer_user_id, v_current_status
    FROM public.amc_contracts c
    JOIN public.engineers e ON e.id = c.primary_engineer_id
   WHERE c.id = p_contract_id;

  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = '42704';
  END IF;

  IF v_caller <> v_hospital_id
     AND v_caller IS DISTINCT FROM v_primary_engineer_user_id
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  IF v_current_status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'contract already in terminal state %', v_current_status
      USING ERRCODE = '22023';
  END IF;

  -- Round 475: compute remaining pool balance BEFORE flipping status to
  -- 'cancelled'. After flip, the round-474 contract-status gate on
  -- apply_amc_pool_credit would refuse to further credit, so the
  -- balance is locked at the moment of cancellation.
  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = p_contract_id;

  -- Convert to paise + clamp to positive. Negative balance means the
  -- pool was already in arrears (round-267 auto-pause path) and the
  -- hospital actually owes US money — no refund to issue. Zero
  -- balance also means nothing to refund.
  IF v_balance > 0 THEN
    v_refund_paise := (v_balance * 100)::bigint;
  ELSE
    v_refund_paise := NULL;
  END IF;

  UPDATE public.amc_contracts
     SET status = 'cancelled',
         auto_renew = false,
         updated_at = now(),
         refund_owed_paise = v_refund_paise,
         refund_initiated_at = CASE
           WHEN v_refund_paise IS NOT NULL THEN now()
           ELSE refund_initiated_at
         END,
         scope_text = CASE
           WHEN p_reason IS NULL OR p_reason = '' THEN scope_text
           ELSE coalesce(scope_text, '') ||
                E'\n[cancelled: ' || left(p_reason, 200) || ']'
         END
   WHERE id = p_contract_id
     AND status IN ('active','paused');

  -- Also record a ledger 'refund' row representing the intent. Amount
  -- is positive in the ledger (kind='refund' is sign-positive like
  -- credit). balance_after reflects the post-refund balance (should
  -- be 0 if v_refund_paise = balance * 100; ledger stays consistent
  -- with the audit trail even before the actual Razorpay refund fires).
  --
  -- We use 'refund' (valid per the CHECK in amc_payment_pool) with a
  -- source_payment_order_id = NULL because the refund is contract-
  -- scoped, not order-scoped (a contract may have many top-up orders;
  -- the refund collapses them).
  IF v_refund_paise IS NOT NULL THEN
    INSERT INTO public.amc_payment_pool (
      amc_contract_id, ledger_kind, amount_rupees, balance_after,
      source_payment_order_id, source_visit_id, description
    ) VALUES (
      p_contract_id, 'refund', v_balance, 0,
      NULL, NULL,
      'Cancellation refund intent (round 475) — ' || coalesce(p_reason, 'no reason given')
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'contract_id', p_contract_id,
    'refund_owed_paise', v_refund_paise,
    'refund_initiated', v_refund_paise IS NOT NULL
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.cancel_amc_contract(uuid, text) IS
  'Round 454 + round 475: cancels an AMC contract. Round 475 computes remaining pool balance and records refund intent (refund_owed_paise + refund_initiated_at on amc_contracts, plus a refund ledger row in amc_payment_pool). Returns jsonb with refund_owed_paise so the client can surface "refund pending" to the hospital. Actual Razorpay refund execution is currently manual (founder via dashboard, then mark_amc_refund_dispatched) — automated dispatcher deferred until payout volume warrants.';

-- ---------------------------------------------------------------------
-- 3. mark_amc_refund_dispatched — service_role-only RPC that the
-- (future) dispatcher OR founder ops tool calls after the Razorpay
-- refund POST returns ok.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_amc_refund_dispatched(
  p_contract_id           uuid,
  p_razorpay_refund_id    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_existing_dispatched timestamptz;
  v_refund_owed         bigint;
BEGIN
  SELECT refund_dispatched_at, refund_owed_paise
    INTO v_existing_dispatched, v_refund_owed
    FROM public.amc_contracts
    WHERE id = p_contract_id
    FOR UPDATE;

  IF v_refund_owed IS NULL THEN
    RAISE EXCEPTION 'contract % has no pending refund', p_contract_id
      USING ERRCODE = '22023';
  END IF;

  IF v_existing_dispatched IS NOT NULL THEN
    -- Idempotent: already marked dispatched. Return the existing state.
    RETURN jsonb_build_object(
      'ok', true,
      'idempotent', true,
      'dispatched_at', v_existing_dispatched
    );
  END IF;

  UPDATE public.amc_contracts
     SET refund_dispatched_at = now(),
         refund_razorpay_refund_id = p_razorpay_refund_id,
         refund_failure_reason = NULL,
         updated_at = now()
   WHERE id = p_contract_id;

  RETURN jsonb_build_object(
    'ok', true,
    'idempotent', false,
    'dispatched_at', now()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_amc_refund_dispatched(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_amc_refund_dispatched(uuid, text) TO service_role;

COMMENT ON FUNCTION public.mark_amc_refund_dispatched(uuid, text) IS
  'Round 475: marks an AMC contract refund as dispatched after Razorpay refund POST succeeds. service_role-only. Idempotent on re-call. The future dispatch-amc-refunds edge fn or founder ops tool calls this.';

-- ---------------------------------------------------------------------
-- 4. mark_amc_refund_failed — log a failed refund attempt without
-- clearing the pending state (so retry remains possible).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_amc_refund_failed(
  p_contract_id  uuid,
  p_reason       text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_reason IS NULL OR p_reason = '' THEN
    RAISE EXCEPTION 'reason is required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.amc_contracts
     SET refund_failure_reason = left(p_reason, 1000),
         updated_at = now()
   WHERE id = p_contract_id
     AND refund_owed_paise IS NOT NULL
     AND refund_dispatched_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'contract % has no pending refund to fail', p_contract_id
      USING ERRCODE = '22023';
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_amc_refund_failed(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_amc_refund_failed(uuid, text) TO service_role;

-- ---------------------------------------------------------------------
-- 5. founder_amc_pending_refunds — ops view (founder-gated).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_amc_pending_refunds()
RETURNS TABLE (
  contract_id                 uuid,
  hospital_user_id            uuid,
  refund_owed_paise           bigint,
  refund_owed_rupees          numeric(10,2),
  refund_initiated_at         timestamptz,
  hours_pending               numeric(10,2),
  refund_failure_reason       text,
  latest_razorpay_payment_id  text,
  latest_razorpay_order_id    text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- Round 475: is_founder() gate inside the body so SECURITY DEFINER +
  -- GRANT to authenticated cannot leak hospital identifiers to non-
  -- founder users (same pattern as round 473's founder_razorpay_*).
  SELECT
    c.id AS contract_id,
    c.hospital_user_id,
    c.refund_owed_paise,
    (c.refund_owed_paise / 100.0)::numeric(10,2) AS refund_owed_rupees,
    c.refund_initiated_at,
    EXTRACT(EPOCH FROM (now() - c.refund_initiated_at)) / 3600 AS hours_pending,
    c.refund_failure_reason,
    -- Surface the most-recent paid Razorpay payment id so the founder
    -- can paste it directly into the Razorpay dashboard refund flow.
    (SELECT razorpay_payment_id
       FROM public.amc_payment_orders
       WHERE amc_contract_id = c.id AND status = 'paid'
       ORDER BY updated_at DESC LIMIT 1) AS latest_razorpay_payment_id,
    (SELECT razorpay_order_id
       FROM public.amc_payment_orders
       WHERE amc_contract_id = c.id AND status = 'paid'
       ORDER BY updated_at DESC LIMIT 1) AS latest_razorpay_order_id
    FROM public.amc_contracts c
    WHERE public.is_founder()
      AND c.refund_owed_paise IS NOT NULL
      AND c.refund_dispatched_at IS NULL
    ORDER BY c.refund_initiated_at ASC NULLS LAST;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_pending_refunds()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pending_refunds()
  TO authenticated;

COMMENT ON FUNCTION public.founder_amc_pending_refunds() IS
  'Round 475: founder dashboard — AMC contracts with pending cancellation refunds (refund_owed_paise set, refund_dispatched_at NULL). Surfaces the most-recent Razorpay payment_id so the founder can paste directly into the Razorpay dashboard refund flow. Then call mark_amc_refund_dispatched to close out.';
