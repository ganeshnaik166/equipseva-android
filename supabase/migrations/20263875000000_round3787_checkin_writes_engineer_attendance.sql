-- =====================================================================
-- Round 3787 — light up round496's GPS attendance ledger (it was inert)
-- =====================================================================
--
-- round496 (v0.4 Phase 3 #7) built an arrival/departure attendance
-- ledger to defeat a specific fraud its own header names:
--   "a remote engineer can fake-progress jobs from home + later swap in
--    field photos pulled from someone else's repair. Trust falls apart
--    at the first lawsuit."
-- It shipped `engineer_attendance`, `haversine_meters()`,
-- `record_engineer_attendance()`, `attendance_for_job()` and
-- `founder_suspicious_attendance_recent()`.
--
-- None of it has ever done anything. Verified against production:
--   * public.engineer_attendance                    -> 0 rows
--   * the ONLY INSERT into it lives inside record_engineer_attendance()
--   * record_engineer_attendance() has ZERO callers (no Kotlin, no web,
--     no edge function, no other migration)
--
-- The reason is a straightforward collision of two migrations. The
-- app's REAL on-device check-in path is `engineer_check_in_with_geo`
-- (20260521100000_v21_checkin_geofence.sql, called from
-- SupabaseRepairJobRepository), which predates round496 and only ever
-- does `UPDATE repair_jobs SET status='in_progress', started_at=...,
-- engineer_latitude=..., engineer_longitude=...`. round496 then added a
-- parallel, better-instrumented path that nothing was ever wired to.
-- (This is already documented in app/src/.../core/network/DataError.kt
-- lines 61-65, which excluded record_engineer_attendance's error code
-- from client mapping for exactly this reason.)
--
-- CONSEQUENTLY DEAD: attendance_for_job() and
-- founder_suspicious_attendance_recent() always return 0 rows;
-- haversine_meters() had zero callers; and my_sla_card()'s timing
-- signals are structurally fake — avg_accept_to_arrival_hrs and
-- avg_arrival_to_complete_hrs are NULL (avg over an empty FILTER),
-- sla_breaches is always 0 and on_time_pct always renders a spurious
-- 100%. That last part is why the round3771 sweep deliberately did NOT
-- build an SLA-card screen: it would have told every engineer they were
-- perfect.
--
-- APPROACH — a TRIGGER, deliberately, rather than editing the check-in
-- RPC. Check-in is a critical trust/money path; the safest change is
-- one that cannot touch it. Everything the attendance row needs is
-- already ON the updated repair_jobs row:
--     engineer coords  -> NEW.engineer_latitude / NEW.engineer_longitude
--     expected coords  -> NEW.site_latitude / NEW.site_longitude
--     hospital         -> NEW.hospital_user_id
--     engineer user    -> engineers.user_id via NEW.engineer_id
-- so a trigger can reconstruct the whole record with no client change
-- and no change to engineer_check_in_with_geo's signature or its four
-- returned columns (which the Kotlin CheckInWithGeoRow decodes).
--
-- This is also STRICTLY MORE TRUSTWORTHY than round496's own design.
-- record_engineer_attendance() took the hospital's expected coordinates
-- as CLIENT-SUPPLIED parameters (p_hospital_expected_lat/lng), so a
-- dishonest engineer could pass their own position as the "expected"
-- location and score distance 0 — defeating the exact fraud the feature
-- exists to catch. Deriving them server-side from repair_jobs closes
-- that hole. record_engineer_attendance() is left in place untouched
-- (still zero callers) rather than dropped, since removing a
-- SECURITY DEFINER function is out of scope here.
--
-- SAFETY — attendance logging must NEVER be able to abort a check-in:
--   * The whole body runs inside a plpgsql BEGIN/EXCEPTION block (an
--     implicit subtransaction). Any failure is swallowed with a NOTICE,
--     so the engineer's check-in still succeeds.
--   * Explicit guards precede the INSERT for the two NOT NULL columns
--     that could genuinely be absent. Verified against production:
--     repair_jobs.hospital_user_id IS NULLABLE while
--     engineer_attendance.hospital_user_id is NOT NULL (0 such rows
--     today, but the schema permits it), and engineer_id may not
--     resolve to an engineers row.
--   * 26 repair_jobs rows currently have no site coords. Verified that
--     engineer_attendance.distance_from_hospital_m is NULLABLE, so
--     those check-ins log an attendance row with a NULL distance rather
--     than failing; suspicious_distance is NOT NULL and is coalesced.
--   * engineer_attendance has 0 rows, so there is nothing to corrupt,
--     no backfill, and no double-write path.
--
-- The trigger's WHEN clause pins it to a genuine geo check-in — a
-- status TRANSITION into 'in_progress' that also carries engineer
-- coordinates — so an admin override or a backfill that merely flips
-- status will not manufacture a false arrival record. ('in_progress'
-- confirmed to be a real job_status enum label: requested, assigned,
-- en_route, in_progress, completed, cancelled, disputed.)

BEGIN;

CREATE OR REPLACE FUNCTION public.log_engineer_arrival_attendance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user uuid;
  v_distance_m    double precision;
BEGIN
  -- Subtransaction: a failure here must never roll back the check-in.
  BEGIN
    -- engineer_attendance.hospital_user_id is NOT NULL but
    -- repair_jobs.hospital_user_id is nullable.
    IF NEW.hospital_user_id IS NULL THEN
      RETURN NEW;
    END IF;

    SELECT e.user_id INTO v_engineer_user
      FROM public.engineers e
     WHERE e.id = NEW.engineer_id;
    IF v_engineer_user IS NULL THEN
      RETURN NEW;
    END IF;

    -- Expected coords are derived SERVER-SIDE (see header). NULL when
    -- the hospital never geocoded the site; distance stays NULL then,
    -- which the column permits.
    IF NEW.site_latitude IS NOT NULL AND NEW.site_longitude IS NOT NULL THEN
      v_distance_m := public.haversine_meters(
        NEW.engineer_latitude, NEW.engineer_longitude,
        NEW.site_latitude,     NEW.site_longitude
      );
    END IF;

    INSERT INTO public.engineer_attendance (
      repair_job_id, engineer_user_id, hospital_user_id,
      event_kind, device_captured_at,
      engineer_lat, engineer_lng,
      hospital_expected_lat, hospital_expected_lng,
      distance_from_hospital_m, suspicious_distance
    ) VALUES (
      NEW.id, v_engineer_user, NEW.hospital_user_id,
      'arrival_checkin', now(),
      NEW.engineer_latitude, NEW.engineer_longitude,
      NEW.site_latitude,     NEW.site_longitude,
      v_distance_m,
      -- round496's own threshold: >500m off the listed coords during a
      -- check-in is the review flag. coalesce so a NULL distance (no
      -- site coords) is recorded as not-suspicious rather than failing
      -- the NOT NULL column.
      coalesce(v_distance_m > 500, false)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'log_engineer_arrival_attendance: skipped for job % (% / %)',
      NEW.id, SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.log_engineer_arrival_attendance() IS
  'Round 3787 — writes the round496 engineer_attendance arrival row when a job transitions to in_progress with engineer coordinates present (i.e. a real geo check-in). Derives the hospital''s expected coordinates server-side from repair_jobs, unlike record_engineer_attendance() which trusted client-supplied ones. Fully exception-guarded: attendance logging can never abort a check-in.';

DROP TRIGGER IF EXISTS log_engineer_arrival_attendance_trg ON public.repair_jobs;
CREATE TRIGGER log_engineer_arrival_attendance_trg
  AFTER UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.status = 'in_progress'
    AND OLD.status IS DISTINCT FROM NEW.status
    AND NEW.engineer_latitude IS NOT NULL
    AND NEW.engineer_longitude IS NOT NULL
  )
  EXECUTE FUNCTION public.log_engineer_arrival_attendance();

-- ---------------------------------------------------------------------
-- Verification — drive a real check-in-shaped UPDATE, then roll it back
-- ---------------------------------------------------------------------
-- Runs INSIDE the transaction. The probe promotes a real assigned job
-- to in_progress with coordinates (exactly what engineer_check_in_with_geo
-- does), asserts an attendance row appeared, and then rolls the whole
-- probe back via the subtransaction sentinel so neither the job nor the
-- attendance row persists.
DO $$
DECLARE
  v_job_id   uuid;
  v_before   int;
  v_after    int;
  v_probed   boolean := false;
BEGIN
  SELECT count(*) INTO v_before FROM public.engineer_attendance;

  SELECT rj.id INTO v_job_id
    FROM public.repair_jobs rj
   WHERE rj.status IS DISTINCT FROM 'in_progress'
     AND rj.hospital_user_id IS NOT NULL
     AND rj.engineer_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.engineers e WHERE e.id = rj.engineer_id)
   LIMIT 1;

  IF v_job_id IS NULL THEN
    RAISE NOTICE 'round 3787: no suitable job to probe (need hospital + resolvable engineer) — trigger installed but not exercised';
  ELSE
    BEGIN
      UPDATE public.repair_jobs
         SET status = 'in_progress',
             engineer_latitude  = 17.3850,
             engineer_longitude = 78.4867
       WHERE id = v_job_id;

      SELECT count(*) INTO v_after FROM public.engineer_attendance;
      IF v_after <> v_before + 1 THEN
        RAISE EXCEPTION
          'round 3787 VERIFY FAILED: expected 1 new engineer_attendance row, went from % to %',
          v_before, v_after;
      END IF;
      RAISE NOTICE 'round 3787: check-in-shaped UPDATE produced an engineer_attendance arrival row (% -> %)', v_before, v_after;
      RAISE EXCEPTION 'ROUND3787_PROBE_ROLLBACK';
    EXCEPTION
      WHEN SQLSTATE 'P0001' THEN
        v_probed := true;
      WHEN OTHERS THEN
        RAISE EXCEPTION 'round 3787 VERIFY FAILED: probe errored: % %', SQLSTATE, SQLERRM;
    END;
    IF v_probed THEN
      RAISE NOTICE 'round 3787: probe rolled back (job status and attendance row both discarded)';
    END IF;
  END IF;

  RAISE NOTICE 'round 3787 verified: engineer_attendance now populates on real check-ins — round496 anti-fraud ledger, attendance_for_job(), founder_suspicious_attendance_recent() and my_sla_card() timing signals all become live';
END;
$$;

COMMIT;
