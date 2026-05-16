-- Round 275 — server-side CHECK constraints on repair_jobs rating columns.
--
-- The client (`submitRating` in SupabaseRepairJobRepository) validates
-- `require(stars in 1..5)` and trims review text to 1000 chars before
-- the UPDATE. Server-side the columns are unbounded:
--
--   repair_jobs.hospital_rating  smallint     (no CHECK)
--   repair_jobs.engineer_rating  smallint     (no CHECK)
--   repair_jobs.hospital_review  text         (no CHECK)
--   repair_jobs.engineer_review  text         (no CHECK)
--
-- A direct PostgREST PATCH call from a malicious or buggy client
-- bypasses the on-device validator and could:
--   • Write `hospital_rating = -1` or `9999` — corrupting the
--     engineer rating aggregator (round_robin AVG over completed jobs).
--   • Write a 10MB review — bloating the row + every directory fetch
--     that returns this engineer.
--
-- Add CHECK constraints to enforce the same bounds server-side. The
-- bid-status / rating column-level grant trigger from PR-D26 was the
-- only line of defense; this adds a real CHECK that fires even if the
-- trigger is bypassed.
--
-- DROP CONSTRAINT IF EXISTS / ADD CONSTRAINT IF NOT EXISTS pattern
-- so the migration is safe to re-apply.

ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_hospital_rating_range;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_hospital_rating_range
  CHECK (hospital_rating IS NULL OR hospital_rating BETWEEN 1 AND 5);

ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_engineer_rating_range;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_engineer_rating_range
  CHECK (engineer_rating IS NULL OR engineer_rating BETWEEN 1 AND 5);

ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_hospital_review_length;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_hospital_review_length
  CHECK (hospital_review IS NULL OR char_length(hospital_review) <= 2000);

ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_engineer_review_length;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_engineer_review_length
  CHECK (engineer_review IS NULL OR char_length(engineer_review) <= 2000);

COMMENT ON CONSTRAINT repair_jobs_hospital_rating_range ON public.repair_jobs IS
  'Round 275 — pin 1..5 range matching the client require() check. Aggregator '
  'trigger averages over these, so out-of-range writes corrupt rating_avg.';
