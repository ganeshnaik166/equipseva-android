-- Round 234 — server-side CHECK constraints for bid amount + review text.
--
-- Client-side validators block these today (require(amount in 1..MAX_BID),
-- review trim/take(1000)), but a direct REST call or a future client
-- regression could land an invalid row. Promote those bounds to DB
-- constraints so the row never makes it in.
--
-- Bid: amount_rupees must be > 0 and <= 10_000_000 (₹1 crore — covers
-- realistic complex repairs, blocks obvious garbage / overflow).
-- Review: hospital_review and engineer_review capped at 1000 chars
-- to match the client-side trim (PR #609).
--
-- NOT VALID + VALIDATE pattern: the ADD is cheap (no row scan), the
-- VALIDATE pass surfaces any existing-row violation as a migration
-- failure so ops can clean up before we lock the constraint in.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'repair_job_bids_amount_in_range'
      AND conrelid = 'public.repair_job_bids'::regclass
  ) THEN
    ALTER TABLE public.repair_job_bids
      ADD CONSTRAINT repair_job_bids_amount_in_range
      CHECK (amount_rupees > 0 AND amount_rupees <= 10000000) NOT VALID;
    ALTER TABLE public.repair_job_bids
      VALIDATE CONSTRAINT repair_job_bids_amount_in_range;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'repair_jobs_hospital_review_len'
      AND conrelid = 'public.repair_jobs'::regclass
  ) THEN
    ALTER TABLE public.repair_jobs
      ADD CONSTRAINT repair_jobs_hospital_review_len
      CHECK (hospital_review IS NULL OR char_length(hospital_review) <= 1000) NOT VALID;
    ALTER TABLE public.repair_jobs
      VALIDATE CONSTRAINT repair_jobs_hospital_review_len;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'repair_jobs_engineer_review_len'
      AND conrelid = 'public.repair_jobs'::regclass
  ) THEN
    ALTER TABLE public.repair_jobs
      ADD CONSTRAINT repair_jobs_engineer_review_len
      CHECK (engineer_review IS NULL OR char_length(engineer_review) <= 1000) NOT VALID;
    ALTER TABLE public.repair_jobs
      VALIDATE CONSTRAINT repair_jobs_engineer_review_len;
  END IF;
END$$;
