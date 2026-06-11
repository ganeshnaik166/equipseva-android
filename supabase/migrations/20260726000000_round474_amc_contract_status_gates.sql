-- Round 474 — AMC contract-status gates on money-flow ops.
--
-- Closes 3 of 8 audit-7 HIGHs by adding defensive contract-status
-- checks to the three money-flow paths that previously fired
-- regardless of whether the parent amc_contracts row was still in a
-- "live" state:
--
--   #5 — apply_amc_pool_credit silently credits cancelled/expired
--        contracts (hospital pays for a dead contract; money lands;
--        no recovery)
--   #6 — debit_amc_pool_on_visit_complete drains cancelled-contract
--        pools (engineer completes stale visit on dead contract;
--        pool debited from orphan funds)
--   #8 — enqueue_engineer_payout_on_amc_visit_debit fires on
--        cancelled-contract visits (engineer paid by EquipSeva for
--        service rendered to a contract that never paid us or was
--        terminated)
--
-- amc_contracts.status enum (from r-v21 schema):
--   'active', 'paused'        — LIVE (money allowed to flow)
--   'expired', 'cancelled',   — TERMINAL (no further money flow)
--     'renewal_failed'
--
-- Design rationale:
--   We guard at the trigger / RPC level rather than at the API layer
--   because that's the narrowest waist for all entry paths (verify-amc,
--   razorpay-webhook recovery, admin tools, future cron). Defense-
--   in-depth: even if a future caller bypasses the API gate, the
--   trigger guard still catches it.
--
--   We RETURN NEW silently (rather than RAISE) on the trigger path to
--   avoid blocking the parent UPDATE (e.g. an admin retroactively
--   completing a visit on a cancelled contract should still succeed
--   as a state correction; the trigger just refuses to debit). The
--   RPC path RAISEs with a specific error code so verify-amc-payment
--   surfaces a structured failure to ops triage.
--
-- Idempotency: all three functions are CREATE OR REPLACE; re-running
-- this migration is safe. The guards are additive (new IF blocks
-- at the top of the body); no existing behavior on live contracts
-- changes.

-- ---------------------------------------------------------------------
-- 1. apply_amc_pool_credit — reject credits on terminal contracts.
--
-- Verify-amc-payment (or razorpay-webhook recovery) calls this AFTER
-- HMAC + server-verify pass. By the time we're here, money is captured
-- at Razorpay. If the contract is dead, we don't credit — we surface
-- as 'contract_not_live' so the caller can:
--   - log + alert ops
--   - trigger auto-refund via the razorpay-webhook r473 path
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
  -- Lock the order row so concurrent verify-amc-payment calls (e.g.
  -- client retry while first call is in-flight) serialize through the
  -- same row and the unique partial index below catches duplicates.
  SELECT amc_contract_id, amount_rupees, razorpay_payment_id
    INTO v_contract_id, v_amount, v_rzp_pay_id
    FROM public.amc_payment_orders
    WHERE id = p_payment_order_id AND status = 'paid'
    FOR UPDATE;

  IF v_contract_id IS NULL THEN
    RAISE EXCEPTION 'payment order % not found or not paid', p_payment_order_id
      USING ERRCODE = '42704';
  END IF;

  -- ROUND 474 — audit-7 HIGH #5 — refuse to credit terminal contracts.
  -- Without this gate, a hospital can pay for a contract after it has
  -- been cancelled / expired / renewal_failed and the money lands in
  -- the dead contract's pool with no recovery path. Caller (verify-
  -- amc-payment or razorpay-webhook) is expected to handle the
  -- structured error by initiating auto-refund.
  SELECT status::text INTO v_contract_stat
    FROM public.amc_contracts
    WHERE id = v_contract_id
    FOR UPDATE;

  IF v_contract_stat IS NULL THEN
    RAISE EXCEPTION 'contract for payment order % not found', p_payment_order_id
      USING ERRCODE = '42704';
  END IF;

  IF v_contract_stat NOT IN ('active', 'paused') THEN
    RAISE EXCEPTION 'amc contract is in terminal status % — refusing credit (auto-refund expected)', v_contract_stat
      USING ERRCODE = 'P0001',
            HINT = 'razorpay-webhook should detect this via no_matching_row + cancelled-row branch and auto-refund';
  END IF;

  -- Idempotency: if a credit row already exists for this order, return
  -- it instead of inserting a duplicate. The unique partial index
  -- amc_payment_pool_credit_per_order_uidx is the hard guard; this
  -- check makes the happy-retry path cheap (no constraint violation).
  SELECT id INTO v_ledger_id
    FROM public.amc_payment_pool
    WHERE source_payment_order_id = p_payment_order_id
      AND ledger_kind = 'credit'
    LIMIT 1;
  IF v_ledger_id IS NOT NULL THEN
    RETURN v_ledger_id;
  END IF;

  -- Derive running balance as the signed sum of every prior ledger
  -- row (credits / refunds positive, debits negative). Each insert
  -- snapshots this value into balance_after for O(1) reads later.
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

  -- A new credit may bring a paused contract back to life. Renewal /
  -- cancellation paths should never auto-resume, so we narrow to
  -- 'paused' only (the status guard above already refused if the
  -- contract is anything other than active/paused).
  UPDATE public.amc_contracts
     SET status = 'active', updated_at = now()
     WHERE id = v_contract_id AND status = 'paused';

  RETURN v_ledger_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO service_role;

