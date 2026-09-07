-- =====================================================================
-- Round 3818 — GPS check-ins become §65B evidence (the ledger's first
--              ever writer) and engineer_attendance.evidence_ledger_id
--              is finally populated
-- =====================================================================
--
-- Verified against production before writing this:
--   * public.evidence_ledger has 0 rows. round492 built the §65B chain
--     (register_evidence / verify_evidence_hash / generate_65b_certificate
--     / evidence_for_repair_job) and NOTHING has ever called
--     register_evidence — no Kotlin, no web, no edge function, no other
--     migration. The founder's 65B summary, the hospital's evidence list
--     and the certificate generator have always run over an empty table.
--   * public.engineer_attendance has 1 row (RPR-00040, 2026-09-07 03:43
--     UTC, distance 0 m) and its evidence_ledger_id is NULL — round496
--     designed the link column, round3787 lit up the attendance write
--     via a trigger on repair_jobs, but nobody ever forged the link.
--
-- WHAT THIS DOES
--   1. Adds 'gps_checkin' to evidence_ledger's evidence_kind CHECK. The
--      constraint name below is the live one (pg_constraint verified).
--   2. Extends round3787's trigger function so that, right after it
--      inserts the attendance row, it also:
--        a. builds a canonical JSON record of the check-in (job, engineer,
--           hospital, both coordinate pairs, distance, flag, capture time),
--        b. SHA-256-hashes that record's canonical text (pgcrypto lives in
--           the `extensions` schema on Supabase — hence the prefix),
--        c. inserts it into evidence_ledger as kind 'gps_checkin',
--           source 'repair_job', producer = the engineer (their user id,
--           resolved server-side from engineers.user_id — NOT auth.uid(),
--           so an admin/backfill path attributes correctly too),
--        d. stamps engineer_attendance.evidence_ledger_id with the new id.
--      The record is stored as `metadata`, so verify_evidence_hash() and
--      generate_65b_certificate() work on it exactly as on a file:
--      recompute sha256(metadata::text) and compare. jsonb text output is
--      canonical (sorted keys, normalised spacing), so the hash is
--      reproducible from the stored row.
--   3. Back-fills the ledger link for attendance rows that already exist
--      (today: one), flagged platform_version = 'round3818-backfill' and
--      captured_at = the row's own device_captured_at, so nobody can
--      mistake a retro-registered record for one hashed at capture time.
--
-- WHY A DIRECT INSERT RATHER THAN register_evidence()
--   register_evidence() gates on auth.uid() / service_role and stamps
--   producer_user_id = auth.uid(). Inside a trigger those are the wrong
--   identity for a backfill and a needless failure mode for the live
--   path. The trigger function is SECURITY DEFINER owned by postgres,
--   which retains INSERT on the ledger despite round492's REVOKEs from
--   anon/authenticated/service_role — the ledger stays client-immutable.
--
-- SAFETY — same discipline as round3787
--   * The ledger step runs in its OWN nested BEGIN/EXCEPTION block. If it
--     fails for any reason the attendance row is still committed and the
--     check-in still succeeds; only the link is missing (and a NOTICE
--     says why). The outer block still guarantees the check-in itself
--     can never be aborted by attendance logging.
--   * CREATE OR REPLACE on a trigger function: no ACL replay needed
--     (nothing executes it but the trigger), and no DROP.
--   * The new evidence_kind is additive; every existing kind stays valid.
--
-- GATE (inside this transaction, rolled back): a real check-in-shaped
-- UPDATE on a real assigned job must produce +1 attendance row AND +1
-- ledger row, the attendance row must point at the ledger row, and the
-- ledger row's stored hash must equal sha256(metadata::text) with the
-- matching size, kind, source and producer. Probe errors are FAILURES.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. New evidence kind
-- ---------------------------------------------------------------------
ALTER TABLE public.evidence_ledger
  DROP CONSTRAINT IF EXISTS evidence_ledger_evidence_kind_check;
ALTER TABLE public.evidence_ledger
  ADD CONSTRAINT evidence_ledger_evidence_kind_check
  CHECK (evidence_kind IN (
    'pved_pdf',
    'dsr_pdf',
    'chat_archive',
    'photo_before',
    'photo_after',
    'photo_during',
    'signature_engineer',
    'signature_hospital',
    'amc_affidavit',
    'tds_certificate',
    'gst_invoice_pdf',
    'voice_note',
    'job_completion_otp',
    'parts_receipt',
    'gps_checkin'
  ));

