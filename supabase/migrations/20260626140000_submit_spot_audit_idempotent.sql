-- Round 234 — submit_spot_audit idempotency.
--
-- spot_audit_responses has a UNIQUE constraint on invitation_id, so a
-- double-tap on Submit racing through the network surfaced as a
-- 23505 unique_violation, which the client classifier maps to GiveUp
-- and turned into a "Couldn't submit your audit" toast — confusing
-- because the first call had actually succeeded server-side.
--
-- Make the RPC idempotent: on conflict, return the previously-inserted
-- response id instead of raising. New responses still succeed; double
-- submits become a no-op return of the existing row.

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

  -- ON CONFLICT DO NOTHING means a second submit for the same invitation
  -- returns no row; pair it with a fallback SELECT so the RPC always
  -- returns the canonical response id (the original one).
  INSERT INTO public.spot_audit_responses (invitation_id, rating, feedback)
  VALUES (
    p_invitation_id,
    p_rating,
    nullif(trim(coalesce(p_feedback, '')), '')
  )
  ON CONFLICT (invitation_id) DO NOTHING
  RETURNING id INTO v_resp_id;

  IF v_resp_id IS NULL THEN
    SELECT id INTO v_resp_id
      FROM public.spot_audit_responses
     WHERE invitation_id = p_invitation_id;
  END IF;

  RETURN v_resp_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_spot_audit(uuid, int, text) TO authenticated;