COMMENT ON FUNCTION public.apply_amc_pool_credit(uuid) IS
  'PR-C2 + round 267 + round 474: applies a credit to an AMC contract pool. Round 474 adds contract-status gate — refuses credit if contract is in expired/cancelled/renewal_failed. Caller (verify-amc-payment) is expected to handle the structured error by triggering auto-refund via razorpay-webhook r473 path.';

-- ---------------------------------------------------------------------
-- 2. debit_amc_pool_on_visit_complete — skip debit on terminal contracts.
--
-- A stale visit completing (admin retro-edit, or an in-flight visit
-- that landed after contract cancel) should NOT drain the dead
-- contract's pool. The historical balance is frozen as of the
-- cancellation moment; further debits would orphan money + trigger
-- the round-464 payout-enqueue path which would pay engineers from
-- a contract the hospital walked away from.
--
-- We RETURN NEW silently (not RAISE) because the parent UPDATE on
-- repair_jobs is allowed to succeed — the visit really did complete,
-- we just refuse to spend the dead contract's pool on it. Ops can
-- detect via a join: visits with status=completed but no debit row.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.debit_amc_pool_on_visit_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_monthly_fee    numeric(10,2);
  v_visits_per_yr  int;
  v_contract_stat  text;
  v_per_visit_cost numeric(10,2);
  v_balance        numeric(10,2);
  v_existing_id    uuid;
BEGIN
  IF NEW.kind <> 'maintenance' OR NEW.amc_contract_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status::text <> 'completed' OR OLD.status::text = 'completed' THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_existing_id
    FROM public.amc_payment_pool
    WHERE source_visit_id = NEW.id AND ledger_kind = 'debit'
    LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Round 474 — audit-7 HIGH #6 — lock + status-check the contract
  -- before debiting. The FOR UPDATE moved from later into this same
  -- statement so the status check is consistent with the row read
  -- (was already locked here for monthly_fee anyway).
  SELECT monthly_fee_rupees, visits_per_year, status::text
    INTO v_monthly_fee, v_visits_per_yr, v_contract_stat
    FROM public.amc_contracts
    WHERE id = NEW.amc_contract_id
    FOR UPDATE;

  IF v_monthly_fee IS NULL OR v_visits_per_yr IS NULL OR v_visits_per_yr = 0 THEN
    -- Defensive: contract gone or malformed; skip silently rather
    -- than block the visit-complete update.
    RETURN NEW;
  END IF;

  IF v_contract_stat NOT IN ('active', 'paused') THEN
    -- Round 474: contract is terminal (expired/cancelled/renewal_failed).
    -- The visit-complete UPDATE on repair_jobs is allowed to land (the
    -- visit really did complete), but we don't drain the dead
    -- contract's pool. The downstream enqueue_engineer_payout_on_amc_
    -- visit_debit trigger never fires because no debit row is inserted.
    RAISE WARNING 'debit_amc_pool_on_visit_complete: skipping debit for visit % on terminal contract % (status=%)',
      NEW.id, NEW.amc_contract_id, v_contract_stat;
    RETURN NEW;
  END IF;

  v_per_visit_cost := round(v_monthly_fee * 12 / v_visits_per_yr, 2);

  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       - v_per_visit_cost
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = NEW.amc_contract_id;

  -- Race-safe insert. The pre-check at line 41-46 catches the common
  -- "visit completed once already" case; this EXCEPTION handler
  -- catches the narrow concurrent-INSERT race where two paths both
  -- passed the pre-check before either INSERTed. Without it the
  -- parent repair_jobs UPDATE rolls back with a generic 23505 even
  -- though the desired state (debit row exists) is already true.
  BEGIN
    INSERT INTO public.amc_payment_pool (
      amc_contract_id, ledger_kind, amount_rupees, balance_after,
      source_visit_id, description
    ) VALUES (
      NEW.amc_contract_id, 'debit', v_per_visit_cost, v_balance,
      NEW.id,
      'AMC visit completion ' || NEW.id::text
    );
  EXCEPTION WHEN unique_violation THEN
    -- Concurrent path beat us to the debit. Their visits_completed
    -- increment + status-check already ran in their own transaction;
    -- ours is a no-op so we don't double-increment.
    RETURN NEW;
  END;

  UPDATE public.amc_contracts
     SET visits_completed = visits_completed + 1,
         updated_at = now(),
         status = CASE
           WHEN v_balance < 0 AND status = 'active' THEN 'paused'
           ELSE status
         END
     WHERE id = NEW.amc_contract_id;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.debit_amc_pool_on_visit_complete() IS
  'PR-C2 + round 267 + round 474: debits the per-visit cost from the AMC pool on visit completion. Round 474 adds contract-status gate — silently skips debit (still RETURN NEW so visit UPDATE lands) if contract is in expired/cancelled/renewal_failed, preventing drainage of dead-contract pools.';

