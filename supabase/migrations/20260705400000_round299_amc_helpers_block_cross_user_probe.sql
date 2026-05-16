-- Round 299 — block cross-user probe of amc_contract_is_party and
-- amc_rotation_includes_user.
--
-- These helpers (20260514100000) take (p_contract_id uuid, p_user_id
-- uuid) and return TRUE if the user is associated with the contract.
-- They're SECURITY DEFINER + STABLE + granted to authenticated so the
-- RLS policies on amc_contracts / amc_engineer_rotation can call them
-- without recursing back into RLS.
--
-- Side effect: any authenticated caller can directly invoke the
-- helpers with arbitrary p_user_id arguments, probing "is user X
-- associated with contract Y?". UUID brute-force is impractical but
-- a caller who already knows specific (contract_id, user_id) pairs
-- (e.g., from public-facing data or social engineering) can confirm
-- the relationship.
--
-- Every legitimate caller passes auth.uid() as p_user_id:
--   * RLS policies (lines 87, 102 of the original migration)
--   * SECDEF RPC wrappers (amc_followup_rpcs / fix_amc_invoker_rpcs)
--   * the v_caller := auth.uid() pattern
--
-- Fix: add a guard that rejects calls where p_user_id <> auth.uid()
-- AND the caller isn't admin/founder. Admins can still probe
-- arbitrary users for legitimate ops triage. Everyone else gets the
-- same result as before for their own auth.uid(), but a 42501 if
-- they try to probe another user.

CREATE OR REPLACE FUNCTION public.amc_contract_is_party(
  p_contract_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Block cross-user probe. Admin/founder can target any user.
  IF p_user_id IS DISTINCT FROM auth.uid()
     AND NOT public.is_admin(auth.uid())
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'cross-user probe blocked' USING ERRCODE = '42501';
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.amc_contracts c
    WHERE c.id = p_contract_id
      AND (
        c.hospital_user_id = p_user_id
        OR EXISTS (
          SELECT 1 FROM public.engineers e
          WHERE e.id = c.primary_engineer_id AND e.user_id = p_user_id
        )
      )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.amc_contract_is_party(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.amc_contract_is_party(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.amc_rotation_includes_user(
  p_contract_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid()
     AND NOT public.is_admin(auth.uid())
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'cross-user probe blocked' USING ERRCODE = '42501';
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.amc_engineer_rotation r
    JOIN public.engineers e ON e.id = r.engineer_id
    WHERE r.amc_contract_id = p_contract_id
      AND r.active = true
      AND e.user_id = p_user_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.amc_rotation_includes_user(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.amc_rotation_includes_user(uuid, uuid) TO authenticated;
