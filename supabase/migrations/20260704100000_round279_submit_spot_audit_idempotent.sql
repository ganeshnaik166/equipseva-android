-- Round 279 — make submit_spot_audit idempotent on double-tap.
--
-- spot_audit_responses.invitation_id is UNIQUE. The original RPC
-- (20260619100000_v21_spot_audits.sql) does:
--   1. SELECT ... FOR UPDATE on the invitation row
--   2. INSERT into spot_audit_responses (invitation_id, rating, feedback)
--      RETURNING id
--
-- The FOR UPDATE serializes two concurrent calls on the same
-- invitation_id, but does NOT prevent the second call from then
-- attempting an INSERT that violates the UNIQUE index. The second
-- call returns 23505 unique_violation to the client, which surfaces
-- as a raw Postgres error in SpotAuditRepository.submit().
--
-- Failure mode: hospital double-taps "Submit" on the audit dialog
-- (network blip + retry, slow first response, etc). First call wins
-- and writes the rating. Second call hits 23505 and the UI shows
-- a generic error toast even though the rating WAS recorded.
--
-- Fix: catch unique_violation and return the existing response id
-- instead. The rating is locked in by the first call (same FOR UPDATE
-- serialization), so returning the prior id is correct — the caller
-- gets the "submit succeeded" UX.
--
-- Same pattern PR #715 (round 267) applied to debit_amc_pool_on_visit_complete.

CREATE OR REPLACE FUNCTION public.submit_spot_audit(
  p_invitation_id uuid,
  p_rating        int,
  p_feedback      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_inv    record;
  v_resp_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'rating must be 1..5' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_inv FROM public.spot_audit_invitations
   WHERE id = p_invitation_id
   FOR UPDATE;
  IF v_inv IS NULL THEN
    RAISE EXCEPTION 'invitation not found' USING ERRCODE = '02000';
  END IF;
  IF v_inv.hospital_user_id <> v_caller THEN
    RAISE EXCEPTION 'caller is not the invited hospital' USING ERRCODE = '42501';
  END IF;
  IF v_inv.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation expired at %', v_inv.expires_at USING ERRCODE = '22023';
  END IF;

  BEGIN
    INSERT INTO public.spot_audit_responses (invitation_id, rating, feedback)
    VALUES (
      p_invitation_id,
      p_rating,
      nullif(trim(coalesce(p_feedback, '')), '')
    )
    RETURNING id INTO v_resp_id;
  EXCEPTION WHEN unique_violation THEN
    -- Idempotent: a prior call already recorded this response
    -- (double-tap / retry storm). Return the existing row id so the
    -- caller sees "submitted" instead of a 23505 error.
    SELECT id INTO v_resp_id
      FROM public.spot_audit_responses
      WHERE invitation_id = p_invitation_id;
  END;

  RETURN v_resp_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) TO authenticated;
