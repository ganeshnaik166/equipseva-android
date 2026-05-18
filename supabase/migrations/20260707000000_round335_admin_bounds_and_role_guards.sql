-- Round 335 — bound admin SECDEF text params + protect founder from
-- accidentally demoting themselves via admin_force_role_change.
--
-- Scout audit (this session) found:
--   1. admin_resolve_amc_escalation(p_notes text) — unbounded
--   2. admin_set_engineer_verification(p_reason text) — unbounded
--   3. admin_set_buyer_kyc_status(p_reason text) — unbounded
--   4. admin_set_org_verification(p_reason text) — unbounded
--   5. admin_force_role_change(p_user_id) — no self-guard, no NOT FOUND raise
--
-- Admin operators are trusted, but unbounded text on admin RPCs still
-- bloats the columns (notes/verification_notes/rejection_reason) which
-- are rendered to the affected USER in their app. A 5 MB rejection
-- reason crashes the engineer's KYC screen. Bounded server-side at the
-- column level via CHECK so even direct service-role inserts can't
-- bypass.
--
-- The role-change RPC issue is concrete: founder edits their own
-- profile by accident and loses founder access (founder is decided by
-- email match in is_founder(), not the profiles.role column — but a
-- demoted user UI would route them away from the founder console).
-- Add an explicit RAISE if p_user_id == auth.uid() so the founder
-- can't self-demote without an explicit two-step flow.

ALTER TABLE public.amc_admin_escalations
  DROP CONSTRAINT IF EXISTS amc_admin_escalations_notes_length_check;
ALTER TABLE public.amc_admin_escalations
  ADD CONSTRAINT amc_admin_escalations_notes_length_check
    CHECK (notes IS NULL OR char_length(notes) <= 1000);

ALTER TABLE public.engineers
  DROP CONSTRAINT IF EXISTS engineers_verification_notes_length_check;
ALTER TABLE public.engineers
  ADD CONSTRAINT engineers_verification_notes_length_check
    CHECK (verification_notes IS NULL OR char_length(verification_notes) <= 1000);

ALTER TABLE public.buyer_kyc_verifications
  DROP CONSTRAINT IF EXISTS buyer_kyc_verifications_rejection_reason_length_check;
ALTER TABLE public.buyer_kyc_verifications
  ADD CONSTRAINT buyer_kyc_verifications_rejection_reason_length_check
    CHECK (rejection_reason IS NULL OR char_length(rejection_reason) <= 1000);

ALTER TABLE public.organizations
  DROP CONSTRAINT IF EXISTS organizations_rejection_reason_length_check;
ALTER TABLE public.organizations
  ADD CONSTRAINT organizations_rejection_reason_length_check
    CHECK (rejection_reason IS NULL OR char_length(rejection_reason) <= 1000);

ALTER TABLE public.seller_verification_requests
  DROP CONSTRAINT IF EXISTS seller_verification_requests_rejection_reason_length_check;
ALTER TABLE public.seller_verification_requests
  ADD CONSTRAINT seller_verification_requests_rejection_reason_length_check
    CHECK (rejection_reason IS NULL OR char_length(rejection_reason) <= 1000);

-- ---------------------------------------------------------------
-- admin_force_role_change — self-guard + NOT FOUND raise.
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_force_role_change(
  p_user_id uuid,
  p_new_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_affected int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;

  -- Round 335 — self-guard. Founder identity is email-pinned in
  -- is_founder(); the profiles.role column doesn't gate founder
  -- access. But the app reads profiles.role to decide which home
  -- to render, so a self-demote would lock the founder out of the
  -- founder console UI. Force an explicit "demote me" flow if it's
  -- ever needed rather than silently allowing the foot-gun.
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot change own role via admin_force_role_change'
      USING ERRCODE='42501';
  END IF;

  IF p_new_role NOT IN ('hospital_admin','engineer','supplier','manufacturer','logistics') THEN
    RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023';
  END IF;
  UPDATE public.profiles
  SET role = p_new_role::user_role,
      role_confirmed = true,
      updated_at = now()
  WHERE id = p_user_id;
  GET DIAGNOSTICS v_affected = ROW_COUNT;

  -- Round 335 — explicit NOT FOUND instead of silent success.
  IF v_affected = 0 THEN
    RAISE EXCEPTION 'user not found' USING ERRCODE='02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_force_role_change(uuid, text) TO authenticated;
