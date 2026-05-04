-- Bug: PR #250 (rating aggregator) and PR #251 (revised-quote) both
-- ship broken in production because two BEFORE-UPDATE guards on
-- public.engineers and public.repair_jobs only honor the
-- session_user='postgres' branch of the SECURITY DEFINER bypass — but
-- inside a SECDEF function called from PostgREST, Postgres switches
-- current_user to postgres while session_user stays as the original
-- connection role (authenticator). So every legit SECDEF write hits
-- the guard's RAISE 42501 path and the parent transaction rolls back.
--
-- Symptoms in prod once 20260503100000 + 20260504100000 are deployed:
--   - Hospital submits a rating → recompute_engineer_rating_aggregates
--     fires → UPDATE engineers SET rating_avg / total_jobs → blocked
--     by engineers_trust_columns_guard → 42501 → rating submit fails.
--   - Hospital accepts a bid → accept_repair_bid SECDEF stamps
--     contracted_amount_rupees → blocked by
--     repair_jobs_contracted_amount_guard → 42501 → bid acceptance
--     fails. Same story for decide_cost_revision.
--
-- Fix: also bypass the guards when current_user='postgres'. This is
-- exactly the same patch we applied to profiles_verification_columns_guard
-- in 20260429110000 — engineers + contracted_amount guards were missed.
-- Anon + authenticated client writes still hit current_user='authenticated'
-- / 'anon' and remain blocked by the rest of the guard logic.

-- ============================================================
-- Patch 1: engineers_trust_columns_guard
-- ============================================================
CREATE OR REPLACE FUNCTION public.engineers_trust_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- service_role + direct postgres + SECDEF-via-postgres + founder + admin bypass.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Engineer can only flip verification_status into 'pending' (resubmit)
  -- or leave it unchanged. 'verified' / 'rejected' are admin-only end
  -- states.
  IF TG_OP = 'UPDATE' AND NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'verification_status flip to % requires admin', NEW.verification_status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Trust + computed columns: engineer can never change them. Use
  -- IS DISTINCT FROM for null-safe comparison.
  IF TG_OP = 'UPDATE' THEN
    IF NEW.rating_avg IS DISTINCT FROM OLD.rating_avg
       OR NEW.total_jobs IS DISTINCT FROM OLD.total_jobs
       OR NEW.completion_rate IS DISTINCT FROM OLD.completion_rate
       OR NEW.total_earnings IS DISTINCT FROM OLD.total_earnings
       OR NEW.background_check_status IS DISTINCT FROM OLD.background_check_status
       OR NEW.verification_notes IS DISTINCT FROM OLD.verification_notes
       OR NEW.rejected_doc_types IS DISTINCT FROM OLD.rejected_doc_types
       OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'cannot modify admin / computed engineers columns'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- INSERT must come in with the trust columns at their defaults — no
  -- caller-set rating boosts on creation, no pre-stamped 'verified'.
  IF TG_OP = 'INSERT' THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'engineers row must start at verification_status=pending'
        USING ERRCODE = '42501';
    END IF;
    IF coalesce(NEW.rating_avg, 0) <> 0
       OR coalesce(NEW.total_jobs, 0) <> 0
       OR coalesce(NEW.completion_rate, 0) <> 0
       OR coalesce(NEW.total_earnings, 0) <> 0 THEN
      RAISE EXCEPTION 'engineers stats must start at zero'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.engineers_trust_columns_guard() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.engineers_trust_columns_guard() FROM PUBLIC;

-- ============================================================
-- Patch 2: repair_jobs_contracted_amount_guard
-- ============================================================
CREATE OR REPLACE FUNCTION public.repair_jobs_contracted_amount_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- Service role + direct postgres + SECDEF-via-postgres bypass.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
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
REVOKE ALL ON FUNCTION public.repair_jobs_contracted_amount_guard() FROM PUBLIC;

-- ============================================================
-- Backfill: re-run the rating aggregator now that the guard accepts
-- SECDEF writes. Without this, engineers whose ratings were submitted
-- between PR #250 deploy and this hotfix have wrong (or zero)
-- rating_avg / total_jobs values.
-- ============================================================
WITH agg AS (
  SELECT engineer_id,
         COALESCE(AVG(hospital_rating)::numeric(10,2), 0) AS avg_rating,
         COUNT(*)                                          AS total
    FROM public.repair_jobs
   WHERE hospital_rating IS NOT NULL
     AND status::text = 'completed'
     AND engineer_id IS NOT NULL
   GROUP BY engineer_id
)
UPDATE public.engineers e
   SET rating_avg = agg.avg_rating,
       total_jobs = agg.total
  FROM agg
 WHERE e.id = agg.engineer_id;

-- contracted_amount_rupees backfill from the existing column-add
-- migration is idempotent and was already run; nothing to re-do here.
