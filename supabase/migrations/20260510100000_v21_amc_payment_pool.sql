-- v2.1 PR-C2: AMC pre-paid escrow payment pool with Razorpay binding.
--
-- AMC contracts (PR-C1) are subscription products: hospital pays a
-- monthly fee, engineer drives out for scheduled visits, platform
-- holds the money in escrow and releases share-per-visit to the
-- engineer (engineer-payout split is handled in PR-C4 settlement).
--
-- This migration is the "wallet" layer that sits between Razorpay
-- charges (one-off, hospital-initiated, M months at a time) and the
-- per-visit deductions that fire whenever a maintenance repair_jobs
-- row flips to 'completed'.
--
-- Two tables:
--   amc_payment_orders : Razorpay order ↔ AMC contract binding. One
--                        row per Razorpay charge attempt. Mirrors the
--                        spare_part_orders <-> Razorpay binding shape
--                        so verify-amc-payment can re-use the same
--                        replay-attack guard (require client-submitted
--                        razorpay_order_id to match the persisted one).
--   amc_payment_pool   : append-only ledger. Credits land on
--                        successful Razorpay verification; debits land
--                        on visit completion. balance_after is
--                        snapshotted on every row for fast balance
--                        reads without scanning the whole ledger.
--
-- Plus:
--   apply_amc_pool_credit(uuid)         — SECURITY DEFINER RPC called
--                                          by verify-amc-payment after
--                                          HMAC verification.
--   debit_amc_pool_on_visit_complete()  — trigger on repair_jobs that
--                                          deducts the per-visit cost
--                                          when status flips to
--                                          'completed' for an AMC visit.
--   v_amc_pool_balance                  — view exposing latest balance
--                                          per contract.
--   get_amc_pool_balance(uuid)          — RLS-aware convenience RPC
--                                          for hospital UI.
--
-- All client-facing writes go through SECURITY DEFINER paths; raw
-- INSERT/UPDATE/DELETE on these tables is revoked from anon and
-- authenticated.

-- 1. Razorpay-order ↔ AMC-contract binding.
CREATE TABLE public.amc_payment_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,

  -- Number of months this charge prepays for. Caps at 36 (matches
  -- amc_contracts.renewal_term_months max). amount_rupees is the
  -- de-normalized total = monthly_fee_rupees * months_paid; computed
  -- by create-amc-payment-order edge fn so we never trust client.
  months_paid int NOT NULL CHECK (months_paid > 0 AND months_paid <= 36),
  amount_rupees numeric(10,2) NOT NULL CHECK (amount_rupees > 0),

  -- Razorpay-side identifiers. razorpay_order_id is set by the
  -- create-amc-payment-order edge fn after Razorpay returns the order;
  -- razorpay_payment_id is set by verify-amc-payment after HMAC passes.
  -- UNIQUE on razorpay_order_id prevents double-binding the same
  -- Razorpay order to two different amc_payment_orders rows.
  razorpay_order_id text UNIQUE,
  razorpay_payment_id text,

  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','paid','failed','refunded')),

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX amc_payment_orders_contract_idx
  ON public.amc_payment_orders (amc_contract_id);
CREATE INDEX amc_payment_orders_status_created_idx
  ON public.amc_payment_orders (status, created_at);

-- 2. Append-only ledger. Sign comes from ledger_kind, amount is
-- always positive. balance_after is the running balance for this
-- contract right after this row was inserted; we snapshot it instead
-- of computing on read so balance lookups are O(1).
CREATE TABLE public.amc_payment_pool (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,

  ledger_kind text NOT NULL
    CHECK (ledger_kind IN ('credit','debit','refund')),
  amount_rupees numeric(10,2) NOT NULL CHECK (amount_rupees > 0),
  balance_after numeric(10,2) NOT NULL,

  -- Provenance. Credits link back to the payment_order that funded
  -- them (for idempotency: only one credit row per paid order ever).
  -- Debits link back to the repair_jobs visit that consumed the funds.
  source_payment_order_id uuid REFERENCES public.amc_payment_orders(id),
  source_visit_id uuid REFERENCES public.repair_jobs(id),

  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX amc_payment_pool_contract_created_idx
  ON public.amc_payment_pool (amc_contract_id, created_at DESC);
CREATE INDEX amc_payment_pool_visit_idx
  ON public.amc_payment_pool (source_visit_id) WHERE source_visit_id IS NOT NULL;
CREATE UNIQUE INDEX amc_payment_pool_credit_per_order_uidx
  ON public.amc_payment_pool (source_payment_order_id)
  WHERE source_payment_order_id IS NOT NULL AND ledger_kind = 'credit';
CREATE UNIQUE INDEX amc_payment_pool_debit_per_visit_uidx
  ON public.amc_payment_pool (source_visit_id)
  WHERE source_visit_id IS NOT NULL AND ledger_kind = 'debit';

-- 3. RLS — same shape as amc_contracts: hospital sees own (joined
-- through the parent contract row), engineer sees pool only for
-- contracts they're rotated on, admin/founder bypass.
ALTER TABLE public.amc_payment_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amc_payment_pool   ENABLE ROW LEVEL SECURITY;

CREATE POLICY amc_payment_orders_hospital_own ON public.amc_payment_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_payment_orders.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

CREATE POLICY amc_payment_orders_admin_all ON public.amc_payment_orders
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

CREATE POLICY amc_payment_pool_hospital_own ON public.amc_payment_pool
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_payment_pool.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

CREATE POLICY amc_payment_pool_engineer_assigned ON public.amc_payment_pool
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      JOIN public.engineers e ON e.id = c.primary_engineer_id
      WHERE c.id = amc_payment_pool.amc_contract_id
        AND e.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = amc_payment_pool.amc_contract_id
        AND e.user_id = auth.uid()
        AND r.active = true
    )
  );

