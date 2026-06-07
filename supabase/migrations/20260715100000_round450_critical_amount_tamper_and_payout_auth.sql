-- Round 450 — CRITICAL fixes. Both findings flagged by the 2026-06-07
-- adversarial audit; bundled because both are server-side single-file
-- changes that must ship together to close the financial-fraud surface.
--
--   1. CRITICAL — spare_part_orders amount tampering. compute_order_totals
--      trigger only fires BEFORE INSERT. RLS lets the buyer UPDATE their
--      own row while payment_status='pending', and column-level grants
--      don't revoke UPDATE on (subtotal, gst_amount, shipping_cost,
--      total_amount). A buyer can therefore:
--        a) create a legitimate ₹100,000 order via INSERT (trigger
--           computes total_amount correctly)
--        b) UPDATE total_amount = 1 (RLS passes — payment_status still
--           pending)
--        c) call create-razorpay-order → Razorpay order issued for
--           ₹0.01
--        d) pay 1 paisa, verify, order flips to completed
--      Net: hospital pays 1 paisa for any-priced order.
--
--   2. CRITICAL — payout_status_for_job authorisation predicate compares
--      repair_jobs.engineer_id (which is a FK to engineers.id) against
--      auth.uid() (which is the auth.users row id). They are always
--      different uuids by construction. Engineers ALWAYS get an empty
--      result, so the "Paid ₹X to your UPI · UTR REF…" surface never
--      renders on the engineer's repair-job detail screen — defeating
--      the anti-disintermediation point of round 431. Hospitals work
--      because their auth.uid does equal hospital_user_id.
--
-- Deploy: supabase db push. No edge fn / Android changes required.

-- ---------------------------------------------------------------------
-- 1. compute_order_totals: extend to fire on UPDATE so re-derivation
-- closes the amount-tampering window
-- ---------------------------------------------------------------------
-- The existing function body (20260424015823) recomputes from the row's
-- own `items` jsonb joined to spare_parts.price + gst_rate. Re-running
-- it on UPDATE is safe and idempotent:
--   - If `items` hasn't changed: totals re-derive to the same value.
--   - If `items` changed (buyer edits cart pre-payment): totals
--     re-derive to the new correct value.
-- Either way, tampered totals get overwritten before the row is committed.
--
-- Service-role bypass already exists inside compute_order_totals via the
-- standard request.jwt.claims->>'role' check; that lets verify-* edge
-- functions UPDATE payment_status/invoice_url without the trigger
-- recomputing on those write paths (the rows it sets don't touch
-- totals, but defense in depth keeps any future admin/SECDEF path safe).

DROP TRIGGER IF EXISTS trg_compute_order_totals ON public.spare_part_orders;
CREATE TRIGGER trg_compute_order_totals
  BEFORE INSERT OR UPDATE ON public.spare_part_orders
  FOR EACH ROW EXECUTE FUNCTION public.compute_order_totals();

COMMENT ON FUNCTION public.compute_order_totals() IS
  'Round 450: recomputes spare_part_orders subtotal/gst_amount/shipping_cost/'
  'total_amount from spare_parts.price + gst_rate on INSERT OR UPDATE. '
  'Closes the amount-tampering attack where a buyer UPDATEs total_amount '
  'to 1 paisa while payment_status=pending and pays a token amount for an '
  'any-priced order. Service-role / postgres bypass for verify-* edge fns.';

-- Defense in depth: explicitly revoke UPDATE on the four total columns
-- so even if the trigger were ever disabled, authenticated callers
-- still can't write tamper-sensitive numerics. Keep authenticated able
-- to update items/payment_status/etc. via the existing RLS policy.
REVOKE UPDATE (subtotal, gst_amount, shipping_cost, total_amount)
  ON public.spare_part_orders FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. payout_status_for_job — fix engineer authorisation predicate
-- ---------------------------------------------------------------------
-- The original (round 431) compared rj.engineer_id = auth.uid(), but
-- rj.engineer_id is a FK to engineers.id, NOT auth.users.id. The fix
-- mirrors round 446's get_repair_job_escrow auth: hop through the
-- engineers table to translate engineers.id → engineers.user_id.

-- Signature preserved exactly (10 cols, same order) so CREATE OR REPLACE
-- doesn't trip 42P13 (return-type change). Only the auth predicate is
-- modified — engineers now match via engineers.user_id translation.
CREATE OR REPLACE FUNCTION public.payout_status_for_job(
  p_repair_job_id uuid
)
RETURNS TABLE (
  id                 uuid,
  amount_paise       bigint,
  status             text,
  mode               text,
  utr                text,
  failure_reason     text,
  destination_label  text,
  engineer_name      text,
  queued_at          timestamptz,
  processed_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_authorised boolean := false;
BEGIN
  IF v_caller IS NULL THEN
    RETURN;
  END IF;

  -- Round 450 fix: engineers must be matched via the engineers.user_id
  -- translation. The original predicate compared rj.engineer_id (a FK
  -- to engineers.id, NOT auth.users.id) to auth.uid() — engineers were
  -- always denied and Kotlin saw an empty row, breaking the anti-
  -- disintermediation surface on the repair-job detail screen.
  SELECT
    public.is_founder()
    OR EXISTS (
      SELECT 1
        FROM public.repair_jobs rj
       WHERE rj.id = p_repair_job_id
         AND (
           rj.hospital_user_id = v_caller
           OR v_caller IN (
             SELECT e.user_id
               FROM public.engineers e
              WHERE e.id = rj.engineer_id
           )
         )
    )
  INTO v_authorised;

  IF NOT v_authorised THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.amount_paise,
    p.status,
    p.mode,
    p.utr,
    p.failure_reason,
    CASE
      WHEN m.id IS NULL              THEN NULL
      WHEN m.kind = 'upi'            THEN m.vpa
      WHEN m.kind = 'bank' AND m.bank_name IS NOT NULL
                                     THEN m.bank_name || ' •••• ' || m.account_number_last4
      ELSE                                'Bank •••• ' || m.account_number_last4
    END AS destination_label,
    pr.full_name AS engineer_name,
    p.queued_at,
    p.processed_at
  FROM public.engineer_payouts p
  LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.repair_job_id = p_repair_job_id
  LIMIT 1;
END
$$;
REVOKE EXECUTE ON FUNCTION public.payout_status_for_job(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.payout_status_for_job(uuid) TO authenticated;

COMMENT ON FUNCTION public.payout_status_for_job(uuid) IS
  'Round 450 — fixed auth predicate: engineers now match via engineers.user_id '
  '(was comparing engineers.id to auth.uid, always denied). Signature unchanged.';