-- ---------------------------------------------------------------------
-- 3. enqueue_engineer_payout_on_amc_visit_debit — skip on terminal.
--
-- Belt-and-suspenders with #2: after r474's gate in #2, no debit row
-- can be inserted for a terminal contract, so this trigger naturally
-- doesn't fire. But: a future code path could INSERT a debit row
-- directly bypassing the trigger (e.g. an admin RPC for ledger
-- corrections). Defending here too means even direct-insert paths
-- can't queue engineer payouts for dead contracts.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_visit          public.repair_jobs%ROWTYPE;
  v_contract_stat  text;
  v_engineer_uid   uuid;
  v_method_id      uuid;
  v_payout_rupees  numeric(10,2);
  v_payout_paise   bigint;
BEGIN
  IF NEW.ledger_kind <> 'debit' OR NEW.source_visit_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_visit
    FROM public.repair_jobs
    WHERE id = NEW.source_visit_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF v_visit.kind <> 'maintenance' OR v_visit.amc_contract_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Round 474 — audit-7 HIGH #8 — defense-in-depth: also gate here
  -- on contract status. Even if a future code path inserts a debit
  -- row directly bypassing debit_amc_pool_on_visit_complete (e.g.
  -- admin ledger correction), this trigger refuses to enqueue an
  -- engineer payout against a terminal contract.
  SELECT status::text INTO v_contract_stat
    FROM public.amc_contracts
    WHERE id = v_visit.amc_contract_id;
  IF v_contract_stat IS NULL THEN
    RAISE WARNING 'enqueue_engineer_payout_on_amc_visit_debit: contract % for visit % not found — skipping payout',
      v_visit.amc_contract_id, v_visit.id;
    RETURN NEW;
  END IF;
  IF v_contract_stat NOT IN ('active', 'paused') THEN
    RAISE WARNING 'enqueue_engineer_payout_on_amc_visit_debit: contract % is terminal (status=%) — skipping payout for visit %',
      v_visit.amc_contract_id, v_contract_stat, v_visit.id;
    RETURN NEW;
  END IF;

  SELECT e.user_id INTO v_engineer_uid
    FROM public.engineers e
    WHERE e.id = v_visit.engineer_id;
  IF v_engineer_uid IS NULL THEN
    RAISE WARNING 'enqueue_engineer_payout_on_amc_visit_debit: visit % has no resolvable engineer_user_id (engineer_id=%)',
      v_visit.id, v_visit.engineer_id;
    RETURN NEW;
  END IF;

  v_payout_rupees := round(NEW.amount_rupees * 0.85, 2);
  v_payout_paise := (v_payout_rupees * 100)::bigint;

  IF v_payout_paise <= 0 THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_method_id
    FROM public.engineer_payout_methods
    WHERE user_id = v_engineer_uid AND is_default = true
    LIMIT 1;

  INSERT INTO public.engineer_payouts (
    repair_job_id, engineer_user_id, escrow_id,
    payout_method_id, amount_paise, status
  ) VALUES (
    v_visit.id, v_engineer_uid, NULL,
    v_method_id, v_payout_paise, 'queued'
  )
  ON CONFLICT (repair_job_id) DO NOTHING;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit() IS
  'Round 464 + round 474: queues the engineer 85% share after every AMC visit debit. Round 474 adds contract-status gate (defense-in-depth with debit_amc_pool_on_visit_complete) — skips enqueue for terminal contracts so engineers are never paid from EquipSeva for service on cancelled/expired contracts.';
