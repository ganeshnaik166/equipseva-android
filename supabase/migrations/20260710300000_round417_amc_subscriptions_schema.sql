-- Round 417 — AMC auto-charge phase 1: data model.
--
-- Today v2.1 AMC contracts have:
--   * monthly_fee_rupees (target monthly debit from hospital → engineer)
--   * auto_renew boolean (auto-extends end_date when the contract expires,
--     since round 317 server fn — does NOT auto-charge today)
--   * amc_payment_pool (pre-paid hospital balance, debited per-visit)
--
-- What's missing: recurring auto-debit of the monthly fee. Hospitals
-- currently top-up the pool manually each month (cron sends nudge), which
-- bleeds 5-15% of cycles (forget → visit fails → escalation).
--
-- This migration lays the data model for the Razorpay subscription /
-- recurring-mandate flow. Wiring + edge fn + reconciler come in later
-- rounds (this phase is scaffolding only).
--
-- Two new tables:
--   1. amc_subscriptions — one row per (amc_contract, razorpay_subscription).
--      Tracks status + period boundaries so the cron knows when to charge.
--   2. amc_subscription_charges — ledger of individual debit attempts +
--      outcomes. Distinct from amc_payment_pool which is the destination
--      side (charge succeeds → credit lands in pool). Lets us reconstruct
--      "why did this period's auto-charge fail" without scanning Razorpay
--      logs.

-- =====================================================================
-- amc_subscriptions
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.amc_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  -- Razorpay-side identifiers. Nullable while we're in 'pending' state
  -- (just-created locally, mandate not yet authorized by the hospital).
  razorpay_subscription_id text UNIQUE,
  razorpay_plan_id text,
  razorpay_customer_id text,
  -- Lifecycle status. Mirrors Razorpay's status names (plus our
  -- 'pending' for the pre-mandate state) so reconciler can do a 1:1
  -- mapping.
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','authenticated','active','paused','cancelled','completed','halted','expired')),
  -- Per-cycle bookkeeping. Razorpay reports current_start / current_end
  -- on the subscription resource; we mirror so the cron can ask "is this
  -- period still open / overdue".
  current_period_start timestamptz,
  current_period_end timestamptz,
  next_charge_at timestamptz,
  -- Last successful charge timestamp + cumulative count. Useful for
  -- founder dashboard ("23 successful auto-charges this month").
  last_charged_at timestamptz,
  total_charges_succeeded int NOT NULL DEFAULT 0,
  total_charges_failed int NOT NULL DEFAULT 0,
  -- Last failure context. NULL'd out on next success.
  last_failure_reason text,
  last_failure_at timestamptz,
  -- Mandate metadata (UPI VPA or last4 of card) for the UI to show
  -- "auto-paying via 8XXX...1234". Razorpay returns this on the
  -- subscription resource.
  mandate_summary text,
  -- Audit columns.
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  cancelled_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- A contract has at most one active subscription at a time, but historic
-- cancelled rows are allowed. Enforce via a partial unique index that
-- only constrains active/pending/authenticated rows.
CREATE UNIQUE INDEX IF NOT EXISTS amc_subscriptions_one_active_per_contract
  ON public.amc_subscriptions (amc_contract_id)
  WHERE status IN ('pending','authenticated','active','paused');

-- Indexes for the cron sweep + per-contract lookups.
CREATE INDEX IF NOT EXISTS amc_subscriptions_status_idx
  ON public.amc_subscriptions (status)
  WHERE status IN ('active','authenticated');
CREATE INDEX IF NOT EXISTS amc_subscriptions_next_charge_idx
  ON public.amc_subscriptions (next_charge_at)
  WHERE status = 'active' AND next_charge_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS amc_subscriptions_contract_idx
  ON public.amc_subscriptions (amc_contract_id);

-- Length CHECKs on free-form text columns (lineage: r406, r415, r729,
-- r734). These are server-written from Razorpay payloads but we still
-- cap to keep rows bounded.
ALTER TABLE public.amc_subscriptions
  ADD CONSTRAINT amc_subscriptions_razorpay_subscription_id_len_chk
    CHECK (razorpay_subscription_id IS NULL OR length(razorpay_subscription_id) <= 64);
ALTER TABLE public.amc_subscriptions
  ADD CONSTRAINT amc_subscriptions_razorpay_plan_id_len_chk
    CHECK (razorpay_plan_id IS NULL OR length(razorpay_plan_id) <= 64);
ALTER TABLE public.amc_subscriptions
  ADD CONSTRAINT amc_subscriptions_razorpay_customer_id_len_chk
    CHECK (razorpay_customer_id IS NULL OR length(razorpay_customer_id) <= 64);
ALTER TABLE public.amc_subscriptions
  ADD CONSTRAINT amc_subscriptions_last_failure_reason_len_chk
    CHECK (last_failure_reason IS NULL OR length(last_failure_reason) <= 500);
