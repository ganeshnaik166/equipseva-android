-- v2 introduces a "contracted price" semantic on repair_jobs that's
-- distinct from the original bid amount. Today the bid amount in
-- repair_job_bids is the contractual price; v2 lets engineers propose
-- revised quotes after they arrive on-site and find more issues, so
-- the contracted price drifts away from the original bid.
--
--   * `repair_job_bids.amount_rupees` keeps its meaning ("what the
--     engineer originally bid") — never mutated after acceptance.
--   * `repair_jobs.contracted_amount_rupees` (new) is the live
--     authoritative price. Set on bid acceptance to match the bid;
--     overwritten by `decide_cost_revision` when a revised quote is
--     approved by the hospital. All commission / payout / invoice
--     math reads this column.
--
-- Column-level guard mirrors `repair_jobs_rating_column_guard` style:
-- only SECURITY DEFINER + owner=postgres callers (the gated RPCs) may
-- write the column; direct authenticated UPDATEs are blocked.

ALTER TABLE public.repair_jobs
  ADD COLUMN IF NOT EXISTS contracted_amount_rupees numeric(10,2);

-- One-time backfill: stamp accepted-bid amount onto historical jobs
-- that pre-date this column. Idempotent — re-runs are no-ops once the
-- column is filled.
UPDATE public.repair_jobs rj
   SET contracted_amount_rupees = b.amount_rupees
  FROM public.repair_job_bids b
 WHERE b.repair_job_id = rj.id
   AND b.status::text = 'accepted'
   AND rj.contracted_amount_rupees IS NULL;

CREATE OR REPLACE FUNCTION public.repair_jobs_contracted_amount_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- Service role + direct postgres (SECURITY DEFINER bypass) skip
  -- the check entirely. Founder + admin also bypass for ops fixes.
  IF v_caller_role = 'service_role' OR session_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF NEW.contracted_amount_rupees IS DISTINCT FROM OLD.contracted_amount_rupees THEN
    RAISE EXCEPTION
      'contracted_amount_rupees can only be written via accept_repair_bid / decide_cost_revision'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.repair_jobs_contracted_amount_guard() OWNER TO postgres;

DROP TRIGGER IF EXISTS repair_jobs_contracted_amount_guard_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_contracted_amount_guard_trg
  BEFORE UPDATE OF contracted_amount_rupees ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.repair_jobs_contracted_amount_guard();

REVOKE ALL ON FUNCTION public.repair_jobs_contracted_amount_guard() FROM PUBLIC;
