-- =====================================================================
-- Round 576 — Supervised training program (v0.5 Phase 2 #2)
-- =====================================================================
--
-- WHY:
--   The r550 certification ladder rungs (none → bronze → silver → gold)
--   currently only advance on completed-job count + dispute rate + the
--   r503 verified-tier ceiling. Raw count is a weak skill signal — a
--   brand-new engineer ('none' tier) may have legitimate competence but
--   no proof, and gating Bronze on "5 unsupervised jobs" pushes them
--   to take work they may not yet handle safely.
--
--   r576 plants the formal pathway: a lower-tier engineer (TRAINEE) can
--   request a SUPERVISED job, where a higher-tier engineer (SUPERVISOR)
--   shadows them. On successful sign-off (after the hospital signs the
--   DSR), that completion eventually feeds the r550 compute fn as a
--   stronger promotion signal than a plain unsupervised completion.
--
-- STATE MACHINE (supervised_job_assignments.status):
--
--                  request_supervision()
--                          │
--                          ▼
--          ┌──────── pending_supervisor_accept ─────────┐
--          │                                            │
--          │ accept_supervision()   decline_supervision()
--          ▼                                            ▼
--        active                                      declined  (terminal)
--          │
--          │ signoff_supervision('successful')
--          │ signoff_supervision('failed' | 'disputed')
--          ▼
--   completed_successful  /  completed_failed         (terminal)
--
--   At ANY non-terminal state, founder_revoke_supervision() → revoked.
--   All transitions take FOR UPDATE on the assignment row.
--
-- TIER RANK (none=0, bronze=1, silver=2, gold=3):
--   request_supervision requires supervisor strictly out-ranks trainee.
--
-- AUDIT FINDINGS (workflow audit-22 caught & patched here):
--   CRITICAL #1 fixed — DSR gate uses r494 enum value 'signed' (not
--                       fictional 'approved'/'closed').
--   CRITICAL #2 fixed — founder_revoke_supervision now uses the r482
--                       log_founder_action() wrapper (auto-resolves
--                       actor_user_id + actor_email; the raw INSERT
--                       was missing two NOT NULL columns).
--   HIGH fixed       — UNIQUE on (trainee, job) is now PARTIAL,
--                       excluding terminal-but-not-completed states so
--                       a trainee can re-request after decline/revoke.
--   MEDIUM fixed     — disputed jobs blocked from new requests.
--   GRANT fix        — founder RPCs granted to authenticated (PostgREST
--                       Web Console role), not service_role. is_founder()
--                       is the actual authorization gate.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. supervised_job_assignments — one row per (trainee, job) ACTIVE pair
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.supervised_job_assignments (
  id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainee_user_id                 uuid NOT NULL
                                    REFERENCES auth.users(id) ON DELETE CASCADE,
  supervisor_user_id              uuid NOT NULL
                                    REFERENCES auth.users(id) ON DELETE RESTRICT,
  repair_job_id                   uuid NOT NULL
                                    REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  trainee_tier_at_assignment      text NOT NULL
                                    CHECK (trainee_tier_at_assignment IN ('none','bronze','silver','gold')),
  supervisor_tier_at_assignment   text NOT NULL
                                    CHECK (supervisor_tier_at_assignment IN ('none','bronze','silver','gold')),
  status                          text NOT NULL
                                    CHECK (status IN (
                                      'pending_supervisor_accept',
                                      'active',
                                      'completed_successful',
                                      'completed_failed',
                                      'declined',
                                      'revoked'
                                    )),
  decline_reason                  text,
  signoff_outcome                 text
                                    CHECK (signoff_outcome IN ('successful','failed','disputed')),
  signoff_notes                   text,
  requested_at                    timestamptz NOT NULL DEFAULT now(),
  accepted_at                     timestamptz,
  completed_at                    timestamptz,
  signoff_at                      timestamptz,

  -- Self-supervision is never legitimate.
  CONSTRAINT supervised_job_assignments_no_self
    CHECK (trainee_user_id <> supervisor_user_id)
);

