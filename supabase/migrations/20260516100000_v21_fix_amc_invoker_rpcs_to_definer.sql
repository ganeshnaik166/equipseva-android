-- Hotfix: list_amc_rotation (PR-C5) and list_amc_sla_breaches_for_contract
-- (PR-C4) were declared SECURITY INVOKER on the assumption that the
-- amc_engineer_rotation / amc_sla_breaches RLS policies would gate the
-- read. They do — but both RPCs JOIN to public.engineers (and reviews
-- JOINs to public.repair_jobs), and those tables have separate RLS
-- policies that DON'T let a hospital read engineer rows directly.
--
-- Symptom (caught by the on-device AMC detail screen smoke 2026-05-06):
-- the Rotation tab shows "Rotation will appear here." and the SLA tab
-- shows zero breaches even when rows exist in the underlying tables.
-- Direct REST `GET /amc_engineer_rotation?...` works for the hospital
-- (own RLS allows it) but the same JOIN inside the RPC drops everything
-- because the engineers JOIN is shadowed.
--
-- Fix: flip both functions to SECURITY DEFINER + explicit caller gate
-- using the SECDEF helpers shipped in the RLS-recursion hotfix
-- (amc_contract_is_party, amc_rotation_includes_user). This matches the
-- pattern already used by list_amc_pool_ledger / list_amc_visits_for_
-- contract that shipped in v2.1 follow-ups (#269) — those use SECDEF
-- + helper-gated and don't have this issue.
--
-- Rotation engineers (priority>1) need to see their own contracts'
-- rotation list; the gate accepts amc_rotation_includes_user too.

DROP FUNCTION IF EXISTS public.list_amc_rotation(uuid);

CREATE OR REPLACE FUNCTION public.list_amc_rotation(
  p_contract_id uuid
)
RETURNS TABLE (
  rotation_id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_city text,
  priority int,
  is_primary boolean,
  active boolean,
  is_available boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT public.amc_contract_is_party(p_contract_id, v_caller)
     AND NOT public.amc_rotation_includes_user(p_contract_id, v_caller)
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id AS rotation_id,
    r.engineer_id,
    coalesce(p.full_name, '(unnamed)') AS engineer_name,
    coalesce(e.city, '') AS engineer_city,
    r.priority,
    (r.priority = 1) AS is_primary,
    r.active,
    coalesce(e.is_available, false) AS is_available
  FROM public.amc_engineer_rotation r
  JOIN public.engineers e ON e.id = r.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE r.amc_contract_id = p_contract_id
  ORDER BY r.priority ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_amc_rotation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_amc_rotation(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.list_amc_sla_breaches_for_contract(uuid);

CREATE OR REPLACE FUNCTION public.list_amc_sla_breaches_for_contract(
  p_contract_id uuid
)
RETURNS TABLE (
  breach_id uuid,
  visit_id uuid,
  visit_code text,
  breach_type text,
  severity text,
  expected_within_hours int,
  actual_hours numeric,
  credit_issued_rupees numeric,
  detected_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT public.amc_contract_is_party(p_contract_id, v_caller)
     AND NOT public.amc_rotation_includes_user(p_contract_id, v_caller)
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    b.id AS breach_id,
    b.visit_id,
    rj.job_number AS visit_code,
    b.breach_type,
    b.severity,
    b.expected_within_hours,
    b.actual_hours,
    b.credit_issued_rupees,
    b.detected_at,
    b.resolved_at
  FROM public.amc_sla_breaches b
  LEFT JOIN public.repair_jobs rj ON rj.id = b.visit_id
  WHERE b.amc_contract_id = p_contract_id
  ORDER BY b.detected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_amc_sla_breaches_for_contract(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_amc_sla_breaches_for_contract(uuid) TO authenticated;
