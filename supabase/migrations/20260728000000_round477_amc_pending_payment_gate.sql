-- Round 477 — audit-7 HIGH #1 — AMC contract payment-first gate.
--
-- Closes the final audit-7 HIGH: create_amc_contract previously set
-- status='active' immediately, no payment required. Combined with
-- auto_create_due_amc_visits + the per-visit debit trigger, a hospital
-- could create a contract, have engineers complete maintenance visits,
-- and never pay — engineer paid by EquipSeva for service to a contract
-- that never paid us (Free Service Attack).
--
-- THE FIX:
--   1. New status value 'pending_payment' added to amc_contracts.status CHECK
--   2. create_amc_contract now sets status='pending_payment' on creation
--      (was 'active'). auto_create_due_amc_visits already filters
--      WHERE status='active' so pending_payment contracts NEVER trigger
--      visit creation.
--   3. apply_amc_pool_credit promotes 'pending_payment' → 'active' on
--      first verified pool credit (extends round 474 status gate).
--   4. New reaper cron job cancels stranded 'pending_payment' contracts
--      older than 24h (user abandons mid-payment → contract auto-cleaned).
--
-- ANDROID CLIENT CHANGE (deferred to separate PR / v0.3.6):
--   The Android client must call create_amc_contract → get contract_id →
--   immediately invoke create-amc-payment-order → Razorpay → verify-amc-payment
--   (which calls apply_amc_pool_credit and promotes the contract). Old
--   v0.3.5 clients that don't pay will leave contracts in pending_payment;
--   the reaper cleans them up after 24h.
--
-- ROLLOUT:
--   - This migration is ADDITIVE — adds a new enum value + tightens RPC.
--   - Existing 'active' contracts are unaffected.
--   - Existing fallback-engineer validation from round 301 PRESERVED.
--   - Backfill: any 'active' contracts with zero pool balance + zero paid
--     orders are grandfathered (don't retro-flip). New contracts onwards
--     get the gate.

-- ---------------------------------------------------------------------
-- 1. Add 'pending_payment' to amc_contracts.status CHECK constraint.
-- ---------------------------------------------------------------------

ALTER TABLE public.amc_contracts
  DROP CONSTRAINT IF EXISTS amc_contracts_status_check;

ALTER TABLE public.amc_contracts
  ADD CONSTRAINT amc_contracts_status_check
    CHECK (status IN (
      'pending_payment',
      'active',
      'paused',
      'expired',
      'cancelled',
      'renewal_failed'
    ));

COMMENT ON COLUMN public.amc_contracts.status IS
  'AMC contract status. pending_payment = created but awaiting first verified pool credit (round 477 gate); active = paying / in-service; paused = pool exhausted, awaiting top-up; expired = end_date reached; cancelled = explicit cancel_amc_contract or reaper sweep of stranded pending_payment; renewal_failed = auto-renew payment failed.';

-- ---------------------------------------------------------------------
-- 2. create_amc_contract — initial status='pending_payment' (was 'active').
--
-- All other logic from round 301 preserved: input caps, primary engineer
-- verified check, fallback engineer verified check, rotation seeding.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_amc_contract(
  p_primary_engineer_id uuid,
  p_visit_frequency text,
  p_visits_per_year int,
  p_monthly_fee_rupees numeric,
  p_start_date date,
  p_end_date date,
  p_equipment_categories text[],
  p_scope_text text DEFAULT NULL,
  p_response_time_emergency_hours int DEFAULT 4,
  p_response_time_standard_hours int DEFAULT 24,
  p_auto_renew boolean DEFAULT true,
  p_renewal_term_months int DEFAULT 12,
  p_fallback_engineer_ids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_contract_id uuid;
  v_engineer_verified boolean;
  v_fallback_id uuid;
  v_fallback_verified boolean;
  v_priority int := 2;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  -- Round 301: cap array inputs.
  IF coalesce(array_length(p_equipment_categories, 1), 0) > 32 THEN
    RAISE EXCEPTION 'too many equipment_categories (max 32)' USING ERRCODE = '22023';
  END IF;
  IF coalesce(array_length(p_fallback_engineer_ids, 1), 0) > 32 THEN
    RAISE EXCEPTION 'too many fallback_engineer_ids (max 32)' USING ERRCODE = '22023';
  END IF;

  -- Round 301: primary engineer must be a verified engineers row.
  SELECT (verification_status::text = 'verified') INTO v_engineer_verified
    FROM public.engineers WHERE id = p_primary_engineer_id;
  IF v_engineer_verified IS NULL OR NOT v_engineer_verified THEN
    RAISE EXCEPTION 'primary_engineer must be verified' USING ERRCODE = '22023';
  END IF;

  -- Round 477 — audit-7 HIGH #1 — contract starts in 'pending_payment'
  -- instead of 'active'. auto_create_due_amc_visits filters WHERE
  -- status='active' so no maintenance visits are created until the
  -- first verified pool credit promotes this row (via
  -- apply_amc_pool_credit). The reaper cron sweeps stranded
  -- pending_payment contracts older than 24h to 'cancelled'.
  --
  -- next_visit_at is still set so that the moment payment promotes the
  -- contract to 'active', the cron can immediately pick it up (no
  -- additional update needed at promote time).
  INSERT INTO public.amc_contracts (
    hospital_user_id, primary_engineer_id, status,
    visit_frequency, visits_per_year, monthly_fee_rupees,
    start_date, end_date,
    scope_text, equipment_categories,
    next_visit_at,
    response_time_emergency_hours, response_time_standard_hours,
    auto_renew, renewal_term_months
  ) VALUES (
    v_caller_id, p_primary_engineer_id, 'pending_payment',
    p_visit_frequency, p_visits_per_year, p_monthly_fee_rupees,
    p_start_date, p_end_date,
    p_scope_text, coalesce(p_equipment_categories, ARRAY[]::text[]),
    p_start_date::timestamptz + interval '12 hours',
    p_response_time_emergency_hours, p_response_time_standard_hours,
    p_auto_renew, p_renewal_term_months
  ) RETURNING id INTO v_contract_id;

  INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
  VALUES (v_contract_id, p_primary_engineer_id, 1, true);

  -- Round 301: fallback engineer verification (preserved from r301).
  IF p_fallback_engineer_ids IS NOT NULL THEN
    FOREACH v_fallback_id IN ARRAY p_fallback_engineer_ids LOOP
      IF v_fallback_id IS NOT NULL AND v_fallback_id <> p_primary_engineer_id THEN
        SELECT (verification_status::text = 'verified') INTO v_fallback_verified
          FROM public.engineers WHERE id = v_fallback_id;
        IF v_fallback_verified IS NULL OR NOT v_fallback_verified THEN
          RAISE EXCEPTION 'fallback engineer % is not verified', v_fallback_id
            USING ERRCODE = '22023';
        END IF;

        INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
        VALUES (v_contract_id, v_fallback_id, v_priority, true)
        ON CONFLICT (amc_contract_id, engineer_id) DO NOTHING;
        v_priority := v_priority + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN v_contract_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_amc_contract(
  uuid, text, int, numeric, date, date, text[], text, int, int, boolean, int, uuid[]
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.create_amc_contract(
  uuid, text, int, numeric, date, date, text[], text, int, int, boolean, int, uuid[]
) TO authenticated;

COMMENT ON FUNCTION public.create_amc_contract(
  uuid, text, int, numeric, date, date, text[], text, int, int, boolean, int, uuid[]
) IS
  'PR-C1 + round 301 + round 477: creates an AMC contract. Round 477 sets initial status=pending_payment (was active) — gates the Free Service Attack where contracts were active before any payment landed. The cron auto_create_due_amc_visits filters WHERE status=active so no visits fire until apply_amc_pool_credit promotes the contract on first verified credit.';

-- ---------------------------------------------------------------------
-- 3. apply_amc_pool_credit — promote pending_payment → active on first credit.
--
-- Extends the round 474 status-gate. Now accepts pending_payment as a
-- valid target for the FIRST credit; on credit insert, flip status to
-- 'active' AND record paid_at-ish metadata via next_visit_at refresh.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.apply_amc_pool_credit(p_payment_order_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id   uuid;
  v_contract_stat text;
  v_amount        numeric(10,2);
  v_rzp_pay_id    text;
  v_balance       numeric(10,2);
  v_ledger_id     uuid;
BEGIN
  -- Lock the order row (round 267).
  SELECT amc_contract_id, amount_rupees, razorpay_payment_id
    INTO v_contract_id, v_amount, v_rzp_pay_id
    FROM public.amc_payment_orders
    WHERE id = p_payment_order_id AND status = 'paid'
    FOR UPDATE;

  IF v_contract_id IS NULL THEN
    RAISE EXCEPTION 'payment order % not found or not paid', p_payment_order_id
      USING ERRCODE = '42704';
  END IF;

  -- ROUND 474 + 477 — refuse to credit terminal contracts; ACCEPT
  -- pending_payment, active, paused. Promotion handled at end of fn.
  SELECT status::text INTO v_contract_stat
    FROM public.amc_contracts
    WHERE id = v_contract_id
    FOR UPDATE;

  IF v_contract_stat IS NULL THEN
    RAISE EXCEPTION 'contract for payment order % not found', p_payment_order_id
      USING ERRCODE = '42704';
  END IF;

  IF v_contract_stat NOT IN ('pending_payment', 'active', 'paused') THEN
    RAISE EXCEPTION 'amc contract is in terminal status % — refusing credit (auto-refund expected)', v_contract_stat
      USING ERRCODE = 'P0001',
            HINT = 'razorpay-webhook should detect this via no_matching_row + cancelled-row branch and auto-refund';
  END IF;

  -- Idempotency: existing credit row → no-op (round 267).
  SELECT id INTO v_ledger_id
    FROM public.amc_payment_pool
    WHERE source_payment_order_id = p_payment_order_id
      AND ledger_kind = 'credit'
    LIMIT 1;
  IF v_ledger_id IS NOT NULL THEN
    RETURN v_ledger_id;
  END IF;

  -- Running balance derivation (round 267).
  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       + v_amount
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = v_contract_id;

  INSERT INTO public.amc_payment_pool (
    amc_contract_id, ledger_kind, amount_rupees, balance_after,
    source_payment_order_id, description
  ) VALUES (
    v_contract_id, 'credit', v_amount, v_balance,
    p_payment_order_id,
    'Razorpay payment ' || coalesce(v_rzp_pay_id, 'unknown')
  ) RETURNING id INTO v_ledger_id;

  -- ROUND 477 — promote pending_payment → active on first credit.
  -- Also promote paused → active on top-up (round 474 behavior).
  -- The contract row is already locked FOR UPDATE above so this is
  -- race-safe.
  UPDATE public.amc_contracts
     SET status = 'active',
         updated_at = now()
     WHERE id = v_contract_id
       AND status IN ('pending_payment', 'paused');

  RETURN v_ledger_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO service_role;

COMMENT ON FUNCTION public.apply_amc_pool_credit(uuid) IS
  'PR-C2 + round 267 + round 474 + round 477: applies a credit to an AMC contract pool. Round 477 extends: accepts pending_payment as a valid status (it''s the round 477 gate); promotes pending_payment → active on first credit. Refuses credit if contract is in expired/cancelled/renewal_failed.';

-- ---------------------------------------------------------------------
-- 4. reap_stranded_pending_payment_amc_contracts — cron sweeper.
--
-- Hospital creates contract → status=pending_payment → user closes app
-- before completing payment → contract sits forever. This reaper cancels
-- contracts older than 24h still in pending_payment so they don't
-- pollute the contract list. The hospital can re-create the contract
-- and pay properly on the next attempt.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.reap_stranded_pending_payment_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  -- Cancel pending_payment contracts older than 24h + atomically
  -- invalidate any pending amc_payment_orders tied to them.
  --
  -- Why atomic invalidation (CodeRabbit catch):
  --   verify-amc-payment marks the order status='paid' BEFORE calling
  --   apply_amc_pool_credit. Without this order-kill step, a hospital
  --   could:
  --     1. Create contract → status=pending_payment + payment order A pending
  --     2. Close app before Razorpay returns
  --     3. Reaper cancels the contract 24h later
  --     4. Hospital re-opens the app, completes payment from a stale link
  --     5. verify-amc-payment marks order A 'paid'
  --     6. apply_amc_pool_credit rejects (contract cancelled)
  --     7. Razorpay auto-refund (r473) recovers — works, but messy
  --   Proactive order kill eliminates that inflight window: the
  --   pre-Razorpay create-amc-payment-order check will reject if order
  --   is already 'failed', so the user can't even start the Razorpay
  --   sheet against a stranded order.
  --
  -- amc_payment_orders.status CHECK allows ('pending','paid','failed',
  -- 'refunded') — 'cancelled' is NOT valid, so we use 'failed' as the
  -- terminal label.
  --
  -- Single SQL statement via CTE ensures atomicity — no window where a
  -- contract is cancelled but the order is still pending.
  WITH cancelled AS (
    UPDATE public.amc_contracts
       SET status = 'cancelled',
           updated_at = now(),
           scope_text = coalesce(scope_text, '') ||
             E'\n[reaper: stranded in pending_payment for >24h; auto-cancelled by reap_stranded_pending_payment_amc_contracts]'
     WHERE status = 'pending_payment'
       AND created_at < (now() - interval '24 hours')
    RETURNING id
  ),
  killed_orders AS (
    UPDATE public.amc_payment_orders
       SET status = 'failed',
           updated_at = now()
     WHERE amc_contract_id IN (SELECT id FROM cancelled)
       AND status = 'pending'
    RETURNING id
  )
  SELECT count(*)::int INTO v_count FROM cancelled;

  IF v_count > 0 THEN
    RAISE NOTICE 'reap_stranded_pending_payment_amc_contracts: cancelled % stranded contracts + invalidated tied pending orders', v_count;
  END IF;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reap_stranded_pending_payment_amc_contracts()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reap_stranded_pending_payment_amc_contracts()
  TO service_role;

COMMENT ON FUNCTION public.reap_stranded_pending_payment_amc_contracts() IS
  'Round 477: pg_cron-driven sweeper. Cancels AMC contracts still in pending_payment after 24h. Frees the (hospital, primary_engineer_id, start_date) tuple so the hospital can re-create the contract cleanly.';

-- ---------------------------------------------------------------------
-- 5. Schedule the reaper on pg_cron (runs every hour).
--
-- pg_cron is already in use by round 466 (payout reconciliation) +
-- existing AMC renewal cron — schema exists, just add the job.
-- ---------------------------------------------------------------------

-- Unschedule any prior version of this job for idempotency (re-running
-- the migration is safe).
DO $$
DECLARE
  v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job
   WHERE jobname = 'reap_stranded_pending_payment_amc_contracts';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- pg_cron extension not installed on this Supabase project (it's a
    -- Pro-tier opt-in). Skip silently — the reaper is scheduled out-of-
    -- band via the .github/workflows/cron-tick-* GH Actions workflow
    -- that POSTs to a tick endpoint hourly. See SETUP.md for wiring.
    RAISE NOTICE 'pg_cron not available (%) — reaper job not registered; schedule via GH Actions cron-tick instead', SQLERRM;
END $$;

DO $$
BEGIN
  PERFORM cron.schedule(
    'reap_stranded_pending_payment_amc_contracts',
    '0 * * * *',  -- every hour, on the minute
    $cron$SELECT public.reap_stranded_pending_payment_amc_contracts()$cron$
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not available (%) — reaper job not registered; schedule via GH Actions cron-tick instead', SQLERRM;
END $$;
