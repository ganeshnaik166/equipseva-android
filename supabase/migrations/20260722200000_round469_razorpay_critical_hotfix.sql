-- Round 469 — EMERGENCY hotfix for 2 CRITICAL Razorpay flow bugs caught by audit 6.
--
-- (1) CRITICAL — Cross-row signature replay on spare_part_orders + repair_job_escrow.
--     amc_payment_orders has UNIQUE (razorpay_order_id) — the other two intake
--     tables don't. Exploit: authenticated buyer creates 2 orders (cheap + expensive),
--     binds the same razorpay_order_id to BOTH via RLS-allowed UPDATE on the
--     pending one, pays the cheap order at Razorpay (₹10), then calls verify-*
--     twice (once with order=A, once with order=B). Both pass the per-row binding
--     check + HMAC verify. Both flip to completed. Buyer pays ₹10, gets ₹100k worth
--     of fulfillment.
--
-- (2) CRITICAL — Items mutation after razorpay_order_id binding bypasses amount lock.
--     Round 450 added a trigger that recomputes spare_part_orders.total_amount on
--     UPDATE (not just INSERT) — necessary for cost-revision flow but it AMPLIFIED
--     this attack: buyer creates ₹10 order, binds Razorpay order at ₹10, UPDATEs
--     items array to expensive parts (RLS allows; round 450's REVOKE only covered
--     subtotal/gst_amount/shipping_cost/total_amount — NOT items), trigger
--     recomputes total_amount = ₹100k, buyer pays the ₹10 at Razorpay (Razorpay
--     enforces only the original ₹10 against the bound order), verify-* passes
--     HMAC + binding (no amount cross-check vs Razorpay GET /payments/{id}),
--     status flips to completed at the NEW total_amount=₹100k. Supplier ships
--     ₹100k of parts paid only ₹10.
--
-- Fixes in this migration:
--   1. Partial UNIQUE index on razorpay_order_id for spare_part_orders +
--      repair_job_escrow (matches the amc_payment_orders pattern). Prevents
--      cross-row replay at the DB layer.
--   2. REVOKE UPDATE (razorpay_order_id, razorpay_payment_id) on all 3 intake
--      tables — once Razorpay binding is set, clients cannot rebind it. Was an
--      RLS-only protection before; now grant-layer too.
--   3. New BEFORE-UPDATE trigger spare_part_orders_freeze_items_when_bound —
--      RAISE EXCEPTION if items column is being changed and razorpay_order_id
--      is NOT NULL. Closes the round-450-amplified items-tamper path.
--   4. (Companion in edge fn round469): all 3 verify-* functions add a
--      server-side GET /v1/payments/{id} call to Razorpay's API + assert
--      amount/status/order_id match the row. This is Razorpay's own recommended
--      anti-tamper backstop (their HMAC only covers order_id|payment_id, not
--      amount).

-- ---------------------------------------------------------------------
-- 1. UNIQUE razorpay_order_id on spare_part_orders + repair_job_escrow
-- ---------------------------------------------------------------------

-- Pre-flight: check for existing duplicate razorpay_order_ids. If any, the
-- index creation will fail and we need ops triage before we can ship this.
DO $$
DECLARE
  v_dups int;
