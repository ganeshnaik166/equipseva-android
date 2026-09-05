-- =====================================================================
-- Round 3806 -- the verification timestamp `engineers` never had
-- =====================================================================
--
-- FOUNDER-APPROVED (2026-09-05): this is decision #2 from
-- docs/SWEEP_METRIC_REDEFINITIONS.md, approved together with wiring the
-- unscheduled cron jobs, because it is what makes the KYC-renewal jobs
-- actually functional.
--
-- THE GAP: nothing recorded when an engineer's verification status last
-- changed. At least five shipped call sites want that timestamp
-- (schedule_engineer_kyc_renewals reads it; founder_complete_kyc_renewal
-- and reap_expired_kyc_renewals historically wrote it; round493's
-- pre-visit dossier reads it; three founder latency metrics want it).
-- The sweep repaired those sites to DOCUMENT the absence rather than
-- invent a proxy, because the obvious proxy was dangerous: backfilling
-- from created_at would hand every engineer onboarded >379 days ago an
-- already-expired renewal, and the daily reaper would then flip them to
-- verification_status='pending' and drop them from the hospital
-- directory with no notice.
--
-- WHAT THIS DOES
--   1. Adds engineers.verification_status_updated_at timestamptz.
--   2. Backfills now() -- NOT created_at, see above -- for the 16
--      currently-verified engineers. Their first annual renewal窗口
--      therefore starts today, which is the only honest reading given
--      the platform never recorded the real approval date.
--   3. Makes the column SERVER-AUTHORITATIVE with a stamping trigger:
--      any INSERT, and any UPDATE that changes verification_status,
--      sets it to now() regardless of what the caller supplied. So
--      every path that flips status -- admin RPCs, the reaper, future
--      code -- stamps it without each site needing to remember to.
--   4. Extends engineers_trust_columns_guard so a non-admin cannot move
--      the timestamp WITHOUT a status change (an engineer pushing their
--      own renewal date forward would postpone re-KYC indefinitely).
--      The condition deliberately tolerates the stamping trigger's own
--      write: a timestamp change accompanied by a status change is
--      allowed through the guard and then overwritten to now() by the
--      stamp anyway, so trigger firing order cannot matter.
--   5. Repairs founder_kyc_pipeline_snapshot_summary, one of the sweep's
--      nine documented refusals -- it was declined precisely because
--      this column did not exist. Two defects fixed together:
--        * 'in_review' x5 -- not a verification_status label
--          (pending/verified/rejected), a latent 22P02. Inside
--          IN ('pending','in_review') the dead literal just drops out.
--        * e.verified_at x3 -> e.verification_status_updated_at. Those
--          predicates already require verification_status='verified',
--          under which the new column IS the approval time.
--
-- WHAT THIS DELIBERATELY DOES NOT DO: re-point the other proxy-documented
-- readers (founder_verified_engineers_recent shows signup date labelled
-- as verified_at, build_pved returns NULL, onboarding-velocity latencies
-- report 0). Their honest-but-degraded behaviour only becomes wrong to
-- keep once REAL approval timestamps accumulate; they are follow-up, and
-- listed in docs/SWEEP_METRIC_REDEFINITIONS.md.
--
-- VERIFY runs inside the transaction (round3781) and, per round3793,
-- EXECUTES the write paths rather than trusting static checks:
--   * the stamping trigger is fired by a real status flip and asserted
--     to bump the timestamp (then rolled back via subtransaction);
--   * the guard is asserted to REJECT a non-admin moving the timestamp
--     without a status change (42501);
--   * schedule_engineer_kyc_renewals() is EXECUTED -- with everything
--     backfilled to now(), it must create exactly 0 renewals; a nonzero
--     count would be the created_at mass-expiry bug this design avoids;
--   * founder_kyc_pipeline_snapshot_summary() is executed as the founder.
-- Per round3802, this gate has no blanket exception handler and fails on
-- any probe error.

BEGIN;

-- 1. the column ------------------------------------------------------
ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS verification_status_updated_at timestamptz;

COMMENT ON COLUMN public.engineers.verification_status_updated_at IS
  'When verification_status last changed. Server-authoritative: stamped by '
  'stamp_engineer_verification_status_change() on INSERT and on every status '
  'change; guarded against direct client writes by engineers_trust_columns_guard. '
  'Backfilled to the round3806 migration time for engineers already verified, '
  'because the real approval dates were never recorded (round3806).';

-- 2. backfill: now(), NOT created_at ---------------------------------
UPDATE public.engineers
   SET verification_status_updated_at = now()
 WHERE verification_status = 'verified'
   AND verification_status_updated_at IS NULL;

-- 3. server-authoritative stamping -----------------------------------
CREATE OR REPLACE FUNCTION public.stamp_engineer_verification_status_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF TG_OP = 'INSERT'
     OR NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    NEW.verification_status_updated_at := now();
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS stamp_engineer_verification_status_trg ON public.engineers;
CREATE TRIGGER stamp_engineer_verification_status_trg
  BEFORE INSERT OR UPDATE ON public.engineers
  FOR EACH ROW
  EXECUTE FUNCTION public.stamp_engineer_verification_status_change();

