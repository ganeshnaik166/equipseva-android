-- Round 421 — restore the per-job escrow INSERT in accept_repair_bid.
--
-- Round 276 (20260703100000_round276_accept_repair_bid_status_guard.sql)
-- closed a TOCTOU race between accept_repair_bid and the engineer-side
-- withdrawBid by adding `AND status = 'pending'` to the bid UPDATE.
-- That fix is correct.
--
-- BUT: when Round 276 rewrote accept_repair_bid, it copied the body
-- from the 20260504110000 version (pre-v2.1) instead of the
-- 20260520100000_v21_per_job_escrow_schema version. That older body
-- doesn't INSERT the public.repair_job_escrow row in 'pending' state
-- after the repair_jobs UPDATE. The v2.1 version did.
--
-- Net result on prod since 2026-07-03: every accept_repair_bid call
-- transitions the job to 'assigned' but leaves NO escrow row. The
-- hospital's "Pay ₹10 to escrow" CTA — gated client-side on
-- `escrow != null` (RepairJobDetailScreen.kt:582) — never renders. The
-- job is permanently stuck at 'assigned'; the engineer never gets
-- paid; the hospital has no way to release the funds without manual
-- intervention. Discovered live during the v0.2.1 ₹10 E2E demo on
-- 2026-06-02: hospital posted RPR-00034, hospital accepted Testy's
-- bid, status went to 'assigned' — and the entire Escrow section of
-- the job-detail screen was missing.
--
-- Fix: re-add the INSERT INTO public.repair_job_escrow block + the
-- companion repair_job_escrow_events 'created' audit row at the end of
-- accept_repair_bid, identical to the v2.1 version. Idempotent via
-- ON CONFLICT (repair_job_id) DO NOTHING — a re-accept after an admin
-- reset doesn't double-insert.
--
-- Live-patched in prod via the Management API SQL endpoint on
-- 2026-06-02 to unblock the demo; this migration captures the same
-- fix in source so supabase db reset / a fresh env doesn't reintroduce
-- the bug.
--
-- Round 276's TOCTOU guard (AND status = 'pending' on the bid UPDATE)
-- is preserved verbatim — this is a strict superset.

CREATE OR REPLACE FUNCTION public.accept_repair_bid(p_bid_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_bid record;
  v_engineer_id uuid;
  v_job jsonb;
  v_accepted_count int;
  v_escrow_id uuid;
BEGIN
  SELECT
      b.id,
      b.repair_job_id,
      b.engineer_user_id,
      b.amount_rupees,
      b.status,
      rj.hospital_user_id,
      rj.status AS job_status
    INTO v_bid
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
   WHERE b.id = p_bid_id
   FOR UPDATE OF rj;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bid not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_bid.hospital_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the hospital owner can accept bids' USING ERRCODE = '42501';
  END IF;

  IF v_bid.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending bids can be accepted' USING ERRCODE = '22023';
  END IF;

  IF v_bid.job_status <> 'requested' THEN
    RAISE EXCEPTION 'Job is no longer open for bids' USING ERRCODE = '22023';
  END IF;

  SELECT e.id INTO v_engineer_id
    FROM public.engineers e
   WHERE e.user_id = v_bid.engineer_user_id
   LIMIT 1;

  IF v_engineer_id IS NULL THEN
    RAISE EXCEPTION 'Engineer profile not found for bid' USING ERRCODE = 'P0002';
  END IF;

  -- Round 276 TOCTOU guard: explicit `status = 'pending'` clause closes
  -- the withdraw-vs-accept race. Do NOT remove — see r276 migration.
  UPDATE public.repair_job_bids
     SET status = 'accepted',
         updated_at = now()
   WHERE id = p_bid_id
     AND status = 'pending';

  GET DIAGNOSTICS v_accepted_count = ROW_COUNT;
  IF v_accepted_count = 0 THEN
    RAISE EXCEPTION 'Only pending bids can be accepted' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_bids
     SET status = 'rejected',
         updated_at = now()
   WHERE repair_job_id = v_bid.repair_job_id
     AND id <> p_bid_id
     AND status = 'pending';

  UPDATE public.repair_jobs
     SET engineer_id = v_engineer_id,
         status = 'assigned',
         contracted_amount_rupees = v_bid.amount_rupees,
         updated_at = now()
   WHERE id = v_bid.repair_job_id
   RETURNING to_jsonb(repair_jobs.*) INTO v_job;

  -- PR-D4 / v2.1: escrow row at quote-accept. Restored after Round 276
  -- accidentally dropped it. Idempotent — a re-accept after an admin
  -- reset leaves any existing escrow row untouched. Pay-in flips
  -- status from 'pending' to 'held' later via the Razorpay verify
  -- edge function.
  INSERT INTO public.repair_job_escrow (
    repair_job_id, hospital_user_id, engineer_user_id, amount_rupees, status
  )
  VALUES (
    v_bid.repair_job_id, v_bid.hospital_user_id, v_bid.engineer_user_id,
    v_bid.amount_rupees, 'pending'
  )
  ON CONFLICT (repair_job_id) DO NOTHING
  RETURNING id INTO v_escrow_id;

  IF v_escrow_id IS NOT NULL THEN
    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
    VALUES (v_escrow_id, 'created', v_bid.hospital_user_id,
            jsonb_build_object('amount_rupees', v_bid.amount_rupees));
  END IF;

  RETURN v_job;
END;
$$;

ALTER FUNCTION public.accept_repair_bid(uuid) OWNER TO postgres;
