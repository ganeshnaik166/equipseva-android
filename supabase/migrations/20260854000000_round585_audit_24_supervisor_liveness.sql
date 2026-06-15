-- Round 585 — Audit-24 MEDIUM: enforce supervisor liveness in picker + request RPC
--
-- Two RPCs let a deactivated/cash-suspended/verification-revoked engineer
-- still be picked as a supervisor:
--
--   1. my_eligible_supervisors (r582) — header comment promised "AND who
--      are active" but query never joined to engineers; soft-suspended
--      and verification-revoked supervisors stayed in the dropdown.
--   2. request_supervision (r576) — accepted any UUID with a cert-progress
--      row at higher rank, no liveness check. Even if the picker was
--      hardened, a direct RPC call could bypass.
--
-- Two-layer defense-in-depth gap. Patched in both layers here.
--
-- Liveness predicate: e.verification_status = 'verified' AND
-- e.cash_auto_suspended_at IS NULL. These are the operational flags
-- ops uses to suspend engineers (per r311 + v21_cash_auto_suspend).

BEGIN;

-- ------------------------------------------------------------------
-- 1. Replace my_eligible_supervisors with the liveness filter
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_eligible_supervisors();
CREATE OR REPLACE FUNCTION public.my_eligible_supervisors()
RETURNS TABLE (
  user_id            uuid,
  current_tier       text,
  jobs_completed     int,
  display_name       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid             uuid := auth.uid();
  v_my_tier         text;
  v_my_rank         int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT current_tier INTO v_my_tier
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = v_uid;
  IF NOT FOUND THEN
    v_my_tier := 'none';
  END IF;

  v_my_rank := public._supervised_tier_rank(v_my_tier);
  IF v_my_rank IS NULL THEN
    v_my_rank := 0;
  END IF;

  RETURN QUERY
  SELECT
    p.engineer_user_id                          AS user_id,
    p.current_tier,
    p.jobs_completed,
    coalesce(pr.full_name, '(engineer)')        AS display_name
  FROM public.engineer_certification_progress p
  JOIN public.engineers e
    ON e.user_id = p.engineer_user_id
   AND e.verification_status = 'verified'
   AND e.cash_auto_suspended_at IS NULL
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.engineer_user_id <> v_uid
    AND public._supervised_tier_rank(p.current_tier) > v_my_rank
  ORDER BY public._supervised_tier_rank(p.current_tier) DESC,
           p.jobs_completed DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_eligible_supervisors()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_eligible_supervisors()
  TO authenticated;

-- ------------------------------------------------------------------
-- 2. Replace request_supervision with the same liveness gate
--    (server-side mirror of the picker filter — without this, a
--    bypassed-picker attack still works.)
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_supervision(uuid, uuid);
CREATE OR REPLACE FUNCTION public.request_supervision(
  p_job_id              uuid,
  p_supervisor_user_id  uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller            uuid := auth.uid();
  v_job_status        text;
  v_accepted_bidder   uuid;
  v_trainee_tier      text;
  v_supervisor_tier   text;
  v_trainee_rank      int;
  v_supervisor_rank   int;
  v_sup_verification  text;
  v_sup_cash_susp     timestamptz;
  v_new_id            uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  IF p_job_id IS NULL OR p_supervisor_user_id IS NULL THEN
    RAISE EXCEPTION 'job_id and supervisor_user_id required'
      USING ERRCODE = '22023';
  END IF;

  IF v_caller = p_supervisor_user_id THEN
    RAISE EXCEPTION 'cannot supervise self' USING ERRCODE = '22023';
  END IF;

  SELECT rj.status, b.engineer_user_id
    INTO v_job_status, v_accepted_bidder
    FROM public.repair_jobs rj
    LEFT JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE rj.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_job_status IN ('completed','cancelled','disputed') THEN
    RAISE EXCEPTION 'job in terminal state %; cannot request supervision', v_job_status
      USING ERRCODE = '0L000';
  END IF;
  IF v_accepted_bidder IS NULL OR v_accepted_bidder <> v_caller THEN
    RAISE EXCEPTION 'only the accepted-bid engineer may request supervision'
      USING ERRCODE = '42501';
  END IF;

  SELECT current_tier INTO v_trainee_tier
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = v_caller;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'trainee has no certification progress row'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT current_tier INTO v_supervisor_tier
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = p_supervisor_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'supervisor has no certification progress row'
      USING ERRCODE = 'P0002';
  END IF;

  v_trainee_rank    := public._supervised_tier_rank(v_trainee_tier);
  v_supervisor_rank := public._supervised_tier_rank(v_supervisor_tier);

  IF v_supervisor_rank IS NULL OR v_trainee_rank IS NULL THEN
    RAISE EXCEPTION 'invalid tier mapping' USING ERRCODE = '22023';
  END IF;

  IF v_supervisor_rank <= v_trainee_rank THEN
    RAISE EXCEPTION
      'supervisor tier (%) must be strictly higher than trainee tier (%)',
      v_supervisor_tier, v_trainee_tier
      USING ERRCODE = '0L000';
  END IF;

  -- r585 audit-24 MEDIUM: supervisor must be a verified, non-suspended
  -- engineer. Otherwise a deactivated account that happens to retain a
  -- gold cert-progress row could still be picked.
  SELECT e.verification_status, e.cash_auto_suspended_at
    INTO v_sup_verification, v_sup_cash_susp
    FROM public.engineers e
   WHERE e.user_id = p_supervisor_user_id;
  IF NOT FOUND OR coalesce(v_sup_verification, 'pending') <> 'verified'
     OR v_sup_cash_susp IS NOT NULL THEN
    RAISE EXCEPTION 'supervisor is not an active verified engineer'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.supervised_job_assignments
    (trainee_user_id, supervisor_user_id, repair_job_id,
     trainee_tier_at_assignment, supervisor_tier_at_assignment,
     status, requested_at)
  VALUES
    (v_caller, p_supervisor_user_id, p_job_id,
     v_trainee_tier, v_supervisor_tier,
     'pending_supervisor_accept', now())
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.request_supervision(uuid, uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_supervision(uuid, uuid)
  TO authenticated;

COMMIT;