-- 4. guard: non-admins cannot move the timestamp on its own ----------
-- (Full definition preserved from the live guard; the ONLY change is the
--  one new condition, marked "round3806".)
CREATE OR REPLACE FUNCTION public.engineers_trust_columns_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role' OR session_user = 'postgres' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'verification_status flip to % requires admin', NEW.verification_status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.rating_avg IS DISTINCT FROM OLD.rating_avg
       OR NEW.total_jobs IS DISTINCT FROM OLD.total_jobs
       OR NEW.completion_rate IS DISTINCT FROM OLD.completion_rate
       OR NEW.total_earnings IS DISTINCT FROM OLD.total_earnings
       OR NEW.background_check_status IS DISTINCT FROM OLD.background_check_status
       OR NEW.verification_notes IS DISTINCT FROM OLD.verification_notes
       OR NEW.rejected_doc_types IS DISTINCT FROM OLD.rejected_doc_types
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.cash_auto_suspended_at IS DISTINCT FROM OLD.cash_auto_suspended_at
       OR NEW.cash_auto_suspension_reason IS DISTINCT FROM OLD.cash_auto_suspension_reason
       -- round3806: the KYC-renewal clock may not be moved by its owner.
       -- Tolerate the stamping trigger: a timestamp change that rides on a
       -- status change is fine (and gets overwritten to now() anyway).
       OR (NEW.verification_status_updated_at IS DISTINCT FROM OLD.verification_status_updated_at
           AND NEW.verification_status IS NOT DISTINCT FROM OLD.verification_status)
    THEN
      RAISE EXCEPTION 'cannot modify admin / computed engineers columns'
        USING ERRCODE = '42501';
    END IF;
    -- Block engineer from un-pausing themselves while auto-suspended.
    IF OLD.cash_auto_suspended_at IS NOT NULL
       AND NEW.is_available = true
       AND coalesce(OLD.is_available, false) = false THEN
      RAISE EXCEPTION 'engineer is suspended pending review'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'engineers row must start at verification_status=pending'
        USING ERRCODE = '42501';
    END IF;
    IF coalesce(NEW.rating_avg, 0) <> 0
       OR coalesce(NEW.total_jobs, 0) <> 0
       OR coalesce(NEW.completion_rate, 0) <> 0
       OR coalesce(NEW.total_earnings, 0) <> 0 THEN
      RAISE EXCEPTION 'engineers stats must start at zero'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 5. repair the declined pipeline function ---------------------------
CREATE OR REPLACE FUNCTION public.founder_kyc_pipeline_snapshot_summary()
 RETURNS TABLE(engineer_pending bigint, engineer_rejected bigint, engineer_pending_0_7d bigint, engineer_pending_7_30d bigint, engineer_pending_over_30d bigint, engineer_oldest_age_days integer, buyer_pending bigint, buyer_rejected bigint, buyer_pending_0_7d bigint, buyer_pending_7_30d bigint, buyer_pending_over_30d bigint, rekyc_due_30d bigint, rekyc_overdue bigint, rekyc_grace_expiring_7d bigint, engineer_intake_today bigint, engineer_verified_today bigint, engineer_verified_30d bigint, buyer_intake_today bigint, buyer_verified_today bigint, buyer_verified_30d bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- Engineer KYC backlog
    -- round3806: 'in_review' is not a verification_status label
    -- (pending/verified/rejected) -- the original IN list raised 22P02.
    -- The dead literal drops out; the live semantics are unchanged.
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status::text,'pending') = 'pending'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'rejected'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status::text,'pending') = 'pending'
        AND e.created_at >= now() - interval '7 days'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status::text,'pending') = 'pending'
        AND e.created_at <  now() - interval '7 days'
        AND e.created_at >= now() - interval '30 days'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status::text,'pending') = 'pending'
        AND e.created_at <  now() - interval '30 days'),
    coalesce((SELECT (extract(epoch FROM (now() - min(e.created_at)))::int / 86400)
                FROM public.engineers e
               WHERE coalesce(e.verification_status::text,'pending') = 'pending'), 0),

    -- Buyer KYC backlog
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b WHERE b.status = 'pending'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b WHERE b.status = 'rejected'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending' AND b.submitted_at >= now() - interval '7 days'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending'
        AND b.submitted_at <  now() - interval '7 days'
        AND b.submitted_at >= now() - interval '30 days'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending' AND b.submitted_at < now() - interval '30 days'),

    -- Re-KYC pipeline
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.due_at <= now() + interval '30 days'),
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.due_at < now()),
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.grace_until <= now() + interval '7 days'),

    -- Intake vs approval -- engineer side
    -- round3806: e.verified_at never existed; the real approval time is
    -- verification_status_updated_at (valid here because the predicate
    -- already requires verification_status='verified').
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.created_at >= v_today_start AND e.created_at < v_today_end),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'verified'
        AND e.verification_status_updated_at >= v_today_start
        AND e.verification_status_updated_at < v_today_end),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'verified'
        AND e.verification_status_updated_at >= now() - interval '30 days'),

    -- Intake vs approval -- buyer side
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.submitted_at >= v_today_start AND b.submitted_at < v_today_end),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'verified'
        AND b.reviewed_at >= v_today_start AND b.reviewed_at < v_today_end),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'verified'
        AND b.reviewed_at >= now() - interval '30 days');
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_n        int;
  v_before   timestamptz;
  v_after    timestamptz;
  v_eng      uuid;
  v_owner    uuid;
  v_renewals int;
  v_created  int;
