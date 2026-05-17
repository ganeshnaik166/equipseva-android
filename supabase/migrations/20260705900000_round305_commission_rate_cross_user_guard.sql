-- Round 305 — block cross-user probe of commission_rate_for_hospital.
--
-- commission_rate_for_hospital(p_hospital_user_id) is SECDEF, granted
-- to authenticated. Same probe-oracle vector as round 299: any
-- authenticated caller can pass arbitrary uuids and infer 3-bit
-- buckets about another hospital's job history (< 10 jobs / 10-49 /
-- 50+ AND ≥ 3 distinct engineers). The 20260622100000 anti-gaming
-- fix added the diversity requirement but didn't address the probe
-- surface.
--
-- Legit callers:
--   * BEFORE-UPDATE triggers on repair_jobs (pass NEW.hospital_user_id,
--     which is the parent row's hospital — they're either inserting or
--     updating it themselves so this isn't a probe).
--   * engineer_view_hospital_tier RPC — already gates on caller being
--     the assigned engineer.
--
-- Add a guard: caller must EITHER be the hospital themselves OR be
-- an engineer assigned to a job for this hospital (so the probe is
-- bounded to real-relationship contexts) OR be admin/founder.
-- Trigger-fired calls bypass via session_user='postgres' check.

CREATE OR REPLACE FUNCTION public.commission_rate_for_hospital(
  p_hospital_user_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_distinct_engineers int := 0;
  v_min_amount constant numeric := 2000;
  v_min_distinct constant int := 3;
  v_caller uuid := auth.uid();
  v_allowed boolean := false;
BEGIN
  IF p_hospital_user_id IS NULL THEN
    RETURN 0.07;
  END IF;

  -- Round 305 access gate. Bypass for trigger / service-role contexts
  -- where session_user is postgres or the JWT role is service_role.
  IF session_user = 'postgres'
     OR current_setting('request.jwt.claim.role', true) = 'service_role'
     OR v_caller IS NULL THEN
    v_allowed := true;
  ELSIF v_caller = p_hospital_user_id THEN
    v_allowed := true;
  ELSIF public.is_admin(v_caller) OR public.is_founder() THEN
    v_allowed := true;
  ELSE
    -- Engineer assigned to a job for this hospital? Mirror the
    -- engineer_view_hospital_tier gate.
    v_allowed := EXISTS (
      SELECT 1 FROM public.repair_jobs rj
      JOIN public.engineers e ON e.id = rj.engineer_id
      WHERE rj.hospital_user_id = p_hospital_user_id
        AND e.user_id = v_caller
      LIMIT 1
    );
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'cross-user probe blocked' USING ERRCODE = '42501';
  END IF;

  -- Original anti-gaming body from 20260622100000.
  SELECT count(*),
         count(DISTINCT engineer_id)
    INTO v_count, v_distinct_engineers
    FROM public.repair_jobs
   WHERE hospital_user_id = p_hospital_user_id
     AND status::text = 'completed'
     AND completed_at IS NOT NULL
     AND completed_at >= now() - interval '12 months'
     AND COALESCE(contracted_amount_rupees, 0) >= v_min_amount
     AND engineer_id IS NOT NULL;

  IF v_distinct_engineers < v_min_distinct THEN
    RETURN 0.07;
  END IF;

  IF v_count >= 50 THEN
    RETURN 0.03;
  ELSIF v_count >= 10 THEN
    RETURN 0.05;
  ELSE
    RETURN 0.07;
  END IF;
END;
$$;

ALTER FUNCTION public.commission_rate_for_hospital(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) TO authenticated;
