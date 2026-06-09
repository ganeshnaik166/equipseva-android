-- Round 468 — pre-emptive hardening of the payout dispatch path before
-- Cashfree's "Activation in Process" lands.
--
-- Closes 3 deferred HIGH findings from the 2026-06-07 audit-5:
--
-- (1) HIGH — no_method spin-loop blocks the queue.
--     Current picker selects ANY queued row. When the engineer has no
--     default method on file, the worker hits the row, dispatch RPC
--     reverts to status='queued' AND attempts is incremented forever.
--     Next tick picks the same row again (oldest-first ORDER BY). The
--     no-method row crowds out queue slots for engineers who DO have
--     methods. Eventually the no-method row dead-letters after 5
--     attempts even though it never even talked to Cashfree.
--
-- (2) HIGH — stale VPA at dispatch time.
--     Current picker uses COALESCE(payout_method_id, default-method)
--     which only late-binds when the captured method_id was NULL at
--     enqueue. If the engineer UPDATED their VPA between enqueue and
--     dispatch (e.g. escrow waits 48h while engineer rotates accounts),
--     the OLD captured method_id wins and Cashfree dispatches to the
--     stale VPA.
--
-- (3) HIGH — no operator surface for the no-method backlog.
--     Founder dashboard had no query to surface "queued payouts that
--     can't fire because engineer hasn't attached a method". Engineers
--     accumulated unpaid payouts silently.
--
-- Fix:
--   • Picker now FILTERS no-method rows (won't claim them, won't bump
--     attempts) AND re-resolves method_id to the engineer's CURRENT
--     default at pick time (was COALESCE).
--   • New RPC founder_engineer_payouts_no_method_summary() surfaces
--     stuck engineers with totals + oldest-queued timestamp.

-- ---------------------------------------------------------------------
-- 1. Picker — skip no-method rows + re-resolve method to current default
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pick_engineer_payouts_for_processing(
  p_limit int DEFAULT 25
)
RETURNS TABLE (
  payout_id        uuid,
  engineer_user_id uuid,
  amount_paise     bigint,
  attempts         integer,
  method_id        uuid,
  method_kind      text,
  vpa              text,
  bank_account_holder text,
  bank_name        text,
  ifsc             text,
  account_number_encrypted text,
  account_number_last4 text,
  razorpay_contact_id text,
  razorpay_fund_account_id text,
  job_number       text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_lim int := GREATEST(1, LEAST(p_limit, 100));
BEGIN
  RETURN QUERY
  WITH claimed AS (
    SELECT p.id
      FROM public.engineer_payouts p
     WHERE p.status = 'queued'
       -- Round 468 fix #1: skip rows where the engineer has no default
       -- method on file. Worker would otherwise burn attempts on these
       -- forever (dispatch RPC reverts to 'queued' on no_method).
       -- They re-enter the pickable set the moment the engineer
       -- attaches a method via set_engineer_payout_method.
       AND EXISTS (
         SELECT 1 FROM public.engineer_payout_methods m
          WHERE m.user_id = p.engineer_user_id
            AND m.is_default = true
       )
     ORDER BY p.queued_at
     FOR UPDATE SKIP LOCKED
     LIMIT v_lim
  ),
  resolved AS (
    UPDATE public.engineer_payouts p
       SET status = 'processing',
           attempts = p.attempts + 1,
           last_attempt_at = now(),
           -- Round 468 fix #2: ALWAYS re-resolve method_id to the
           -- engineer's CURRENT default at pick time (was COALESCE,
           -- which kept the stale ID captured at enqueue). If the
           -- engineer rotated VPAs while the payout sat in queue,
           -- Cashfree now dispatches to the NEW VPA.
           payout_method_id = (
             SELECT id FROM public.engineer_payout_methods m
              WHERE m.user_id = p.engineer_user_id
                AND m.is_default = true
              LIMIT 1
           )
      FROM claimed c
     WHERE p.id = c.id
    RETURNING p.id, p.engineer_user_id, p.amount_paise, p.attempts,
              p.payout_method_id, p.repair_job_id
  )
  SELECT
    r.id,
    r.engineer_user_id,
    r.amount_paise,
    r.attempts,
    r.payout_method_id AS method_id,
    m.kind AS method_kind,
    m.vpa,
    m.bank_account_holder,
    m.bank_name,
    m.ifsc,
    m.account_number_encrypted,
    m.account_number_last4,
    m.razorpay_contact_id,
    m.razorpay_fund_account_id,
    rj.job_number
  FROM resolved r
  LEFT JOIN public.engineer_payout_methods m ON m.id = r.payout_method_id
  LEFT JOIN public.repair_jobs rj ON rj.id = r.repair_job_id;
END
$$;

REVOKE EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(int) TO service_role;

COMMENT ON FUNCTION public.pick_engineer_payouts_for_processing(int) IS
  'Round 468: picker skips rows with no current default method (no_method spin-loop fix) and re-resolves method to engineer''s current default at pick time (stale-VPA-at-dispatch fix).';

-- ---------------------------------------------------------------------
-- 2. Founder no-method dashboard — surface the stuck backlog
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_engineer_payouts_no_method_summary()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email   text,
  engineer_name    text,
  queued_count     bigint,
  total_paise      bigint,
  oldest_queued_at timestamptz,
  newest_queued_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    ep.engineer_user_id,
    pr.email,
    pr.full_name,
    count(*)::bigint                     AS queued_count,
    coalesce(sum(ep.amount_paise), 0)::bigint AS total_paise,
    min(ep.queued_at)                    AS oldest_queued_at,
    max(ep.queued_at)                    AS newest_queued_at
  FROM public.engineer_payouts ep
  LEFT JOIN public.profiles pr ON pr.id = ep.engineer_user_id
  WHERE ep.status = 'queued'
    AND NOT EXISTS (
      SELECT 1 FROM public.engineer_payout_methods m
       WHERE m.user_id = ep.engineer_user_id
         AND m.is_default = true
    )
  GROUP BY ep.engineer_user_id, pr.email, pr.full_name
  ORDER BY oldest_queued_at ASC NULLS LAST;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_payouts_no_method_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_payouts_no_method_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_engineer_payouts_no_method_summary() IS
  'Round 468: founder dashboard query — engineers with queued payouts but no default method on file. Use to nag those engineers to attach UPI/bank in the app.';

-- ---------------------------------------------------------------------
-- 3. Reset stale engineer-keyed beneId cache.
--    Audit-5 finding (HIGH): Cashfree beneId was derived from
--    engineer_user_id, so all of an engineer's methods shared one
--    beneId locked to the FIRST VPA registered. Round 468 edge fn
--    switches to method-keyed derivation. Existing cached values
--    in razorpay_contact_id point at the old engineer-keyed beneIds
--    which are now stale (mapped to the wrong VPA). Null them out
--    so the new code re-adds beneficiaries via Cashfree's
--    addBeneficiary (idempotent — Cashfree returns "already exists"
--    on a duplicate beneId and the edge fn handles it).
-- ---------------------------------------------------------------------

UPDATE public.engineer_payout_methods
   SET razorpay_contact_id = NULL,
       razorpay_fund_account_id = NULL
 WHERE razorpay_contact_id IS NOT NULL
    OR razorpay_fund_account_id IS NOT NULL;

-- Surface the count in deploy logs.
DO $$
DECLARE
  v_cleared int;
BEGIN
  GET DIAGNOSTICS v_cleared = ROW_COUNT;
  RAISE NOTICE 'Round 468: cleared % stale engineer-keyed beneId rows. Edge fn will re-add per-method beneficiaries on next dispatch.', v_cleared;
END $$;
