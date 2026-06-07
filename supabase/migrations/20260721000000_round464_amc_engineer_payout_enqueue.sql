-- Round 464 — CRITICAL fix: AMC visit engineer payouts were never queued.
--
-- Background:
--   • Regular repair jobs: hospital pays via Razorpay → escrow row →
--     engineer marks complete → 48h timer or hospital tap-confirm →
--     escrow flips 'held'→'released' → enqueue_engineer_payout_on_
--     escrow_release_trg INSERTs into engineer_payouts → cron drains.
--   • AMC visits (repair_jobs.kind='maintenance'): hospital prepaid the
--     AMC contract; per-visit cost debits amc_payment_pool via
--     debit_amc_pool_on_visit_complete trigger. BUT no trigger ever
--     queued an engineer_payouts row — engineer's earnings UI showed
--     85% of per-visit cost, but the engineer NEVER received the money.
--     Platform silently kept 100% of every AMC visit fee since round 234
--     (~2026-06-26).
--
-- Fix:
--   1. New trigger fires AFTER INSERT ON amc_payment_pool when
--      ledger_kind='debit' — the debit row IS the signal that an AMC
--      visit was paid for (the prior debit trigger has already
--      validated the visit + contract, so this is a clean fan-out).
--   2. Trigger looks up the source visit, the engineer's auth.users.id
--      (via engineers.user_id), the engineer's default payout method,
--      and INSERTs into engineer_payouts with status='queued'.
--   3. amount_paise = round(debit.amount_rupees * 0.85, 2) * 100
--      matches the 85/15 split shown in engineer_my_amc_earnings RPC
--      (residual-take pattern from round 457 keeps it drift-free).
--   4. ON CONFLICT (repair_job_id) DO NOTHING — engineer_payouts has
--      UNIQUE(repair_job_id) so accidental re-fire is safe.
--   5. Backfill: scan all historical maintenance visits that have a
--      debit row but no engineer_payouts row. INSERT them as queued so
--      the next worker tick drains them through Cashfree. Engineers
--      finally get their back-owed AMC commission.
--
-- Safety:
--   • Skip when engineer_id is NULL (defensive — should never happen for
--     completed maintenance visits but the debit trigger doesn't enforce).
--   • Skip when computed payout_paise <= 0 (e.g. last-of-cycle true-up
--     with zero remaining envelope).
--   • payout_method_id NULL is OK — same pattern as regular jobs;
--     surfaces in admin dashboard "engineer hasn't attached method".

-- ---------------------------------------------------------------------
-- 1. Trigger function
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_visit          public.repair_jobs%ROWTYPE;
  v_engineer_uid   uuid;
  v_method_id      uuid;
  v_payout_rupees  numeric(10,2);
  v_payout_paise   bigint;
BEGIN
  -- Only act on debit rows that point at a visit.
  IF NEW.ledger_kind <> 'debit' OR NEW.source_visit_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fetch the visit. Defensive: a malformed debit row that points at
  -- a non-existent visit shouldn't bubble.
  SELECT * INTO v_visit
    FROM public.repair_jobs
   WHERE id = NEW.source_visit_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  -- Only AMC maintenance visits — defensive belt-and-braces; the debit
  -- trigger already constrains to this, but a future code path could
  -- INSERT debit rows directly.
  IF v_visit.kind <> 'maintenance' OR v_visit.amc_contract_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- engineer_id (engineers.id) → auth.users.id mapping.
  SELECT e.user_id INTO v_engineer_uid
    FROM public.engineers e
   WHERE e.id = v_visit.engineer_id;
  IF v_engineer_uid IS NULL THEN
    -- Visit was pre-assigned a non-existent engineer or had its
    -- engineer purged. Nothing we can do — log and skip.
    RAISE WARNING 'enqueue_engineer_payout_on_amc_visit_debit: visit % has no resolvable engineer_user_id (engineer_id=%)',
      v_visit.id, v_visit.engineer_id;
    RETURN NEW;
  END IF;

  -- 85/15 residual split (matches engineer_my_amc_earnings RPC from
  -- round 457).
  v_payout_rupees := round(NEW.amount_rupees * 0.85, 2);
  v_payout_paise := (v_payout_rupees * 100)::bigint;

  IF v_payout_paise <= 0 THEN
    -- Last-of-cycle true-up with zero remaining envelope, or a debit
    -- of 0 — nothing to pay.
    RETURN NEW;
  END IF;

  -- Engineer's default payout method (NULL is OK — admin dashboard
  -- surfaces these).
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

