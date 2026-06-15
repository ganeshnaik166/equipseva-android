-- Round 582 — Picker helpers for the trainee-side request-supervision flow
--
-- WHY: Without a way for the Android client to enumerate (a) jobs the
-- trainee is currently accepted on and (b) engineers whose tier
-- strictly out-ranks them, the request_supervision RPC is unusable —
-- the trainee has no UUIDs to feed it.
--
-- Ships TWO new SECDEF, authenticated-only, STABLE self-view RPCs:
--
--   my_supervisable_jobs()
--     — repair jobs where caller is the accepted-bid engineer AND the
--       job is not in a terminal state ('completed','cancelled','disputed').
--       Trainee picks the job to open supervision against.
--
--   my_eligible_supervisors()
--     — engineers whose current_tier strictly out-ranks caller's tier
--       (per the r578 _supervised_tier_rank mapping) AND who are active.
--       Trainee picks the supervisor to request from.
--
-- Both RPCs are auth.uid()-scoped server-side — no parameters that
-- could pivot to another user's view.

BEGIN;

-- ----------------------------------------------------------------
-- RPC: my_supervisable_jobs
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_supervisable_jobs();
CREATE OR REPLACE FUNCTION public.my_supervisable_jobs()
RETURNS TABLE (
  repair_job_id      uuid,
  job_number         text,
  equipment_brand    text,
  equipment_model    text,
  status             text,
  accepted_at        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    rj.id                  AS repair_job_id,
    rj.job_number,
    rj.equipment_brand,
    rj.equipment_model,
    rj.status,
    b.created_at           AS accepted_at
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b
    ON b.repair_job_id = rj.id
   AND b.status = 'accepted'
  WHERE b.engineer_user_id = v_uid
    AND rj.status NOT IN ('completed','cancelled','disputed')
  ORDER BY b.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_supervisable_jobs()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_supervisable_jobs()
  TO authenticated;

-- ----------------------------------------------------------------
-- RPC: my_eligible_supervisors
-- Returns engineers strictly higher in the cert-ladder rank.
-- Privacy: returns user_id, current_tier, jobs_completed (already
-- visible via engineers table) — no PII.
-- ----------------------------------------------------------------
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

COMMIT;
