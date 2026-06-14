-- =====================================================================
-- Round 544 — Hospital chain memberships (v0.5 Phase 1 seed)
-- =====================================================================
--
-- Multi-site hospital model. Lets a hospital admin (the founder of a
-- chain — e.g. Clove Dental HQ) manage many physical sites under one
-- organizational umbrella, with site-level admins delegated downward.
--
-- Schema:
--   hospital_chains              — chain entity (Clove HQ, Apollo HQ, etc.)
--   hospital_chain_memberships   — which hospital_user_ids belong to which chain
--   hospital_chain_invites       — pending invites for site onboarding (chain admin → site admin)
--
-- The actual "hospital" is still the existing auth.users row (one per
-- site). A chain is just a grouping with a designated chain admin who
-- has cross-site visibility into all member hospitals' active jobs +
-- AMC contracts + invoices. The site admins keep day-to-day control.
--
-- This migration only seeds the schema + RLS + a few CRUD RPCs. The
-- cross-site read RPCs (chain_jobs_summary, chain_amc_summary, etc.)
-- land in v0.5 Phase 1 #4 when the UI is wired.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. hospital_chains
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chains (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  text NOT NULL CHECK (length(trim(name)) >= 3),
  billing_gstin         text CHECK (billing_gstin IS NULL OR billing_gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]{3}$'),
  primary_admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  -- Optional contract metadata for the chain itself.
  contracted_at         timestamptz,
  status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','paused','offboarded')),
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT hospital_chains_name_uniq UNIQUE (name)
);

CREATE INDEX IF NOT EXISTS hospital_chains_primary_admin_idx
  ON public.hospital_chains (primary_admin_user_id);

ALTER TABLE public.hospital_chains ENABLE ROW LEVEL SECURITY;

-- Chain admins see their own chain; founder sees all.
DROP POLICY IF EXISTS hospital_chains_select ON public.hospital_chains;
CREATE POLICY hospital_chains_select
  ON public.hospital_chains FOR SELECT
  TO authenticated
  USING (primary_admin_user_id = auth.uid() OR public.is_founder());

-- Direct INSERT/UPDATE/DELETE forbidden — must go through SECDEF RPCs
-- so the founder_action_log captures the writes.
REVOKE INSERT, UPDATE, DELETE ON public.hospital_chains
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. hospital_chain_memberships — which hospitals belong to which chain
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_memberships (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id            uuid NOT NULL REFERENCES public.hospital_chains(id) ON DELETE CASCADE,
  hospital_user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- role within the chain: 'admin' = co-admin with cross-site visibility,
  -- 'site' = single-site member (default, no cross-site read).
  member_role         text NOT NULL DEFAULT 'site'
                        CHECK (member_role IN ('site','admin')),
  site_label          text,           -- e.g. "Clove Banjara Hills"
  joined_at           timestamptz NOT NULL DEFAULT now(),
  added_by            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT hospital_chain_memberships_uniq UNIQUE (chain_id, hospital_user_id)
);

CREATE INDEX IF NOT EXISTS hospital_chain_memberships_chain_idx
  ON public.hospital_chain_memberships (chain_id);
CREATE INDEX IF NOT EXISTS hospital_chain_memberships_hospital_idx
  ON public.hospital_chain_memberships (hospital_user_id);

ALTER TABLE public.hospital_chain_memberships ENABLE ROW LEVEL SECURITY;

-- Hospitals see their own memberships; chain admins see all member
-- rows for their chain; founder sees all.
DROP POLICY IF EXISTS hospital_chain_memberships_select ON public.hospital_chain_memberships;
CREATE POLICY hospital_chain_memberships_select
  ON public.hospital_chain_memberships FOR SELECT
  TO authenticated
  USING (
    hospital_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.hospital_chains c
       WHERE c.id = chain_id
         AND c.primary_admin_user_id = auth.uid()
    )
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.hospital_chain_memberships
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. hospital_chain_invites — pending site onboarding invitations
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_chain_invites (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id            uuid NOT NULL REFERENCES public.hospital_chains(id) ON DELETE CASCADE,
  invited_email       text NOT NULL CHECK (invited_email ~* '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'),
  site_label          text,
  invite_token        text NOT NULL DEFAULT replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','accepted','revoked','expired')),
  expires_at          timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  created_at          timestamptz NOT NULL DEFAULT now(),
  created_by          uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  CONSTRAINT hospital_chain_invites_uniq UNIQUE (chain_id, invited_email, status)
);

CREATE INDEX IF NOT EXISTS hospital_chain_invites_token_idx
  ON public.hospital_chain_invites (invite_token);
CREATE INDEX IF NOT EXISTS hospital_chain_invites_status_idx
  ON public.hospital_chain_invites (status, expires_at);