BEGIN
  SELECT count(*) INTO v_dups FROM (
    SELECT razorpay_order_id FROM public.spare_part_orders
     WHERE razorpay_order_id IS NOT NULL
     GROUP BY razorpay_order_id HAVING count(*) > 1
  ) x;
  IF v_dups > 0 THEN
    RAISE EXCEPTION 'spare_part_orders has % duplicate razorpay_order_id values — ops triage required before round 469 can apply', v_dups;
  END IF;

  SELECT count(*) INTO v_dups FROM (
    SELECT razorpay_order_id FROM public.repair_job_escrow
     WHERE razorpay_order_id IS NOT NULL
     GROUP BY razorpay_order_id HAVING count(*) > 1
  ) x;
  IF v_dups > 0 THEN
    RAISE EXCEPTION 'repair_job_escrow has % duplicate razorpay_order_id values — ops triage required before round 469 can apply', v_dups;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_spare_part_orders_razorpay_order_id
  ON public.spare_part_orders (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_repair_job_escrow_razorpay_order_id
  ON public.repair_job_escrow (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 2. Column-level REVOKE on razorpay binding columns (defense in depth).
--    Round 467 taught us: table-level grant overrides column REVOKE. So
--    REVOKE table-level UPDATE then GRANT only what clients need.
-- ---------------------------------------------------------------------

-- spare_part_orders
REVOKE UPDATE ON public.spare_part_orders FROM authenticated, anon;
-- Re-grant on the columns clients legitimately write. Round 450 already
-- locked subtotal/gst_amount/shipping_cost/total_amount via the recompute
-- trigger; we re-grant 'items' but the new freeze trigger below blocks
-- mutation once razorpay_order_id is set.
GRANT UPDATE (
  items, shipping_address, shipping_city, shipping_state, shipping_pincode,
  notes,
  tracking_number, estimated_delivery, delivered_at,
  order_status,  -- guarded by guard_order_state_transitions trigger
  payment_status,  -- guarded
  cancel_reason,
  updated_at
) ON public.spare_part_orders TO authenticated;

-- repair_job_escrow — round 469: only service_role + admin should ever
-- mutate this table outside of the standard RPCs. Client UPDATE was
-- already restricted by RLS but grant was wide. Lock it down.
REVOKE UPDATE ON public.repair_job_escrow FROM authenticated, anon;
GRANT UPDATE (
  -- Hospital can write dispute fields via open_repair_job_escrow_dispute
  -- RPC which runs as SECDEF; if we want raw REST path too, allowlist here
  dispute_reason,
  engineer_response,
  updated_at
) ON public.repair_job_escrow TO authenticated;

-- amc_payment_orders — same defense-in-depth (had UNIQUE razorpay_order_id
-- already; now lock the rest of the binding columns).
REVOKE UPDATE ON public.amc_payment_orders FROM authenticated, anon;
GRANT UPDATE (
  -- Clients shouldn't write to this table outside of RPCs anyway, but
  -- allowlist nothing here — all writes via SECDEF (apply_amc_pool_credit etc.)
  updated_at
) ON public.amc_payment_orders TO authenticated;

-- ---------------------------------------------------------------------
-- 3. Freeze items on spare_part_orders once razorpay_order_id is set.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.spare_part_orders_freeze_items_when_bound()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- Elevated callers (service_role, SECDEF fns, admin) bypass — they
  -- legitimately mutate items during cost-revision or admin force-edit.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Once a razorpay_order_id is bound, items is frozen. Buyer must
  -- cancel + create a new order to change items.
  IF OLD.razorpay_order_id IS NOT NULL
     AND NEW.items IS DISTINCT FROM OLD.items THEN
    RAISE EXCEPTION 'spare_part_orders.items cannot be modified after razorpay_order_id is bound — create a new order'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.spare_part_orders_freeze_items_when_bound() FROM PUBLIC;

DROP TRIGGER IF EXISTS spare_part_orders_freeze_items_when_bound_trg ON public.spare_part_orders;
CREATE TRIGGER spare_part_orders_freeze_items_when_bound_trg
  BEFORE UPDATE ON public.spare_part_orders
  FOR EACH ROW
  WHEN (NEW.items IS DISTINCT FROM OLD.items)
  EXECUTE FUNCTION public.spare_part_orders_freeze_items_when_bound();

-- ---------------------------------------------------------------------
-- 4. Founder dashboard helper: surface any duplicate razorpay_order_id
--    rows that slipped in before the UNIQUE index was added (paranoia
--    check — pre-flight above asserts 0 dups). Useful for ongoing ops.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_razorpay_binding_health()
RETURNS TABLE (
  table_name        text,
  duplicate_count   bigint,
  null_binding_count bigint,
  oldest_null_at    timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_binding_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_binding_health() TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_binding_health() IS
  'Round 469: surfaces any duplicate razorpay_order_id rows + count of orders stuck in pending with no binding. duplicate_count should always be 0 (enforced by UNIQUE index); >0 means ops needs to triage.';

-- Document the lockdown.
COMMENT ON TABLE public.spare_part_orders IS
  'Spare parts orders. Round 469: razorpay_order_id is UNIQUE (partial WHERE NOT NULL); UPDATE grant is column-allowlist; items column is frozen once razorpay_order_id is bound (trigger). Triggers + grants both enforce — two-layer defense.';

COMMENT ON TABLE public.repair_job_escrow IS
  'Per-repair-job escrow rows. Round 469: razorpay_order_id is UNIQUE (partial); UPDATE grant is column-allowlist (only dispute_reason, engineer_response, updated_at). All status transitions via SECDEF RPCs.';
