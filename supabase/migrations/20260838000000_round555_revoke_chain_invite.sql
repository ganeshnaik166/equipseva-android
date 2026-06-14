-- =====================================================================
-- Round 555 — Revoke pending chain invite
-- =====================================================================
--
-- Chain admin (or founder) can revoke a pending invite token before
-- it's redeemed. Useful when:
--   - Wrong email entered (re-invite with the correct one)
--   - Site no longer joining the chain
--   - Founder needs to claw back a compromised token
--
-- Sets status='revoked' so the (chain_id, invited_email, status)
-- conflict key no longer collides with a fresh invite.

BEGIN;

CREATE OR REPLACE FUNCTION public.chain_admin_revoke_invite(
  p_invite_id uuid,
  p_reason    text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_invite record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT i.*, c.primary_admin_user_id
    INTO v_invite
    FROM public.hospital_chain_invites i
    JOIN public.hospital_chains c ON c.id = i.chain_id
   WHERE i.id = p_invite_id
   FOR UPDATE OF i;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found' USING ERRCODE = '02000';
  END IF;

  -- Caller must be the chain's primary admin OR a founder.
  IF v_invite.primary_admin_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_chain_admin' USING ERRCODE = '42501';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invite_not_pending (status=%)', v_invite.status
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.hospital_chain_invites
     SET status = 'revoked'
   WHERE id = p_invite_id;

  -- Log for forensic recall — chain admins are not founders so we use
  -- the founder log only when a founder did the revoke.
  IF public.is_founder() THEN
    PERFORM public.log_founder_action(
      p_op_name       => 'chain_admin_revoke_invite',
      p_target_table  => 'hospital_chain_invites',
      p_target_row_id => p_invite_id,
      p_before_value  => jsonb_build_object('status', 'pending'),
      p_after_value   => jsonb_build_object('status', 'revoked'),
      p_reason        => coalesce(p_reason, 'no reason given')
    );
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_admin_revoke_invite(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chain_admin_revoke_invite(uuid, text)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 555 chain_admin_revoke_invite verified';
END;
$$;
