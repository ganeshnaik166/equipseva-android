-- Hotfix: amc_contracts + amc_engineer_rotation RLS policies (PR-C1)
-- recurse into each other.
--
-- Symptom: SELECT on either table from a hospital JWT returns 42P17
-- "infinite recursion detected in policy for relation amc_contracts".
--
-- Cause: amc_contracts.amc_contracts_engineer_assigned policy queries
-- amc_engineer_rotation, whose own policy queries amc_contracts. Same
-- vice-versa. PostgreSQL evaluates RLS recursively and detects the
-- cycle.
--
-- Fix: replace both recursive sub-queries with SECURITY DEFINER helper
-- functions that bypass RLS internally. The helpers are owned by
-- postgres + STABLE + search_path-locked; granted to authenticated.
-- Each helper does the cross-table read once with normal table grants
-- (no RLS) and returns a boolean. Policies invoke the helper instead
-- of direct EXISTS subqueries, breaking the cycle.
--
-- Caught by PR-C3 (cron) smoke probe; would have manifested the
-- moment a hospital opened the AMC list screen in PR-C6. Shipping as
-- standalone hotfix so PR-C3/C4/C5 (already DB-applied) can be safely
-- merged into git history without dragging an unrunnable RLS bug.

-- 1. SECDEF helpers ----------------------------------------------------

CREATE OR REPLACE FUNCTION public.amc_contract_is_party(
  p_contract_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
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
$$;
REVOKE EXECUTE ON FUNCTION public.amc_contract_is_party(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.amc_contract_is_party(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.amc_rotation_includes_user(
  p_contract_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.amc_engineer_rotation r
    JOIN public.engineers e ON e.id = r.engineer_id
    WHERE r.amc_contract_id = p_contract_id
      AND r.active = true
      AND e.user_id = p_user_id
  );
$$;
REVOKE EXECUTE ON FUNCTION public.amc_rotation_includes_user(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.amc_rotation_includes_user(uuid, uuid) TO authenticated;

-- 2. Replace recursive policies ---------------------------------------

DROP POLICY IF EXISTS amc_contracts_engineer_assigned ON public.amc_contracts;

CREATE POLICY amc_contracts_engineer_assigned ON public.amc_contracts
  FOR SELECT
  USING (
    -- Direct primary check stays inline — it's a single-table EXISTS,
    -- no cycle possible.
    EXISTS (
      SELECT 1 FROM public.engineers e
      WHERE e.id = primary_engineer_id AND e.user_id = auth.uid()
    )
    -- Rotation membership goes through the SECDEF helper that bypasses
    -- amc_engineer_rotation's RLS, breaking the cycle.
    OR public.amc_rotation_includes_user(amc_contracts.id, auth.uid())
  );

DROP POLICY IF EXISTS amc_rotation_visible_to_party ON public.amc_engineer_rotation;

CREATE POLICY amc_rotation_visible_to_party ON public.amc_engineer_rotation
  FOR SELECT
  USING (
    -- Engineer reading their own rotation row — no cross-table read.
    EXISTS (
      SELECT 1 FROM public.engineers e
      WHERE e.id = amc_engineer_rotation.engineer_id AND e.user_id = auth.uid()
    )
    -- Hospital / primary-engineer party check uses the SECDEF helper
    -- so we don't trigger amc_contracts' own RLS evaluation.
    OR public.amc_contract_is_party(amc_engineer_rotation.amc_contract_id, auth.uid())
    OR public.is_admin(auth.uid())
    OR public.is_founder()
  );