CREATE POLICY amc_payment_pool_admin_all ON public.amc_payment_pool
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

-- All client writes go through SECURITY DEFINER RPCs / edge fns.
REVOKE INSERT, UPDATE, DELETE ON public.amc_payment_orders FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.amc_payment_pool   FROM anon, authenticated;

-- 4. Credit application RPC. Called by verify-amc-payment after the
-- Razorpay HMAC verifies. Idempotent: re-calling with the same paid
-- order returns the existing ledger row id without double-crediting.
CREATE OR REPLACE FUNCTION public.apply_amc_pool_credit(p_payment_order_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id uuid;
  v_amount      numeric(10,2);
  v_rzp_pay_id  text;
  v_balance     numeric(10,2);
  v_ledger_id   uuid;
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
  -- 'paused' only.
  UPDATE public.amc_contracts
     SET status = 'active', updated_at = now()
     WHERE id = v_contract_id AND status = 'paused';

  RETURN v_ledger_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO service_role;

-- 5. Per-visit debit trigger. Fires AFTER UPDATE OF status on
-- repair_jobs, only for AMC maintenance visits transitioning to
-- 'completed'. Per-visit cost = monthly_fee * 12 / visits_per_year,
-- i.e. fair share of the annual envelope.
--
-- Idempotency: enforced by amc_payment_pool_debit_per_visit_uidx
-- (UNIQUE on source_visit_id WHERE ledger_kind='debit'). The
-- pre-check below is a cheap fast-path that avoids constraint hits in
-- normal flow (e.g. a status reset + complete cycle by admin).
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

  -- Only act on the actual transition into completed.
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
    -- Defensive: contract gone or malformed; skip silently rather
    -- than block the visit-complete update.
    RETURN NEW;
  END IF;

  v_per_visit_cost := round(v_monthly_fee * 12 / v_visits_per_yr, 2);

  -- Signed-sum derivation matches apply_amc_pool_credit.
  SELECT coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)
       - v_per_visit_cost
    INTO v_balance
    FROM public.amc_payment_pool
    WHERE amc_contract_id = NEW.amc_contract_id;

  INSERT INTO public.amc_payment_pool (
    amc_contract_id, ledger_kind, amount_rupees, balance_after,
    source_visit_id, description
  ) VALUES (
    NEW.amc_contract_id, 'debit', v_per_visit_cost, v_balance,
    NEW.id,
    'AMC visit completion ' || NEW.id::text
  );

  UPDATE public.amc_contracts
     SET visits_completed = visits_completed + 1,
         updated_at = now(),
         -- If this debit drives the pool negative, pause the contract
         -- so PR-C3's renewal cron (and the UI banner) can prompt the
         -- hospital to top up. Don't override terminal statuses.
         status = CASE
           WHEN v_balance < 0 AND status = 'active' THEN 'paused'
           ELSE status
         END
     WHERE id = NEW.amc_contract_id;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.debit_amc_pool_on_visit_complete() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_debit_amc_pool_on_visit_complete ON public.repair_jobs;
CREATE TRIGGER trg_debit_amc_pool_on_visit_complete
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.kind = 'maintenance' AND NEW.amc_contract_id IS NOT NULL)
  EXECUTE FUNCTION public.debit_amc_pool_on_visit_complete();

-- 6. Balance view + convenience RPC. View is SECURITY INVOKER (the
-- default), so it inherits the underlying table's RLS. Hospital sees
-- only their own contract balances.
CREATE OR REPLACE VIEW public.v_amc_pool_balance AS
  SELECT amc_contract_id,
         coalesce(
           SUM(CASE WHEN ledger_kind = 'debit' THEN -amount_rupees
                    ELSE amount_rupees END),
           0)::numeric(10,2) AS balance_rupees
    FROM public.amc_payment_pool
   GROUP BY amc_contract_id;

GRANT SELECT ON public.v_amc_pool_balance TO authenticated;

CREATE OR REPLACE FUNCTION public.get_amc_pool_balance(p_contract_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    (SELECT balance_rupees FROM public.v_amc_pool_balance
      WHERE amc_contract_id = p_contract_id),
    0::numeric
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_amc_pool_balance(uuid) TO authenticated;
