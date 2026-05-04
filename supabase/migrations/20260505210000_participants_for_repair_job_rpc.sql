-- Server-only helper for the request-call-session edge function.
-- Returns both real phone numbers for a given repair job's
-- (hospital, engineer) pair. Reading profiles.phone is RLS-blocked
-- at the table level since 20260428110000_security_profiles_select_self_only,
-- so the edge function must call this RPC under service-role to look
-- up the routing targets without exposing them to any client.
--
-- EXECUTE granted ONLY to service_role — authenticated callers can't
-- invoke this even if they know the function name. SECURITY DEFINER
-- is the right shape but still gated by the role grant.

CREATE OR REPLACE FUNCTION public.participants_for_repair_job(p_job_id uuid)
RETURNS TABLE (
  hospital_user_id uuid,
  engineer_user_id uuid,
  hospital_phone text,
  engineer_phone text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rj.hospital_user_id                                      AS hospital_user_id,
    e.user_id                                                AS engineer_user_id,
    hp.phone                                                 AS hospital_phone,
    ep.phone                                                 AS engineer_phone
  FROM public.repair_jobs rj
  LEFT JOIN public.engineers e  ON e.id = rj.engineer_id
  LEFT JOIN public.profiles  hp ON hp.id = rj.hospital_user_id
  LEFT JOIN public.profiles  ep ON ep.id = e.user_id
  WHERE rj.id = p_job_id
  LIMIT 1;
END;
$$;

ALTER FUNCTION public.participants_for_repair_job(uuid) OWNER TO postgres;

-- Service-role only. Authenticated callers must NOT be able to pull
-- the engineer's phone via this back door — the `engineer_public_profile`
-- gated RPC remains the only authenticated path, and it returns the
-- VIRTUAL number once Feature 3 is fully wired (Phase 2 of this PR
-- chain).
REVOKE ALL ON FUNCTION public.participants_for_repair_job(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.participants_for_repair_job(uuid) TO service_role;
