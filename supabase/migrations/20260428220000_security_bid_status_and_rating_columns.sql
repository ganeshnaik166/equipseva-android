-- Two findings from the bidding + rating audit.
--
-- 1. repair_job_bids UPDATE policy let an engineer mutate their own
--    pending bid AND set status to anything in the same statement.
--    USING gated on status='pending', but WITH CHECK only enforced the
--    engineer-match. So the engineer could UPDATE … SET status='accepted'
--    on their own bid and bypass the hospital's accept_repair_bid RPC,
--    self-promoting to assigned. Tighten WITH CHECK to also require
--    status stays 'pending'. Promotion to accepted/rejected is the
--    accept_repair_bid RPC's job (SECURITY DEFINER).
--
-- 2. repair_jobs UPDATE is gated per-row to "involved parties" but the
--    RLS doesn't restrict which columns each party can change. The
--    hospital could write engineer_rating / engineer_review (the
--    engineer's rating of the hospital) and self-grade a positive
--    review of themselves. Same risk in reverse for the engineer
--    writing hospital_rating. Add a BEFORE UPDATE trigger that
--    requires the side-specific identity match + status='completed'
--    whenever the rating columns change.

DROP POLICY IF EXISTS "Engineers update own pending bid" ON public.repair_job_bids;

CREATE POLICY "Engineers update own pending bid"
  ON public.repair_job_bids
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = engineer_user_id AND status = 'pending')
  WITH CHECK (auth.uid() = engineer_user_id AND status = 'pending');

CREATE OR REPLACE FUNCTION public.repair_jobs_rating_column_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user_id uuid;
BEGIN
  -- Hospital_rating + hospital_review: hospital's rating of the engineer.
  -- Only hospital_user_id may change them, and only on completed jobs.
  IF NEW.hospital_rating IS DISTINCT FROM OLD.hospital_rating
     OR NEW.hospital_review IS DISTINCT FROM OLD.hospital_review THEN
    IF auth.uid() IS DISTINCT FROM NEW.hospital_user_id THEN
      RAISE EXCEPTION 'Only the hospital can write hospital_rating / hospital_review';
    END IF;
    IF NEW.status::text <> 'completed' THEN
      RAISE EXCEPTION 'Ratings can only be written on completed jobs (status=%)', NEW.status;
    END IF;
  END IF;

  -- Engineer_rating + engineer_review: engineer's rating of the hospital.
  -- Only the engineer assigned to the job (resolved via engineers.user_id)
  -- may change them, and only on completed jobs.
  IF NEW.engineer_rating IS DISTINCT FROM OLD.engineer_rating
     OR NEW.engineer_review IS DISTINCT FROM OLD.engineer_review THEN
    SELECT e.user_id INTO v_engineer_user_id
      FROM public.engineers e
      WHERE e.id = NEW.engineer_id;
    IF auth.uid() IS DISTINCT FROM v_engineer_user_id THEN
      RAISE EXCEPTION 'Only the assigned engineer can write engineer_rating / engineer_review';
    END IF;
    IF NEW.status::text <> 'completed' THEN
      RAISE EXCEPTION 'Ratings can only be written on completed jobs (status=%)', NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS repair_jobs_rating_column_guard_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_rating_column_guard_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.repair_jobs_rating_column_guard();

REVOKE ALL ON FUNCTION public.repair_jobs_rating_column_guard() FROM PUBLIC;