ALTER TABLE public.amc_subscriptions
  ADD CONSTRAINT amc_subscriptions_mandate_summary_len_chk
    CHECK (mandate_summary IS NULL OR length(mandate_summary) <= 200);

-- updated_at trigger so the row tracks last-touch.
CREATE OR REPLACE FUNCTION public.amc_subscriptions_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS amc_subscriptions_touch_updated_at ON public.amc_subscriptions;
CREATE TRIGGER amc_subscriptions_touch_updated_at
  BEFORE UPDATE ON public.amc_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.amc_subscriptions_touch_updated_at();

-- RLS — hospital reads own subscriptions, engineer reads contracts they're
-- party to, admin reads all. Writes are SECURITY DEFINER only (edge fn +
-- reconciler).
ALTER TABLE public.amc_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS amc_subscriptions_hospital_own ON public.amc_subscriptions;
CREATE POLICY amc_subscriptions_hospital_own ON public.amc_subscriptions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_subscriptions.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS amc_subscriptions_engineer_party ON public.amc_subscriptions;
CREATE POLICY amc_subscriptions_engineer_party ON public.amc_subscriptions
  FOR SELECT TO authenticated
  USING (
    -- Same hop as v2.1 amc_engineer_rotation RLS: rotation.engineer_id
    -- references engineers(id), so we need the engineers→auth.users join
    -- to land at auth.uid().
    EXISTS (
      SELECT 1 FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = amc_subscriptions.amc_contract_id
        AND e.user_id = auth.uid()
        AND r.active = true
    )
  );

DROP POLICY IF EXISTS amc_subscriptions_admin_all ON public.amc_subscriptions;
CREATE POLICY amc_subscriptions_admin_all ON public.amc_subscriptions
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.amc_subscriptions FROM anon, authenticated;

-- =====================================================================
-- amc_subscription_charges — ledger of individual auto-debit attempts
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.amc_subscription_charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id uuid NOT NULL REFERENCES public.amc_subscriptions(id) ON DELETE CASCADE,
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  razorpay_payment_id text UNIQUE,
  razorpay_invoice_id text,
  amount_rupees numeric NOT NULL CHECK (amount_rupees >= 0),
  status text NOT NULL
    CHECK (status IN ('attempted','succeeded','failed','refunded')),
  -- Period this charge covers (matches the subscription's current_period_*
  -- at the time of the attempt).
  period_start timestamptz NOT NULL,
  period_end timestamptz NOT NULL,
  -- The amc_payment_pool ledger entry id that credit was applied to, when
  -- charge succeeded. Lets the founder dashboard trace "this pool credit
  -- came from auto-debit X" without joining through 3 tables.
  pool_ledger_id uuid REFERENCES public.amc_payment_pool(id) ON DELETE SET NULL,
  -- Failure reason (Razorpay error description). Capped server-side.
  failure_reason text,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS amc_subscription_charges_subscription_idx
  ON public.amc_subscription_charges (subscription_id, attempted_at DESC);
CREATE INDEX IF NOT EXISTS amc_subscription_charges_contract_idx
  ON public.amc_subscription_charges (amc_contract_id, attempted_at DESC);
CREATE INDEX IF NOT EXISTS amc_subscription_charges_status_idx
  ON public.amc_subscription_charges (status)
  WHERE status IN ('attempted','failed');

ALTER TABLE public.amc_subscription_charges
  ADD CONSTRAINT amc_subscription_charges_razorpay_payment_id_len_chk
    CHECK (razorpay_payment_id IS NULL OR length(razorpay_payment_id) <= 64);
ALTER TABLE public.amc_subscription_charges
  ADD CONSTRAINT amc_subscription_charges_razorpay_invoice_id_len_chk
    CHECK (razorpay_invoice_id IS NULL OR length(razorpay_invoice_id) <= 64);
ALTER TABLE public.amc_subscription_charges
  ADD CONSTRAINT amc_subscription_charges_failure_reason_len_chk
    CHECK (failure_reason IS NULL OR length(failure_reason) <= 500);

-- RLS — same shape as amc_subscriptions: hospital + engineer-party reads,
-- admin reads all, writes only via SECDEF.
ALTER TABLE public.amc_subscription_charges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS amc_subscription_charges_hospital_own ON public.amc_subscription_charges;
CREATE POLICY amc_subscription_charges_hospital_own ON public.amc_subscription_charges
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
      WHERE c.id = amc_subscription_charges.amc_contract_id
        AND c.hospital_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS amc_subscription_charges_engineer_party ON public.amc_subscription_charges;
CREATE POLICY amc_subscription_charges_engineer_party ON public.amc_subscription_charges
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = amc_subscription_charges.amc_contract_id
        AND e.user_id = auth.uid()
        AND r.active = true
    )
  );

DROP POLICY IF EXISTS amc_subscription_charges_admin_all ON public.amc_subscription_charges;
CREATE POLICY amc_subscription_charges_admin_all ON public.amc_subscription_charges
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.amc_subscription_charges FROM anon, authenticated;
