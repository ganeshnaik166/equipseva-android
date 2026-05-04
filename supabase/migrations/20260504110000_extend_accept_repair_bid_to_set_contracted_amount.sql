-- Extend accept_repair_bid (latest definition in 20260501100000) to
-- also stamp `repair_jobs.contracted_amount_rupees` from the accepted
-- bid's amount_rupees. This is the v2 semantic: "contracted price"
-- starts equal to the bid and may be revised later via the
-- propose_cost_revision / decide_cost_revision flow. Without this
-- backfill on accept, the new column would stay NULL until the first
-- revision lands, breaking commission/invoice math downstream.
--
-- The function owner stays postgres so the new
-- repair_jobs_contracted_amount_guard recognises this as an internal
-- write (session_user='postgres' bypass).

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

  UPDATE public.repair_job_bids
     SET status = 'accepted',
         updated_at = now()
   WHERE id = p_bid_id;

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
