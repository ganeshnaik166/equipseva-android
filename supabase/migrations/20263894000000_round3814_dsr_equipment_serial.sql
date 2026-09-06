-- =====================================================================
-- Round 3814 -- the engineer can record the equipment serial in the DSR
-- =====================================================================
--
-- WHY: the NABH audit bundle (nabh_bundle_for_equipment / export_nabh_bundle)
-- is keyed on equipment_serial, and the DSR snapshots the serial FROM THE
-- JOB. Measured in production: 35 of 39 repair jobs (90%) were booked
-- with no serial at all, so the first real DSR (round3812) has none and
-- the bundle RPC correctly refuses it ("equipment_serial required").
-- Hospitals book without the serial; the engineer is the one standing in
-- front of the device plate. So submit_dsr gains an optional
-- p_equipment_serial:
--   * when given, it is the ENGINEER'S ATTESTATION and becomes the DSR's
--     serial (the DSR is the engineer's signed record);
--   * it back-fills repair_jobs.equipment_serial ONLY where the job has
--     none -- a hospital-entered serial is never overwritten; a conflict
--     leaves the job's value alone and the DSR carrying the on-site
--     reading, which is exactly the discrepancy an auditor would want
--     visible rather than silently reconciled;
--   * when blank, behaviour is unchanged (job's serial, possibly NULL).
-- dsr_for_job returns equipment_serial so the record view shows what was
-- attested.
--
-- BOTH CHANGES ALTER A SIGNATURE, and this is the round3791 discipline:
--   * adding a DEFAULTed parameter via CREATE OR REPLACE would create a
--     SECOND OVERLOAD; PostgREST dispatching 11 named params would then
--     match both (defaults fill the 12th) -> PGRST203 ambiguity for every
--     caller. So the old function is DROPPED first.
--   * DROP discards the ACL, and Supabase's default privileges then grant
--     EXECUTE to anon/authenticated/service_role on the new function --
--     anon included. The ACL is captured before the drop, everything is
--     revoked after the create (PUBLIC, anon, authenticated, service_role)
--     and exactly the captured grants are replayed. The gate asserts the
--     result is identical in both directions and that nothing is
--     anon-executable.
-- The only clients are this app's DsrRepository (round3812) and the
-- founder role; both send named params, so the 11-arg calls keep working.

BEGIN;

CREATE TEMP TABLE _r3814_acl ON COMMIT DROP AS
SELECT p.proname, a.grantee::regrole::text AS grantee, a.privilege_type AS priv
FROM pg_proc p
CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname IN ('submit_dsr', 'dsr_for_job')
  AND a.grantee <> 0;   -- 0 = PUBLIC; we never want that replayed

DROP FUNCTION public.submit_dsr(uuid, jsonb, boolean, jsonb, boolean, boolean, jsonb, text, jsonb, text, text);
DROP FUNCTION public.dsr_for_job(uuid);

CREATE FUNCTION public.submit_dsr(
  p_repair_job_id         uuid,
  p_pre_post_readings     jsonb,
  p_iec_62353_passed      boolean,
  p_iec_62353_readings    jsonb,
  p_calibration_performed boolean,
  p_calibration_within_oem boolean,
  p_calibration_readings  jsonb,
  p_calibration_lab_ref   text,
  p_parts_replaced        jsonb,
  p_work_summary          text,
  p_recommendations       text DEFAULT NULL,
  p_equipment_serial      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller        uuid := auth.uid();
  v_job           record;
  v_engineer_user uuid;
  v_dsr_id        uuid;
  v_serial        text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_work_summary IS NULL OR length(trim(p_work_summary)) < 20 THEN
    RAISE EXCEPTION 'work_summary required (min 20 chars)' USING ERRCODE = '22023';
  END IF;
  -- round3814: optional on-site serial reading; blank = not provided
  v_serial := nullif(trim(p_equipment_serial), '');
  IF v_serial IS NOT NULL AND length(v_serial) > 64 THEN
    RAISE EXCEPTION 'equipment_serial too long (max 64)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT engineer_user_id INTO v_engineer_user
    FROM public.repair_job_bids
   WHERE repair_job_id = p_repair_job_id
     AND status = 'accepted'
   LIMIT 1;
  IF v_engineer_user IS NULL THEN
    RAISE EXCEPTION 'no_accepted_engineer' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_engineer_user AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'engineer_only_can_submit_dsr' USING ERRCODE = '42501';
  END IF;

  -- The engineer's reading wins for the DSR; the job's value is the
  -- fallback. Back-fill the job ONLY when it has no serial of its own.
  IF v_serial IS NOT NULL AND nullif(trim(v_job.equipment_serial), '') IS NULL THEN
    UPDATE public.repair_jobs
       SET equipment_serial = v_serial
     WHERE id = p_repair_job_id;
  END IF;
  v_serial := coalesce(v_serial, nullif(trim(v_job.equipment_serial), ''));

  -- Idempotency: one DSR per job. Re-submit replaces.
  DELETE FROM public.dsr_reports WHERE repair_job_id = p_repair_job_id;

  INSERT INTO public.dsr_reports (
    repair_job_id, engineer_user_id, hospital_user_id,
    equipment_brand, equipment_model, equipment_serial, equipment_type,
    pre_post_readings, iec_62353_passed, iec_62353_readings,
    calibration_performed, calibration_within_oem, calibration_readings, calibration_lab_ref,
    parts_replaced, work_summary, recommendations,
    engineer_signature_at, status
  ) VALUES (
    p_repair_job_id, v_engineer_user, v_job.hospital_user_id,
    v_job.equipment_brand, v_job.equipment_model, v_serial, v_job.equipment_type::text,
    coalesce(p_pre_post_readings, '[]'::jsonb),
    p_iec_62353_passed, coalesce(p_iec_62353_readings, '[]'::jsonb),
    coalesce(p_calibration_performed, false),
    p_calibration_within_oem,
    coalesce(p_calibration_readings, '[]'::jsonb), p_calibration_lab_ref,
    coalesce(p_parts_replaced, '[]'::jsonb),
    p_work_summary, p_recommendations,
    now(), 'pending_hospital_sign'
  ) RETURNING id INTO v_dsr_id;

  RETURN v_dsr_id;
END;
$$;

CREATE FUNCTION public.dsr_for_job(p_repair_job_id uuid)
RETURNS TABLE(
  id                     uuid,
  status                 text,
  engineer_signature_at  timestamptz,
  hospital_signature_at  timestamptz,
  iec_62353_passed       boolean,
  calibration_within_oem boolean,
  work_summary           text,
  recommendations        text,
  pre_post_readings      jsonb,
  parts_replaced         jsonb,
  equipment_serial       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT d.id, d.status, d.engineer_signature_at, d.hospital_signature_at,
         d.iec_62353_passed, d.calibration_within_oem,
         d.work_summary, d.recommendations, d.pre_post_readings, d.parts_replaced,
         d.equipment_serial
    FROM public.dsr_reports d
   WHERE d.repair_job_id = p_repair_job_id
     AND (d.hospital_user_id = auth.uid() OR d.engineer_user_id = auth.uid() OR public.is_founder());
END;
$$;

-- Strip the default privileges (anon included), then replay exactly what was captured.
REVOKE ALL ON FUNCTION public.submit_dsr(uuid, jsonb, boolean, jsonb, boolean, boolean, jsonb, text, jsonb, text, text, text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.dsr_for_job(uuid) FROM PUBLIC, anon, authenticated, service_role;

DO $regrant$
DECLARE r record; v_n int := 0;
BEGIN
  FOR r IN SELECT * FROM _r3814_acl LOOP
    IF r.proname = 'submit_dsr' THEN
      EXECUTE format('GRANT %s ON FUNCTION public.submit_dsr(uuid, jsonb, boolean, jsonb, boolean, boolean, jsonb, text, jsonb, text, text, text) TO %I', r.priv, r.grantee);
    ELSE
      EXECUTE format('GRANT %s ON FUNCTION public.dsr_for_job(uuid) TO %I', r.priv, r.grantee);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'round 3814: replayed % grant(s)', v_n;
END
$regrant$;

-- ---------------------------------------------------------------------
-- VERIFY
-- ---------------------------------------------------------------------
DO $gate$
DECLARE
  v_n int; v_bad text; v_eng uuid; v_job uuid; v_hosp uuid;
  v_dsr uuid; v_dsr_serial text; v_job_serial text; v_read int;
BEGIN
  -- 1. exactly ONE overload each (the whole point of the DROP)
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='submit_dsr';
  IF v_n <> 1 THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: submit_dsr has % overload(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='dsr_for_job';
  IF v_n <> 1 THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: dsr_for_job has % overload(s)', v_n; END IF;

  -- 2. ACL identical to the capture, both directions; nothing anon/PUBLIC-executable
  SELECT string_agg(x, ', ') INTO v_bad FROM (
    SELECT c.proname||':'||c.grantee||'='||c.priv AS x FROM _r3814_acl c
    EXCEPT
    SELECT p.proname||':'||a.grantee::regrole::text||'='||a.privilege_type
      FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE p.pronamespace='public'::regnamespace AND p.proname IN ('submit_dsr','dsr_for_job')
       AND a.grantee <> 0
  ) q;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: grant(s) lost: %', v_bad; END IF;
  SELECT string_agg(x, ', ') INTO v_bad FROM (
    SELECT p.proname||':'||coalesce(nullif(a.grantee,0)::regrole::text,'PUBLIC')||'='||a.privilege_type AS x
      FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE p.pronamespace='public'::regnamespace AND p.proname IN ('submit_dsr','dsr_for_job')
    EXCEPT
    SELECT c.proname||':'||c.grantee||'='||c.priv FROM _r3814_acl c
  ) q;
  IF v_bad IS NOT NULL THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: unexpected grant(s): %', v_bad; END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
              AND p.proname IN ('submit_dsr','dsr_for_job')
              AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                   OR has_function_privilege(0, p.oid, 'EXECUTE'))) THEN
    RAISE EXCEPTION 'round 3814 VERIFY FAILED: anon/PUBLIC can execute a DSR function';
  END IF;

  -- 3. live behaviour, rolled back: serial attested + job back-filled only when blank
  SELECT id INTO v_eng FROM auth.users WHERE lower(email)='play-review-engineer@equipseva.com';
  SELECT b.repair_job_id, rj.hospital_user_id INTO v_job, v_hosp
    FROM public.repair_job_bids b JOIN public.repair_jobs rj ON rj.id=b.repair_job_id
   WHERE b.status='accepted' AND b.engineer_user_id=v_eng LIMIT 1;
  IF v_job IS NULL THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: no accepted-bid job to probe'; END IF;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_eng::text,'role','authenticated')::text, true);
    UPDATE public.repair_jobs SET equipment_serial = NULL WHERE id = v_job;        -- start blank
    v_dsr := public.submit_dsr(v_job, '[]', true, '[]', false, NULL, '[]', NULL, '[]',
              'round3814 probe: serial attested on-site by the engineer.', NULL, '  SN-R3814-PROBE  ');
    SELECT equipment_serial INTO v_dsr_serial FROM public.dsr_reports WHERE id = v_dsr;
    SELECT equipment_serial INTO v_job_serial FROM public.repair_jobs WHERE id = v_job;
    IF v_dsr_serial <> 'SN-R3814-PROBE' OR v_job_serial <> 'SN-R3814-PROBE' THEN
      RAISE EXCEPTION 'round 3814 VERIFY FAILED: attested serial not applied (dsr=% job=%)', v_dsr_serial, v_job_serial;
    END IF;
    -- hospital-entered serial must NOT be overwritten by a differing reading
    UPDATE public.repair_jobs SET equipment_serial = 'HOSP-ENTERED' WHERE id = v_job;
    v_dsr := public.submit_dsr(v_job, '[]', true, '[]', false, NULL, '[]', NULL, '[]',
              'round3814 probe: conflicting on-site reading.', NULL, 'ENG-READ');
    SELECT equipment_serial INTO v_dsr_serial FROM public.dsr_reports WHERE id = v_dsr;
    SELECT equipment_serial INTO v_job_serial FROM public.repair_jobs WHERE id = v_job;
    IF v_dsr_serial <> 'ENG-READ' OR v_job_serial <> 'HOSP-ENTERED' THEN
      RAISE EXCEPTION 'round 3814 VERIFY FAILED: conflict handling wrong (dsr=% job=%)', v_dsr_serial, v_job_serial;
    END IF;
    -- blank param falls back to the job's serial; reader exposes it
    v_dsr := public.submit_dsr(v_job, '[]', true, '[]', false, NULL, '[]', NULL, '[]',
              'round3814 probe: no on-site reading supplied.', NULL, '   ');
    SELECT count(*) INTO v_read FROM public.dsr_for_job(v_job) t WHERE t.equipment_serial = 'HOSP-ENTERED';
    IF v_read <> 1 THEN RAISE EXCEPTION 'round 3814 VERIFY FAILED: fallback/reader (rows=%)', v_read; END IF;
    RAISE EXCEPTION 'R3814_PROBE_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'R3814_PROBE_ROLLBACK' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'round 3814 verified: single overloads, ACL identical, anon blocked, attest/back-fill/conflict/fallback all proven and rolled back';
END
$gate$;

COMMIT;