BEGIN
  -- column present + backfill covered every verified engineer
  SELECT count(*) INTO v_n FROM public.engineers
   WHERE verification_status = 'verified' AND verification_status_updated_at IS NULL;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'round 3806 VERIFY FAILED: % verified engineer(s) missing the backfill', v_n;
  END IF;

  -- 1. stamping trigger: a real status flip must bump the timestamp.
  --    Subtlety the first run of this gate caught in ITSELF: now() is
  --    TRANSACTION-stable, so the backfill above and the trigger's stamp
  --    yield the identical value inside this one migration transaction --
  --    "before == after" was true by construction, not because the
  --    trigger failed. The probe therefore AGES the timestamp first
  --    (a direct write, no status change, which the stamp leaves alone
  --    and postgres may make), then flips status and requires the stamp
  --    to overwrite the aged value. Everything rolls back.
  SELECT e.id, e.user_id, e.verification_status_updated_at
    INTO v_eng, v_owner, v_before
    FROM public.engineers e WHERE e.verification_status = 'verified' LIMIT 1;
  BEGIN
    UPDATE public.engineers
       SET verification_status_updated_at = now() - interval '1 year'
     WHERE id = v_eng;
    SELECT verification_status_updated_at INTO v_after FROM public.engineers WHERE id = v_eng;
    IF v_after IS DISTINCT FROM (now() - interval '1 year') THEN
      RAISE EXCEPTION 'round 3806 VERIFY FAILED: stamp overwrote a timestamp-only write (aging set %, read back %)', now() - interval '1 year', v_after;
    END IF;

    UPDATE public.engineers SET verification_status = 'rejected' WHERE id = v_eng;
    SELECT verification_status_updated_at INTO v_after FROM public.engineers WHERE id = v_eng;
    IF v_after IS NULL OR v_after < now() THEN
      RAISE EXCEPTION 'round 3806 VERIFY FAILED: status flip did not restamp (aged -1y, read back %)', v_after;
    END IF;
    RAISE EXCEPTION 'R3806_PROBE_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'R3806_PROBE_ROLLBACK' THEN RAISE; END IF;
  END;
  SELECT verification_status_updated_at INTO v_after FROM public.engineers WHERE id = v_eng;
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'round 3806 VERIFY FAILED: stamp probe leaked (% -> %)', v_before, v_after;
  END IF;

  -- 2. guard: the row's OWNER may not move the timestamp on its own
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_owner::text, 'role', 'authenticated',
                        'email', 'guard-probe@invalid')::text, true);
    PERFORM set_config('role', 'authenticated', true);
    UPDATE public.engineers
       SET verification_status_updated_at = now() + interval '300 days'
     WHERE id = v_eng;
    RAISE EXCEPTION 'round 3806 VERIFY FAILED: owner moved the renewal clock unchallenged';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;  -- 42501 from the guard (or RLS): exactly what we want
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', NULL, true);

  -- 3. the scheduler must now RUN, and must create ZERO renewals today
  --    (everything was backfilled to now(); a nonzero count here is the
  --    created_at mass-expiry bug this design exists to avoid)
  SELECT count(*) INTO v_renewals FROM public.engineer_kyc_renewals;
  v_created := public.schedule_engineer_kyc_renewals();
  SELECT count(*) - v_renewals INTO v_n FROM public.engineer_kyc_renewals;
  IF coalesce(v_created, v_n) <> 0 OR v_n <> 0 THEN
    RAISE EXCEPTION 'round 3806 VERIFY FAILED: scheduler created % renewal(s) on a fresh backfill -- mass-expiry hazard', greatest(coalesce(v_created,0), v_n);
  END IF;

  -- 4. the repaired pipeline summary executes for the founder
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);
  SELECT count(*) INTO v_n FROM public.founder_kyc_pipeline_snapshot_summary();
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'round 3806 VERIFY FAILED: pipeline summary returned % row(s)', v_n;
  END IF;

  RAISE NOTICE 'round 3806 verified: column + backfill + stamp trigger + guard + scheduler(0 created) + pipeline summary all proven';
END
$gate$;

COMMIT;