-- ---------------------------------------------------------------------
-- 2. Canonical record + hash helper (shared by trigger and backfill)
-- ---------------------------------------------------------------------
-- Pure function of its inputs so the trigger and the backfill produce
-- byte-identical records for identical facts. Version key 'v' lets a
-- future change to the record shape coexist with old rows.
CREATE OR REPLACE FUNCTION public.gps_checkin_evidence_record(
  p_repair_job_id     uuid,
  p_job_number        text,
  p_engineer_id       uuid,
  p_engineer_user_id  uuid,
  p_hospital_user_id  uuid,
  p_engineer_lat      double precision,
  p_engineer_lng      double precision,
  p_site_lat          double precision,
  p_site_lng          double precision,
  p_distance_m        double precision,
  p_suspicious        boolean,
  p_captured_at       timestamptz
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'v',                1,
    'event_kind',       'arrival_checkin',
    'repair_job_id',    p_repair_job_id,
    'job_number',       p_job_number,
    'engineer_id',      p_engineer_id,
    'engineer_user_id', p_engineer_user_id,
    'hospital_user_id', p_hospital_user_id,
    'engineer_lat',     p_engineer_lat,
    'engineer_lng',     p_engineer_lng,
    'site_lat',         p_site_lat,
    'site_lng',         p_site_lng,
    'distance_m',       p_distance_m,
    'suspicious',       p_suspicious,
    'captured_at',      to_char(p_captured_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
  );
$$;

COMMENT ON FUNCTION public.gps_checkin_evidence_record(uuid, text, uuid, uuid, uuid, double precision, double precision, double precision, double precision, double precision, boolean, timestamptz) IS
  'Round 3818 — canonical §65B evidence record for a GPS arrival check-in. Its jsonb::text is what gets SHA-256 hashed into evidence_ledger.content_sha256 (kind gps_checkin); the same jsonb is stored as evidence_ledger.metadata so the hash is reproducible from the row.';

-- Internal-only helper: not a client RPC.
REVOKE EXECUTE ON FUNCTION public.gps_checkin_evidence_record(uuid, text, uuid, uuid, uuid, double precision, double precision, double precision, double precision, double precision, boolean, timestamptz)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Trigger function — round3787 body + the ledger link
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_engineer_arrival_attendance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user uuid;
  v_distance_m    double precision;
  v_now           timestamptz := now();
  v_suspicious    boolean;
  v_att_id        uuid;
  v_record        jsonb;
  v_text          text;
  v_sha           text;
  v_ledger_id     uuid;
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

    -- Expected coords are derived SERVER-SIDE (see round3787 header). NULL
    -- when the hospital never geocoded the site; distance stays NULL then,
    -- which the column permits.
    IF NEW.site_latitude IS NOT NULL AND NEW.site_longitude IS NOT NULL THEN
      v_distance_m := public.haversine_meters(
        NEW.engineer_latitude, NEW.engineer_longitude,
        NEW.site_latitude,     NEW.site_longitude
      );
    END IF;
    -- round496's own threshold: >500m off the listed coords during a
    -- check-in is the review flag. coalesce so a NULL distance (no site
    -- coords) is recorded as not-suspicious rather than failing NOT NULL.
    v_suspicious := coalesce(v_distance_m > 500, false);

    INSERT INTO public.engineer_attendance (
      repair_job_id, engineer_user_id, hospital_user_id,
      event_kind, device_captured_at,
      engineer_lat, engineer_lng,
      hospital_expected_lat, hospital_expected_lng,
      distance_from_hospital_m, suspicious_distance
    ) VALUES (
      NEW.id, v_engineer_user, NEW.hospital_user_id,
      'arrival_checkin', v_now,
      NEW.engineer_latitude, NEW.engineer_longitude,
      NEW.site_latitude,     NEW.site_longitude,
      v_distance_m,
      v_suspicious
    )
    RETURNING id INTO v_att_id;

    -- round3818 — §65B ledger link, in its own guard so a ledger problem
    -- can only ever cost the link, never the attendance row.
    BEGIN
      v_record := public.gps_checkin_evidence_record(
        NEW.id, NEW.job_number, NEW.engineer_id, v_engineer_user, NEW.hospital_user_id,
        NEW.engineer_latitude, NEW.engineer_longitude,
        NEW.site_latitude, NEW.site_longitude,
        v_distance_m, v_suspicious, v_now
      );
      v_text := v_record::text;
      v_sha  := encode(extensions.digest(convert_to(v_text, 'UTF8'), 'sha256'), 'hex');

      INSERT INTO public.evidence_ledger (
        evidence_kind, source_kind, source_id, content_sha256,
        content_size_bytes, storage_url, producer_user_id, producer_kind,
        captured_at, platform_version, metadata
      ) VALUES (
        'gps_checkin', 'repair_job', NEW.id, v_sha,
        octet_length(v_text), NULL, v_engineer_user, 'engineer',
        v_now, 'round3818-trigger', v_record
      )
      RETURNING id INTO v_ledger_id;

      UPDATE public.engineer_attendance
         SET evidence_ledger_id = v_ledger_id
       WHERE id = v_att_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'log_engineer_arrival_attendance: ledger link skipped for job % (% / %)',
        NEW.id, SQLSTATE, SQLERRM;
    END;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'log_engineer_arrival_attendance: skipped for job % (% / %)',
      NEW.id, SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.log_engineer_arrival_attendance() IS
  'Round 3787 + 3818 — writes the round496 engineer_attendance arrival row when a job transitions to in_progress with engineer coordinates present (a real geo check-in), then registers the check-in as §65B evidence (evidence_ledger kind gps_checkin, sha256 of the canonical record in metadata) and links engineer_attendance.evidence_ledger_id. Expected coordinates are derived server-side. Fully exception-guarded at both levels: attendance logging can never abort a check-in, and a ledger failure can never lose the attendance row.';

-- ---------------------------------------------------------------------
-- 4. Backfill: link attendance rows that predate this round
-- ---------------------------------------------------------------------
DO $$
DECLARE
  r            record;
  v_record     jsonb;
  v_text       text;
  v_sha        text;
  v_ledger_id  uuid;
  v_n          int := 0;
BEGIN
  FOR r IN
    SELECT a.id, a.repair_job_id, a.engineer_user_id, a.hospital_user_id,
           a.engineer_lat, a.engineer_lng, a.hospital_expected_lat, a.hospital_expected_lng,
           a.distance_from_hospital_m, a.suspicious_distance, a.device_captured_at,
           rj.job_number, rj.engineer_id
      FROM public.engineer_attendance a
      JOIN public.repair_jobs rj ON rj.id = a.repair_job_id
     WHERE a.evidence_ledger_id IS NULL
       AND a.event_kind = 'arrival_checkin'
  LOOP
    v_ledger_id := NULL;  -- RETURNING yields no row on conflict; never reuse the previous id
    v_record := public.gps_checkin_evidence_record(
      r.repair_job_id, r.job_number, r.engineer_id, r.engineer_user_id, r.hospital_user_id,
      r.engineer_lat, r.engineer_lng, r.hospital_expected_lat, r.hospital_expected_lng,
      r.distance_from_hospital_m, r.suspicious_distance, r.device_captured_at
    );
    v_text := v_record::text;
    v_sha  := encode(extensions.digest(convert_to(v_text, 'UTF8'), 'sha256'), 'hex');

    INSERT INTO public.evidence_ledger (
      evidence_kind, source_kind, source_id, content_sha256,
      content_size_bytes, storage_url, producer_user_id, producer_kind,
      captured_at, platform_version, metadata
    ) VALUES (
      'gps_checkin', 'repair_job', r.repair_job_id, v_sha,
      octet_length(v_text), NULL, r.engineer_user_id, 'engineer',
      r.device_captured_at, 'round3818-backfill', v_record
    )
    ON CONFLICT ON CONSTRAINT evidence_ledger_uniq DO NOTHING
    RETURNING id INTO v_ledger_id;

    IF v_ledger_id IS NULL THEN
      SELECT id INTO v_ledger_id FROM public.evidence_ledger
       WHERE evidence_kind = 'gps_checkin' AND source_kind = 'repair_job'
         AND source_id = r.repair_job_id AND content_sha256 = v_sha;
    END IF;

    UPDATE public.engineer_attendance SET evidence_ledger_id = v_ledger_id WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'round 3818: back-filled ledger links for % pre-existing attendance row(s)', v_n;
END;
$$;

-- ---------------------------------------------------------------------
-- 5. Gate — a real check-in-shaped UPDATE must forge the whole chain
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_job_id        uuid;
  v_att_before    int;
  v_led_before    int;
  v_att_after     int;
  v_led_after     int;
  v_att           record;
  v_led           record;
  v_recomputed    text;
  v_probed        boolean := false;
  v_unlinked      int;
BEGIN
  -- Backfill must have left no unlinked arrival rows behind.
  SELECT count(*) INTO v_unlinked
    FROM public.engineer_attendance
   WHERE evidence_ledger_id IS NULL AND event_kind = 'arrival_checkin';
  IF v_unlinked <> 0 THEN
    RAISE EXCEPTION 'round 3818 VERIFY FAILED: % arrival rows still unlinked after backfill', v_unlinked;
  END IF;

  SELECT count(*) INTO v_att_before FROM public.engineer_attendance;
  SELECT count(*) INTO v_led_before FROM public.evidence_ledger;

  SELECT rj.id INTO v_job_id
    FROM public.repair_jobs rj
   WHERE rj.status IS DISTINCT FROM 'in_progress'
     AND rj.hospital_user_id IS NOT NULL
     AND rj.engineer_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.engineers e WHERE e.id = rj.engineer_id)
   ORDER BY (rj.site_latitude IS NOT NULL) DESC
   LIMIT 1;

  IF v_job_id IS NULL THEN
    -- Refuse to ship unexercised: the round exists to make this path live.
    RAISE EXCEPTION 'round 3818 VERIFY FAILED: no suitable job to probe (need hospital + resolvable engineer)';
  END IF;

  BEGIN
    UPDATE public.repair_jobs
       SET status = 'in_progress',
           engineer_latitude  = 17.3850,
           engineer_longitude = 78.4867
     WHERE id = v_job_id;

    SELECT count(*) INTO v_att_after FROM public.engineer_attendance;
    SELECT count(*) INTO v_led_after FROM public.evidence_ledger;
    IF v_att_after <> v_att_before + 1 THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: expected +1 attendance row, went % -> %', v_att_before, v_att_after;
    END IF;
    IF v_led_after <> v_led_before + 1 THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: expected +1 evidence_ledger row, went % -> %', v_led_before, v_led_after;
    END IF;

    SELECT * INTO v_att FROM public.engineer_attendance
     WHERE repair_job_id = v_job_id ORDER BY created_at DESC LIMIT 1;
    IF v_att.evidence_ledger_id IS NULL THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: attendance row written but evidence_ledger_id is NULL (check the NOTICE above for the swallowed error)';
    END IF;

    SELECT * INTO v_led FROM public.evidence_ledger WHERE id = v_att.evidence_ledger_id;
    IF v_led.id IS NULL THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: attendance points at a ledger row that does not exist';
    END IF;
    IF v_led.evidence_kind <> 'gps_checkin' OR v_led.source_kind <> 'repair_job' OR v_led.source_id <> v_job_id THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: ledger row mis-keyed (% / % / %)', v_led.evidence_kind, v_led.source_kind, v_led.source_id;
    END IF;
    IF v_led.producer_kind <> 'engineer' OR v_led.producer_user_id IS DISTINCT FROM v_att.engineer_user_id THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: producer should be the engineer (% / %)', v_led.producer_kind, v_led.producer_user_id;
    END IF;
    v_recomputed := encode(extensions.digest(convert_to(v_led.metadata::text, 'UTF8'), 'sha256'), 'hex');
    IF v_recomputed <> v_led.content_sha256 THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: sha256(metadata::text) % <> stored %', v_recomputed, v_led.content_sha256;
    END IF;
    IF v_led.content_size_bytes <> octet_length(v_led.metadata::text) THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: content_size_bytes % <> octet_length %', v_led.content_size_bytes, octet_length(v_led.metadata::text);
    END IF;
    IF (v_led.metadata->>'repair_job_id')::uuid <> v_job_id OR v_led.metadata->>'event_kind' <> 'arrival_checkin' THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: canonical record does not describe the probed check-in: %', v_led.metadata;
    END IF;

    RAISE NOTICE 'round 3818: check-in-shaped UPDATE produced attendance % linked to ledger % (kind %, % bytes, sha ok)',
      v_att.id, v_led.id, v_led.evidence_kind, v_led.content_size_bytes;
    RAISE EXCEPTION 'ROUND3818_PROBE_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      IF SQLERRM <> 'ROUND3818_PROBE_ROLLBACK' THEN
        RAISE;  -- a VERIFY FAILED raise is also P0001: propagate it
      END IF;
      v_probed := true;
    WHEN OTHERS THEN
      RAISE EXCEPTION 'round 3818 VERIFY FAILED: probe errored: % %', SQLSTATE, SQLERRM;
  END;

  IF NOT v_probed THEN
    RAISE EXCEPTION 'round 3818 VERIFY FAILED: probe did not reach its rollback sentinel';
  END IF;
  RAISE NOTICE 'round 3818 verified + probe rolled back: GPS check-ins are now §65B evidence and engineer_attendance.evidence_ledger_id is populated';
END;
$$;

COMMIT;
