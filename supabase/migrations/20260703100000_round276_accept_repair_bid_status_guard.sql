-- Round 276 — close a TOCTOU race in accept_repair_bid.
--
-- The 20260504110000 version of accept_repair_bid does a SELECT (with
-- FOR UPDATE OF rj — locks the repair_jobs row) followed by three
-- UPDATEs. The UPDATEs filter only by `id = p_bid_id` (no status
-- guard).
--
-- Race scenario:
--   1. Hospital taps Accept on engineer A's bid.
--   2. RPC SELECT runs, reads v_bid (status='pending'), locks
--      repair_jobs row.
--   3. CONCURRENTLY (different transaction): engineer A calls
--      withdrawBid on their own bid. Postgres MVCC lets this
--      transaction proceed because withdrawBid filters
--      `eq("engineer_user_id", uid)` + `eq("id", bidId)` and
--      doesn't lock repair_jobs. It updates bid.status = 'withdrawn'
--      and commits.
--   4. RPC's UPDATE at line 63 still fires: WHERE id = p_bid_id.
--      No status filter. The withdrawn bid flips to 'accepted'.
--   5. Hospital is now contracted with an engineer who explicitly
--      withdrew. Engineer is surprised. Notifications go out.
--
-- Fix: add `AND status = 'pending'` to the UPDATE. If 0 rows match
-- (concurrent withdraw won), abort the transaction with the same
-- "Only pending bids can be accepted" error the SELECT-check would
-- have raised. The OUT count from the UPDATE drives the check via
-- ROW_COUNT.
--
-- Side note: the FOR UPDATE OF rj already serializes two concurrent
-- ACCEPTS against the same job. The race that escapes that gate is
-- specifically accept vs. withdraw on the SAME bid — withdraw
-- doesn't touch repair_jobs so it doesn't compete for the rj lock.

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

  -- TOCTOU guard: the SELECT above read v_bid.status='pending', but a
  -- concurrent withdrawBid by the engineer could flip it between the
  -- SELECT and this UPDATE (withdrawBid doesn't touch repair_jobs so
  -- it escapes our FOR UPDATE OF rj lock). Match `status='pending'`
  -- explicitly here; if the row was withdrawn we get 0 rows updated
  -- and raise the same "Only pending bids can be accepted" error
  -- the SELECT path would have surfaced.
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

  RETURN v_job;
END;
$$;

ALTER FUNCTION public.accept_repair_bid(uuid) OWNER TO postgres;
