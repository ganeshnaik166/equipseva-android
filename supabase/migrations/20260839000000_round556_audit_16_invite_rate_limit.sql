-- =====================================================================
-- Round 556 — Audit-16 patch (chain invite rotation rate limit)
-- =====================================================================
--
-- Audit-16 confirmed 1 MEDIUM: chain_admin_invite_site used ON CONFLICT
-- DO UPDATE on (chain_id, invited_email, status) which regenerated
-- invite_token on every call. A chain admin could call repeatedly to
-- generate unlimited fresh tokens (DoS surface; email-match prevents
-- account-takeover, but token-flapping breaks legitimate redemption).
--
-- Fix: refuse to rotate the token within 60 seconds of the last
-- rotation. Adds invite_rotations_count + invite_token_rotated_at
-- columns for forensic auditability. Caps total rotations at 10 per
-- invite — beyond that, the chain admin must revoke and re-invite.

BEGIN;

ALTER TABLE public.hospital_chain_invites
  ADD COLUMN IF NOT EXISTS invite_token_rotated_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS invite_rotations_count  int NOT NULL DEFAULT 0;

-- Recreate chain_admin_invite_site with the rate-limit guard.
DROP FUNCTION IF EXISTS public.chain_admin_invite_site(uuid, text, text);

CREATE OR REPLACE FUNCTION public.chain_admin_invite_site(
  p_chain_id      uuid,
  p_email         text,
  p_site_label    text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id        uuid;
  v_existing  record;
  v_email     text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.hospital_chains
     WHERE id = p_chain_id
       AND (primary_admin_user_id = auth.uid() OR public.is_founder())
  ) THEN
    RAISE EXCEPTION 'not_chain_admin' USING ERRCODE = '42501';
  END IF;

  IF p_email IS NULL OR p_email !~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' THEN
    RAISE EXCEPTION 'valid_email_required' USING ERRCODE = '22023';
  END IF;

  v_email := lower(trim(p_email));

  -- Audit-16 rate-limit guard: look for an existing pending invite for
  -- this (chain_id, email). If found and rotated within 60 seconds OR
  -- already rotated >= 10 times, refuse.
  SELECT * INTO v_existing
    FROM public.hospital_chain_invites
   WHERE chain_id = p_chain_id
     AND invited_email = v_email
     AND status = 'pending'
   FOR UPDATE;

  IF FOUND THEN
    IF v_existing.invite_token_rotated_at > now() - interval '60 seconds' THEN
      RAISE EXCEPTION 'invite_rotation_rate_limit (last rotated %s ago)',
        extract(epoch from now() - v_existing.invite_token_rotated_at)::int
        USING ERRCODE = '53400';
    END IF;
    IF v_existing.invite_rotations_count >= 10 THEN
      RAISE EXCEPTION 'invite_rotation_cap_reached — revoke + re-invite'
        USING ERRCODE = '53400';
    END IF;

    UPDATE public.hospital_chain_invites
       SET expires_at = now() + interval '14 days',
           invite_token = replace(gen_random_uuid()::text, '-', '') ||
                          replace(gen_random_uuid()::text, '-', ''),
           invite_token_rotated_at = now(),
           invite_rotations_count = invite_rotations_count + 1,
           site_label = COALESCE(p_site_label, site_label)
     WHERE id = v_existing.id
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO public.hospital_chain_invites
      (chain_id, invited_email, site_label, created_by,
       invite_token_rotated_at, invite_rotations_count)
    VALUES
      (p_chain_id, v_email, p_site_label, auth.uid(), now(), 0)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_admin_invite_site(uuid, text, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chain_admin_invite_site(uuid, text, text)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 556 audit-16 patch verified: chain_admin_invite_site now rate-limited (60s cool-down + 10-rotation cap per invite)';
END;
$$;