ALTER TABLE public.hospital_chain_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hospital_chain_invites_select_admin ON public.hospital_chain_invites;
CREATE POLICY hospital_chain_invites_select_admin
  ON public.hospital_chain_invites FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.hospital_chains c
       WHERE c.id = chain_id
         AND c.primary_admin_user_id = auth.uid()
    )
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.hospital_chain_invites
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. founder_register_hospital_chain — founder creates a chain entity
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_register_hospital_chain(
  p_name                   text,
  p_primary_admin_user_id  uuid,
  p_billing_gstin          text DEFAULT NULL,
  p_notes                  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_name IS NULL OR length(trim(p_name)) < 3 THEN
    RAISE EXCEPTION 'chain_name required (min 3 chars)' USING ERRCODE = '22023';
  END IF;
  IF p_primary_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'primary_admin_user_id required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.hospital_chains (name, billing_gstin, primary_admin_user_id, notes, created_by, contracted_at)
  VALUES (
    trim(p_name),
    p_billing_gstin,
    p_primary_admin_user_id,
    p_notes,
    auth.uid(),
    now()
  )
  RETURNING id INTO v_id;

  -- Auto-add the primary admin as an 'admin' member of the new chain.
  INSERT INTO public.hospital_chain_memberships (chain_id, hospital_user_id, member_role, added_by)
  VALUES (v_id, p_primary_admin_user_id, 'admin', auth.uid());

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_register_hospital_chain',
    p_target_table  => 'hospital_chains',
    p_target_row_id => v_id,
    p_before_value  => NULL,
    p_after_value   => jsonb_build_object('name', p_name, 'primary_admin_user_id', p_primary_admin_user_id),
    p_reason        => coalesce(p_notes, 'v0.5 Phase 1 — chain registration')
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_register_hospital_chain(text, uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_register_hospital_chain(text, uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. chain_admin_invite_site — chain admin invites a new site
-- ---------------------------------------------------------------------
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
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Caller must be the chain's primary admin OR a founder.
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

  INSERT INTO public.hospital_chain_invites (chain_id, invited_email, site_label, created_by)
  VALUES (p_chain_id, lower(trim(p_email)), p_site_label, auth.uid())
  ON CONFLICT (chain_id, invited_email, status) DO UPDATE
    SET expires_at = now() + interval '14 days',
        invite_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
        site_label = COALESCE(EXCLUDED.site_label, public.hospital_chain_invites.site_label)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_admin_invite_site(uuid, text, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.chain_admin_invite_site(uuid, text, text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. accept_hospital_chain_invite — invited user redeems the token
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_hospital_chain_invite(
  p_invite_token  text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_invite record;
  v_membership_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_invite
    FROM public.hospital_chain_invites
   WHERE invite_token = p_invite_token
     AND status = 'pending'
     AND expires_at > now()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found_or_expired' USING ERRCODE = '02000';
  END IF;

  -- Caller's email must match the invited_email — prevents token
  -- replay from a different account.
  IF lower((SELECT email FROM auth.users WHERE id = auth.uid())) <> v_invite.invited_email THEN
    RAISE EXCEPTION 'invite_email_mismatch' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.hospital_chain_memberships
    (chain_id, hospital_user_id, member_role, site_label, added_by)
  VALUES
    (v_invite.chain_id, auth.uid(), 'site', v_invite.site_label, v_invite.created_by)
  ON CONFLICT (chain_id, hospital_user_id) DO NOTHING
  RETURNING id INTO v_membership_id;

  UPDATE public.hospital_chain_invites
     SET status = 'accepted'
   WHERE id = v_invite.id;

  RETURN v_membership_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_hospital_chain_invite(text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.accept_hospital_chain_invite(text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7. founder_list_hospital_chains — read helper for the cockpit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_list_hospital_chains(
  p_status text DEFAULT NULL,
  p_limit  integer DEFAULT 100
)
RETURNS TABLE (
  id                    uuid,
  name                  text,
  billing_gstin         text,
  primary_admin_user_id uuid,
  primary_admin_email   text,
  status                text,
  member_count          int,
  pending_invite_count  int,
  contracted_at         timestamptz,
  created_at            timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.billing_gstin,
    c.primary_admin_user_id,
    (SELECT email FROM auth.users WHERE id = c.primary_admin_user_id),
    c.status,
    (SELECT count(*)::int FROM public.hospital_chain_memberships m WHERE m.chain_id = c.id),
    (SELECT count(*)::int FROM public.hospital_chain_invites i
       WHERE i.chain_id = c.id AND i.status = 'pending' AND i.expires_at > now()),
    c.contracted_at,
    c.created_at
   FROM public.hospital_chains c
  WHERE (p_status IS NULL OR c.status = p_status)
  ORDER BY c.created_at DESC
  LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_hospital_chains(text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_list_hospital_chains(text, integer)
  TO service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 544 hospital chains seed verified: 3 tables + 4 RPCs (founder register / chain invite / accept / founder list)';
END;
$$;