REVOKE EXECUTE ON FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit() FROM PUBLIC;

COMMENT ON FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit() IS
  'Round 464 — fires after every amc_payment_pool debit row to queue the engineer''s 85% share. Closes the silent gap where AMC visit engineers earned in UI but never received money.';

DROP TRIGGER IF EXISTS enqueue_engineer_payout_on_amc_visit_debit_trg
  ON public.amc_payment_pool;
CREATE TRIGGER enqueue_engineer_payout_on_amc_visit_debit_trg
  AFTER INSERT ON public.amc_payment_pool
  FOR EACH ROW
  WHEN (NEW.ledger_kind = 'debit' AND NEW.source_visit_id IS NOT NULL)
  EXECUTE FUNCTION public.enqueue_engineer_payout_on_amc_visit_debit();

-- ---------------------------------------------------------------------
-- 2. Backfill — every historical AMC visit that has a debit row but
--    no engineer_payouts row. Engineers get back-owed commission
--    queued; the */5 cron drains them through Cashfree.
--
-- Idempotency: the ON CONFLICT (repair_job_id) DO NOTHING on the
-- target table means re-running this migration is safe.
-- ---------------------------------------------------------------------

INSERT INTO public.engineer_payouts (
  repair_job_id, engineer_user_id, escrow_id,
  payout_method_id, amount_paise, status
)
SELECT
  rj.id,
  e.user_id,
  NULL,
  (SELECT m.id FROM public.engineer_payout_methods m
    WHERE m.user_id = e.user_id AND m.is_default = true LIMIT 1),
  (round(p.amount_rupees * 0.85, 2) * 100)::bigint,
  'queued'
FROM public.amc_payment_pool p
JOIN public.repair_jobs rj
  ON rj.id = p.source_visit_id
JOIN public.engineers e
  ON e.id = rj.engineer_id
WHERE p.ledger_kind = 'debit'
  AND rj.kind = 'maintenance'
  AND rj.amc_contract_id IS NOT NULL
  AND rj.status::text = 'completed'
  AND rj.engineer_id IS NOT NULL
  AND e.user_id IS NOT NULL
  AND round(p.amount_rupees * 0.85, 2) > 0
  AND NOT EXISTS (
    SELECT 1 FROM public.engineer_payouts ep
     WHERE ep.repair_job_id = rj.id
  )
ON CONFLICT (repair_job_id) DO NOTHING;

-- Surface a NOTICE with the backfill count so the deploy log makes it
-- obvious how many engineer payouts just got queued. Founder reads
-- the deploy log after `supabase db push` and can sanity-check.
DO $$
DECLARE
  v_queued_count int;
  v_queued_total_paise bigint;
BEGIN
  SELECT count(*), coalesce(sum(amount_paise), 0)
    INTO v_queued_count, v_queued_total_paise
    FROM public.engineer_payouts ep
    JOIN public.repair_jobs rj ON rj.id = ep.repair_job_id
   WHERE rj.kind = 'maintenance'
     AND ep.status = 'queued'
     AND ep.queued_at > now() - interval '1 minute';
  RAISE NOTICE 'Round 464 backfill queued % AMC engineer payouts totalling ₹%',
    v_queued_count,
    (v_queued_total_paise::numeric / 100)::text;
END;
$$;
