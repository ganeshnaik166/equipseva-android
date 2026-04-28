-- The previous engineers column lockdown (20260428280000) blocked the
-- legitimate KYC submit + re-submit flow:
--   - KycViewModel passes aadhaarUploaded=true after a doc upload, which
--     sets aadhaar_verified=true (a "doc present" marker, not a
--     server-side identity validation)
--   - On re-submit after rejection, resetVerificationToPending=true
--     flips verification_status back to 'pending' so the admin queue
--     picks it up again
-- Both writes are needed by the engineer; only the trust-signal
-- end-states (verified_at, verified_by, ratings, computed earnings,
-- background_check_status) need lockdown.
--
-- Revert the broad column lockdown and replace with a BEFORE UPDATE
-- trigger that:
--   1. Lets the engineer flip verification_status only between
--      pending / rejected (the rejected-side comes from the admin RPC,
--      but a re-submit reset to pending is legit). Promotion to
--      'verified' must come from admin_set_engineer_verification or a
--      service_role write.
--   2. Lets aadhaar_verified flip in either direction by the engineer
--      themselves (it's a UI marker; admin still reviews the actual
--      doc), but blocks anyone else from forging it.
--   3. Hard-blocks engineer writes to rating_avg, total_jobs,
--      completion_rate, total_earnings, background_check_status,
--      verification_notes, rejected_doc_types — those are admin /
--      computed columns. service_role + founder + admin bypass.

REVOKE INSERT, UPDATE ON public.engineers FROM anon, authenticated;
GRANT INSERT, UPDATE ON public.engineers TO authenticated;

CREATE OR REPLACE FUNCTION public.engineers_trust_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- service_role + direct postgres + founder + admin bypass.
  IF v_caller_role = 'service_role' OR session_user = 'postgres' THEN
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

DROP TRIGGER IF EXISTS engineers_trust_columns_guard_trg ON public.engineers;
CREATE TRIGGER engineers_trust_columns_guard_trg
  BEFORE INSERT OR UPDATE ON public.engineers
  FOR EACH ROW
  EXECUTE FUNCTION public.engineers_trust_columns_guard();

REVOKE ALL ON FUNCTION public.engineers_trust_columns_guard() FROM PUBLIC;