-- HIGH fix from audit-22: partial unique allows re-request on the same
-- job after a decline/revoke (terminal-but-no-completion) — a full
-- UNIQUE would lock the trainee out with no recovery path.
CREATE UNIQUE INDEX IF NOT EXISTS supervised_job_assignments_active_per_trainee_job
  ON public.supervised_job_assignments (trainee_user_id, repair_job_id)
  WHERE status NOT IN ('declined','revoked','completed_failed');

CREATE INDEX IF NOT EXISTS supervised_job_assignments_trainee_idx
  ON public.supervised_job_assignments (trainee_user_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS supervised_job_assignments_supervisor_idx
  ON public.supervised_job_assignments (supervisor_user_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS supervised_job_assignments_status_idx
  ON public.supervised_job_assignments (status, requested_at DESC);

ALTER TABLE public.supervised_job_assignments ENABLE ROW LEVEL SECURITY;

-- Deny-all default. NO policies. All reads + writes go through SECDEF
-- RPCs. service_role retains direct table access for reconcilers and
-- the cockpit (matches r482 founder_action_log convention).
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.supervised_job_assignments
  FROM anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. _supervised_tier_rank — private helper
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public._supervised_tier_rank(text);
CREATE OR REPLACE FUNCTION public._supervised_tier_rank(p_tier text)
RETURNS int
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE p_tier
           WHEN 'none'   THEN 0
           WHEN 'bronze' THEN 1
           WHEN 'silver' THEN 2
           WHEN 'gold'   THEN 3
           ELSE NULL
         END;
$$;

REVOKE EXECUTE ON FUNCTION public._supervised_tier_rank(text)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. request_supervision — trainee opens supervision on their job
-- ---------------------------------------------------------------------
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

  -- Caller must be the accepted-bid engineer on a still-open job.
  SELECT rj.status, b.engineer_user_id
    INTO v_job_status, v_accepted_bidder
    FROM public.repair_jobs rj
    LEFT JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE rj.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = 'P0002';
  END IF;
  -- MEDIUM fix from audit-22: also block 'disputed' — opening a
  -- supervised-training row on a disputed job confuses the signal and
  -- could be used to launder credit for already-flagged bad work.
  IF v_job_status IN ('completed','cancelled','disputed') THEN
    RAISE EXCEPTION 'job in terminal state %; cannot request supervision', v_job_status
      USING ERRCODE = '0L000';
  END IF;
  IF v_accepted_bidder IS NULL OR v_accepted_bidder <> v_caller THEN
    RAISE EXCEPTION 'only the accepted-bid engineer may request supervision'
      USING ERRCODE = '42501';
  END IF;

  -- Both parties must have a certification progress row.
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

  -- Supervisor must STRICTLY out-rank trainee.
  IF v_supervisor_rank <= v_trainee_rank THEN
    RAISE EXCEPTION
      'supervisor tier (%) must be strictly higher than trainee tier (%)',
      v_supervisor_tier, v_trainee_tier
      USING ERRCODE = '0L000';
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

-- ---------------------------------------------------------------------
-- 4. accept_supervision — supervisor accepts a pending request
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.accept_supervision(uuid);
CREATE OR REPLACE FUNCTION public.accept_supervision(p_assignment_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_row    public.supervised_job_assignments;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF p_assignment_id IS NULL THEN
    RAISE EXCEPTION 'assignment_id required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
    FROM public.supervised_job_assignments
   WHERE id = p_assignment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.supervisor_user_id <> v_caller THEN
    RAISE EXCEPTION 'only the named supervisor may accept'
      USING ERRCODE = '42501';
  END IF;
  IF v_row.status <> 'pending_supervisor_accept' THEN
    RAISE EXCEPTION 'cannot accept from state %', v_row.status
      USING ERRCODE = '0L000';
  END IF;

  UPDATE public.supervised_job_assignments
     SET status      = 'active',
         accepted_at = now()
   WHERE id = p_assignment_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_supervision(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.accept_supervision(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------
-- 5. decline_supervision — supervisor refuses a pending request
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.decline_supervision(uuid, text);
CREATE OR REPLACE FUNCTION public.decline_supervision(
  p_assignment_id uuid,
  p_reason        text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_row    public.supervised_job_assignments;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF p_assignment_id IS NULL THEN
    RAISE EXCEPTION 'assignment_id required' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'decline reason required (min 10 chars)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
    FROM public.supervised_job_assignments
   WHERE id = p_assignment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.supervisor_user_id <> v_caller THEN
    RAISE EXCEPTION 'only the named supervisor may decline'
      USING ERRCODE = '42501';
  END IF;
  IF v_row.status <> 'pending_supervisor_accept' THEN
    RAISE EXCEPTION 'cannot decline from state %', v_row.status
      USING ERRCODE = '0L000';
  END IF;

  UPDATE public.supervised_job_assignments
     SET status         = 'declined',
         decline_reason = p_reason
   WHERE id = p_assignment_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.decline_supervision(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.decline_supervision(uuid, text)
  TO authenticated;

-- ---------------------------------------------------------------------
-- 6. signoff_supervision — supervisor closes an active assignment
-- ---------------------------------------------------------------------
-- CRITICAL fix from audit-22: DSR gate uses r494 enum value 'signed'
-- (not the fictional 'approved'/'closed'). r494 status enum is:
-- pending_hospital_sign | signed | disputed | invalidated.
-- 'disputed' DSR means hospital pushed back on work quality — should
-- NOT auto-credit the supervised completion.
DROP FUNCTION IF EXISTS public.signoff_supervision(uuid, text, text);
CREATE OR REPLACE FUNCTION public.signoff_supervision(
  p_assignment_id uuid,
  p_outcome       text,
  p_notes         text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller       uuid := auth.uid();
  v_row          public.supervised_job_assignments;
  v_new_status   text;
  v_has_signed_dsr boolean;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF p_assignment_id IS NULL THEN
    RAISE EXCEPTION 'assignment_id required' USING ERRCODE = '22023';
  END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('successful','failed','disputed') THEN
    RAISE EXCEPTION 'outcome must be successful|failed|disputed'
      USING ERRCODE = '22023';
  END IF;
  IF p_notes IS NULL OR length(trim(p_notes)) < 10 THEN
    RAISE EXCEPTION 'signoff notes required (min 10 chars)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
    FROM public.supervised_job_assignments
   WHERE id = p_assignment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.supervisor_user_id <> v_caller THEN
    RAISE EXCEPTION 'only the named supervisor may sign off'
      USING ERRCODE = '42501';
  END IF;
  IF v_row.status <> 'active' THEN
    RAISE EXCEPTION 'cannot signoff from state %', v_row.status
      USING ERRCODE = '0L000';
  END IF;

  -- Hospital must have signed the DSR. 'disputed' DSR does NOT count.
  SELECT EXISTS (
    SELECT 1
      FROM public.dsr_reports d
     WHERE d.repair_job_id = v_row.repair_job_id
       AND d.status = 'signed'
  ) INTO v_has_signed_dsr;

  IF NOT v_has_signed_dsr THEN
    RAISE EXCEPTION 'no signed DSR for this job; cannot sign off (hospital must accept first)'
      USING ERRCODE = '0L000';
  END IF;

  v_new_status := CASE
                    WHEN p_outcome = 'successful' THEN 'completed_successful'
                    ELSE 'completed_failed'   -- failed + disputed both
                  END;

  UPDATE public.supervised_job_assignments
     SET status          = v_new_status,
         signoff_outcome = p_outcome,
         signoff_notes   = p_notes,
         completed_at    = now(),
         signoff_at      = now()
   WHERE id = p_assignment_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.signoff_supervision(uuid, text, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.signoff_supervision(uuid, text, text)
  TO authenticated;

-- ---------------------------------------------------------------------
-- 7. founder_revoke_supervision — emergency stop with audit
-- ---------------------------------------------------------------------
-- CRITICAL fix from audit-22: uses the r482 log_founder_action()
-- wrapper instead of a raw INSERT (the raw INSERT was missing
-- actor_user_id + actor_email NOT NULL columns, which would have made
-- every founder revoke roll back).
DROP FUNCTION IF EXISTS public.founder_revoke_supervision(uuid, text);
CREATE OR REPLACE FUNCTION public.founder_revoke_supervision(
  p_assignment_id uuid,
  p_reason        text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.supervised_job_assignments;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_assignment_id IS NULL THEN
    RAISE EXCEPTION 'assignment_id required' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'revoke reason required (min 10 chars)'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
    FROM public.supervised_job_assignments
   WHERE id = p_assignment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.status IN ('completed_successful','completed_failed','declined','revoked') THEN
    RAISE EXCEPTION 'cannot revoke terminal state %', v_row.status
      USING ERRCODE = '0L000';
  END IF;

  UPDATE public.supervised_job_assignments
     SET status         = 'revoked',
         decline_reason = p_reason,
         completed_at   = now()
   WHERE id = p_assignment_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_revoke_supervision',
    p_target_table  => 'supervised_job_assignments',
    p_target_row_id => p_assignment_id,
    p_before_value  => jsonb_build_object(
                         'status', v_row.status,
                         'trainee_user_id', v_row.trainee_user_id,
                         'supervisor_user_id', v_row.supervisor_user_id,
                         'repair_job_id', v_row.repair_job_id
                       ),
    p_after_value   => jsonb_build_object('status', 'revoked'),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revoke_supervision(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_revoke_supervision(uuid, text)
  TO authenticated;

-- ---------------------------------------------------------------------
-- 8. my_supervision_progress — caller's own rows, both roles
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_supervision_progress();
CREATE OR REPLACE FUNCTION public.my_supervision_progress()
RETURNS TABLE (
  role                          text,
  assignment_id                 uuid,
  counterpart_user_id           uuid,
  repair_job_id                 uuid,
  status                        text,
  trainee_tier_at_assignment    text,
  supervisor_tier_at_assignment text,
  requested_at                  timestamptz,
  signoff_outcome               text,
  signoff_at                    timestamptz
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
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    CASE WHEN s.trainee_user_id = v_caller THEN 'trainee' ELSE 'supervisor' END AS role,
    s.id                              AS assignment_id,
    CASE WHEN s.trainee_user_id = v_caller
         THEN s.supervisor_user_id
         ELSE s.trainee_user_id
    END                               AS counterpart_user_id,
    s.repair_job_id,
    s.status,
    s.trainee_tier_at_assignment,
    s.supervisor_tier_at_assignment,
    s.requested_at,
    s.signoff_outcome,
    s.signoff_at
  FROM public.supervised_job_assignments s
  WHERE s.trainee_user_id = v_caller
     OR s.supervisor_user_id = v_caller
  ORDER BY s.requested_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_supervision_progress()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_supervision_progress()
  TO authenticated;

-- ---------------------------------------------------------------------
-- 9. founder_supervision_dashboard — cockpit aggregates
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_supervision_dashboard();
CREATE OR REPLACE FUNCTION public.founder_supervision_dashboard()
RETURNS TABLE (
  status               text,
  assignment_count     int,
  total_in_progress    int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_in_progress int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*)::int INTO v_in_progress
    FROM public.supervised_job_assignments
   WHERE status IN ('pending_supervisor_accept','active');

  RETURN QUERY
  WITH all_statuses(s) AS (
    VALUES
      ('pending_supervisor_accept'),
      ('active'),
      ('completed_successful'),
      ('completed_failed'),
      ('declined'),
      ('revoked')
  )
  SELECT
    a.s                                       AS status,
    coalesce(
      (SELECT count(*)::int
         FROM public.supervised_job_assignments sa
        WHERE sa.status = a.s),
      0
    )                                         AS assignment_count,
    v_in_progress                             AS total_in_progress
  FROM all_statuses a
  ORDER BY
    CASE a.s
      WHEN 'pending_supervisor_accept' THEN 1
      WHEN 'active'                    THEN 2
      WHEN 'completed_successful'      THEN 3
      WHEN 'completed_failed'          THEN 4
      WHEN 'declined'                  THEN 5
      WHEN 'revoked'                   THEN 6
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_supervision_dashboard()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervision_dashboard()
  TO authenticated;

COMMIT;
