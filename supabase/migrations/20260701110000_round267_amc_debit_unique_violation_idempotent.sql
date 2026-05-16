-- Round 267 — make debit_amc_pool_on_visit_complete idempotent on
-- concurrent visit-complete collisions.
--
-- The trigger pre-checks for an existing debit (line 276 of PR-D2's
-- migration), then INSERTs. Between the SELECT and the INSERT, a
-- concurrent visit-complete UPDATE on the same row can also pass the
-- pre-check + race to INSERT — the partial unique index
-- amc_payment_pool_debit_per_visit_uidx then catches the second one
-- with SQLSTATE 23505, which aborts the parent transaction
-- (the UPDATE on repair_jobs).
--
-- User sees the visit-complete fail with a generic "duplicate" error
-- even though the real state — a debit row exists for this visit —
-- is exactly what they wanted. Wrap the INSERT in an EXCEPTION
-- WHEN unique_violation handler so the duplicate path returns
-- silently. The unique index remains the hard guard.

CREATE OR REPLACE FUNCTION public.debit_amc_pool_on_visit_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_monthly_fee    numeric(10,2);
  v_visits_per_yr  int;
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

  SELECT monthly_fee_rupees, visits_per_year
    INTO v_monthly_fee, v_visits_per_yr
    FROM public.amc_contracts
    WHERE id = NEW.amc_contract_id
    FOR UPDATE;

  IF v_monthly_fee IS NULL OR v_visits_per_yr IS NULL OR v_visits_per_yr = 0 THEN
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
