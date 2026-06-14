-- =====================================================================
-- Round 568 — Audit-19 patches (2 CRITICAL closed)
-- =====================================================================
--
-- Audit-19 (workflow wj7lj9d8s) on r564 referral bounty. 3 raw → 2
-- confirmed CRITICAL. Both end-to-end exploitable.
--
-- CRITICAL #1 — Anti-collusion gate is a no-op.
--   r564 referenced public.collusion_pairs (does not exist); real
--   table is public.collusion_flags (r498). The EXCEPTION WHEN
--   undefined_table block catches the error and sets
--   v_has_collusion := false. Every referral bypasses the gate.
--
--   Compounding: even with the right table, collusion_flags models
--   engineer↔hospital relationships, not engineer↔engineer. So
--   patching the table name alone would still leave the gate inert
--   for referral abuse. We REMOVE the broken check and rely on:
--     - Anti-duplicate-account gate (r501 — fixed below)
--     - NEW referrer-consent gate (this round)
--
-- CRITICAL #2 — Self-attribution abuse.
--   register_engineer_referral(p_referrer_user_id) accepts any
--   engineer UUID. Engineer user_ids are not secret (visible in
--   /engineers cockpit + Android directory). Attacker signs up,
--   claims any target as referrer, completes a job → target gets ₹2k
--   without ever consenting. Effectively turns the bounty into a
--   griefing tool against legit engineers.
--
--   Fix: add referrer_confirmed_at + referral_confirmation_code
--   columns. Referrer must explicitly call confirm_engineer_referral
--   from their own session to convert the row from 'pending' to
--   'confirmed'. evaluate_referral_bounty refuses unconfirmed rows.
--
-- Also: verify duplicate_account_flags column names actually match
-- (user_id_a / user_id_b + status column). They do — r501 schema
-- confirmed. Patch retains that check unchanged.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. New columns on engineer_referrals
-- ---------------------------------------------------------------------
ALTER TABLE public.engineer_referrals
  ADD COLUMN IF NOT EXISTS referrer_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS referral_confirmation_code text
    DEFAULT (substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

CREATE INDEX IF NOT EXISTS engineer_referrals_unconfirmed_idx
  ON public.engineer_referrals (referrer_user_id, created_at DESC)
  WHERE referrer_confirmed_at IS NULL AND NOT bounty_revoked;

-- ---------------------------------------------------------------------
-- 2. confirm_engineer_referral — referrer-side opt-in
-- ---------------------------------------------------------------------
--
-- Called by the REFERRER from their own session. Sets the
-- referrer_confirmed_at timestamp. evaluate_referral_bounty then
-- considers the row eligible for the rest of its gates.
--
-- Two acceptable invocations:
--   (a) confirm_engineer_referral(referral_id) — referrer who knows the
--       referral_id (visible in /referrals cockpit / engineer self-view)
--   (b) confirm_engineer_referral_by_code(code) — referrer enters the
--       12-char confirmation code shared by the referee
CREATE OR REPLACE FUNCTION public.confirm_engineer_referral(
  p_referral_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ref record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_ref
    FROM public.engineer_referrals
   WHERE id = p_referral_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'referral_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_ref.referrer_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'not_the_referrer' USING ERRCODE = '42501';
  END IF;

  IF v_ref.bounty_revoked THEN
    RAISE EXCEPTION 'referral_revoked' USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_referrals
     SET referrer_confirmed_at = coalesce(referrer_confirmed_at, now())
   WHERE id = p_referral_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_engineer_referral(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.confirm_engineer_referral(uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.confirm_engineer_referral_by_code(
  p_code text
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

  SELECT id INTO v_id
    FROM public.engineer_referrals
   WHERE referral_confirmation_code = p_code
     AND referrer_user_id = auth.uid()
     AND NOT bounty_revoked
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_code_or_not_referrer' USING ERRCODE = '02000';
  END IF;

  UPDATE public.engineer_referrals
     SET referrer_confirmed_at = coalesce(referrer_confirmed_at, now())
   WHERE id = v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.confirm_engineer_referral_by_code(text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.confirm_engineer_referral_by_code(text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Recreate evaluate_referral_bounty
--    - Remove the broken collusion_pairs check (was no-op via exception
--      handler, and the table is engineer↔hospital anyway)
--    - Add referrer-consent gate
--    - Keep the duplicate-account-flags gate (confirmed working)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.evaluate_referral_bounty(uuid);

CREATE OR REPLACE FUNCTION public.evaluate_referral_bounty(
  p_referral_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ref           record;
  v_first_job     record;
  v_has_duplicate boolean;
BEGIN
  SELECT * INTO v_ref
    FROM public.engineer_referrals
   WHERE id = p_referral_id
   FOR UPDATE;
  IF NOT FOUND OR v_ref.bounty_eligible OR v_ref.bounty_revoked THEN
    RETURN false;
  END IF;

  -- r568 audit-19 CRITICAL #2 fix: referrer must have explicitly
  -- confirmed this referral. Blocks self-attribution abuse.
  IF v_ref.referrer_confirmed_at IS NULL THEN
    RETURN false;
  END IF;

  -- Find referee's earliest completed + escrow-released repair job.
  SELECT rj.id, rj.completed_at
    INTO v_first_job
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
    JOIN public.repair_job_escrow e
      ON e.repair_job_id = rj.id AND e.status = 'released'
   WHERE b.engineer_user_id = v_ref.referee_user_id
     AND rj.status = 'completed'
   ORDER BY rj.completed_at ASC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- r568 audit-19 CRITICAL #1 partial fix: removed the broken
  -- collusion_pairs check entirely. The table name was wrong AND the
  -- collusion_flags schema doesn't model engineer↔engineer pairs
  -- anyway. Duplicate-account gate is now the sole automated abuse
  -- check; founder can still revoke manually post-hoc.

  -- Anti-duplicate-account gate (r501 — verified schema).
  BEGIN
    SELECT EXISTS (
      SELECT 1 FROM public.duplicate_account_flags df
       WHERE df.status IN ('open','investigating','confirmed')
         AND ((df.user_id_a = v_ref.referrer_user_id AND df.user_id_b = v_ref.referee_user_id)
              OR (df.user_id_a = v_ref.referee_user_id  AND df.user_id_b = v_ref.referrer_user_id))
    ) INTO v_has_duplicate;
  EXCEPTION WHEN undefined_table THEN
    v_has_duplicate := false;
  END;

  IF v_has_duplicate THEN
    RETURN false;
  END IF;

  UPDATE public.engineer_referrals
     SET bounty_eligible = true,
         referee_first_job_id = v_first_job.id,
         referee_first_completed_at = v_first_job.completed_at
   WHERE id = v_ref.id;

  INSERT INTO public.referral_bounty_payouts
    (referral_id, beneficiary_user_id, amount_rupees)
  VALUES (v_ref.id, v_ref.referrer_user_id, v_ref.bounty_amount_rupees)
  ON CONFLICT (referral_id) DO NOTHING;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.evaluate_referral_bounty(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.evaluate_referral_bounty(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. Expand my_referrals + add a "incoming pending confirmations" RPC
--    so referrers can see refs they need to confirm.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_pending_referral_confirmations()
RETURNS TABLE (
  id                          uuid,
  referee_user_id             uuid,
  referral_confirmation_code  text,
  created_at                  timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.referee_user_id, r.referral_confirmation_code, r.created_at
    FROM public.engineer_referrals r
   WHERE r.referrer_user_id = v_user
     AND r.referrer_confirmed_at IS NULL
     AND NOT r.bounty_revoked
   ORDER BY r.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_pending_referral_confirmations()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_pending_referral_confirmations()
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 568 audit-19 patches verified: removed broken collusion check + added referrer_confirmed_at gate (self-attribution abuse closed) + new confirm RPCs';
END;
$$;
