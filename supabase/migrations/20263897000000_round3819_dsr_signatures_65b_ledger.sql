-- =====================================================================
-- Round 3819 — the Digital Service Report joins the §65B ledger:
--              engineer attestation + hospital countersign become chained
--              evidence rows; dsr_reports.engineer_signature_ledger /
--              hospital_signature_ledger are finally populated
-- =====================================================================
--
-- Verified against production before writing this:
--   * public.dsr_reports has 2 rows (RPR-00041 signed 2026-09-06,
--     RPR-00040 signed 2026-09-07), BOTH with engineer_signature_ledger
--     AND hospital_signature_ledger NULL. round494 designed the three link
--     columns; nothing ever wrote them. The table has NO triggers.
--   * submit_dsr() (live shape = round3814) does DELETE + INSERT — every
--     submission, including a "Revise report" resubmit, is a fresh INSERT
--     with a fresh engineer_signature_at and status pending_hospital_sign.
--   * hospital_sign_dsr() UPDATEs status='signed' and sets
--     hospital_signature_at / hospital_signer_name / hospital_signer_role.
--   * round3818 made GPS check-ins the ledger's first writer; this round
--     is the second, using the SAME canonical-record + sha256(metadata::text)
--     scheme, so verify_evidence_hash() / generate_65b_certificate() /
--     evidence_for_repair_job() work unchanged.
--
-- WHAT THIS DOES
--   1. dsr_engineer_attestation_record(...) — canonical jsonb of everything
--      the engineer attests to (all report content + identities + the
--      attestation instant). dsr_hospital_countersign_record(...) —
--      canonical jsonb of the countersign (signer, instant) that CARRIES
--      THE SHA-256 OF THE ENGINEER RECORD IT SIGNS. That is the chain: a
--      hospital signature is bound to one exact version of the report;
--      a resubmit produces a new engineer sha and needs a new countersign.
--   2. A BEFORE INSERT OR UPDATE trigger on dsr_reports:
--        INSERT  -> register evidence kind 'signature_engineer'
--                   (source repair_job, producer = the engineer),
--                   set NEW.engineer_signature_ledger.
--        UPDATE  -> only when hospital_signature_at flips NULL -> NOT NULL:
--                   register kind 'signature_hospital' (producer = the
--                   hospital user), set NEW.hospital_signature_ledger.
--      BEFORE (not AFTER) so the link columns are set in place — no
--      self-UPDATE, no trigger recursion. Both branches sit in their own
--      exception guard: a ledger failure leaves the link NULL with a
--      NOTICE and NEVER aborts a submit or a countersign.
--   3. Backfill for the 2 existing signed reports: engineer record with
--      captured_at = engineer_signature_at, hospital record with
--      captured_at = hospital_signature_at, both platform_version
--      'round3819-backfill' so a retro-registered row is distinguishable
--      from one hashed at signing time.
--
-- Both kinds already exist in the evidence_kind CHECK — no constraint
-- change. rendered_pdf_ledger stays NULL: there is no PDF renderer, and
-- inventing a "pdf" record would be exactly the kind of compliant-on-paper
-- theatre this ledger exists to end.
--
-- All new functions have EXECUTE revoked from PUBLIC/anon/authenticated
-- (Supabase default-ACL trap: a fresh CREATE publishes to anon).
--
-- GATE (inside this transaction, rolled back): on a real job with an
-- accepted engineer and no report yet, a submit-shaped INSERT must yield
-- an engineer evidence row linked from the report; a countersign-shaped
-- UPDATE must yield a hospital evidence row linked from the report whose
-- record carries the engineer row's sha; both hashes must recompute from
-- metadata::text; and the backfill must have left no signed report
-- unlinked. Probe errors are FAILURES.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Canonical records
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dsr_engineer_attestation_record(d public.dsr_reports, p_job_number text)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'v',                       1,
    'kind',                    'dsr_engineer_attestation',
    'dsr_id',                  d.id,
    'repair_job_id',           d.repair_job_id,
    'job_number',              p_job_number,
    'engineer_user_id',        d.engineer_user_id,
    'hospital_user_id',        d.hospital_user_id,
    'equipment_brand',         d.equipment_brand,
    'equipment_model',         d.equipment_model,
    'equipment_serial',        d.equipment_serial,
    'equipment_type',          d.equipment_type,
    'pre_post_readings',       d.pre_post_readings,
    'iec_62353_passed',        d.iec_62353_passed,
    'iec_62353_readings',      d.iec_62353_readings,
    'calibration_performed',   d.calibration_performed,
    'calibration_within_oem',  d.calibration_within_oem,
    'calibration_readings',    d.calibration_readings,
    'calibration_lab_ref',     d.calibration_lab_ref,
    'parts_replaced',          d.parts_replaced,
    'work_summary',            d.work_summary,
    'recommendations',         d.recommendations,
    'engineer_signature_at',   to_char(d.engineer_signature_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
  );
$$;
COMMENT ON FUNCTION public.dsr_engineer_attestation_record(public.dsr_reports, text) IS
  'Round 3819 — canonical §65B record of what the engineer attested in a DSR. jsonb::text is hashed into evidence_ledger.content_sha256 (kind signature_engineer) and stored as metadata.';
REVOKE EXECUTE ON FUNCTION public.dsr_engineer_attestation_record(public.dsr_reports, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.dsr_hospital_countersign_record(d public.dsr_reports, p_job_number text, p_attests_sha256 text)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'v',                       1,
    'kind',                    'dsr_hospital_countersign',
    'dsr_id',                  d.id,
    'repair_job_id',           d.repair_job_id,
    'job_number',              p_job_number,
    'hospital_user_id',        d.hospital_user_id,
    'engineer_user_id',        d.engineer_user_id,
    'hospital_signer_name',    d.hospital_signer_name,
    'hospital_signer_role',    d.hospital_signer_role,
    'hospital_signature_at',   to_char(d.hospital_signature_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    -- The chain link: the sha256 of the engineer attestation this signature covers.
    'attests_sha256',          p_attests_sha256
  );
$$;
COMMENT ON FUNCTION public.dsr_hospital_countersign_record(public.dsr_reports, text, text) IS
  'Round 3819 — canonical §65B record of a hospital countersign on a DSR; carries attests_sha256 = the engineer attestation row it signs, binding the signature to one exact report version.';
REVOKE EXECUTE ON FUNCTION public.dsr_hospital_countersign_record(public.dsr_reports, text, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Ledger writer shared by trigger + backfill
-- ---------------------------------------------------------------------
-- Inserts one evidence row for a canonical record and returns its id.
-- Idempotent on the ledger's natural key (kind, source, id, sha).
CREATE OR REPLACE FUNCTION public.register_canonical_evidence(
  p_evidence_kind    text,
  p_source_id        uuid,
  p_record           jsonb,
  p_producer_user_id uuid,
  p_producer_kind    text,
  p_captured_at      timestamptz,
  p_platform_version text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_text text := p_record::text;
  v_sha  text := encode(extensions.digest(convert_to(p_record::text, 'UTF8'), 'sha256'), 'hex');
  v_id   uuid;
BEGIN
  INSERT INTO public.evidence_ledger (
    evidence_kind, source_kind, source_id, content_sha256,
    content_size_bytes, storage_url, producer_user_id, producer_kind,
    captured_at, platform_version, metadata
  ) VALUES (
    p_evidence_kind, 'repair_job', p_source_id, v_sha,
    octet_length(v_text), NULL, p_producer_user_id, p_producer_kind,
    p_captured_at, p_platform_version, p_record
  )
  ON CONFLICT ON CONSTRAINT evidence_ledger_uniq DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.evidence_ledger
     WHERE evidence_kind = p_evidence_kind AND source_kind = 'repair_job'
       AND source_id = p_source_id AND content_sha256 = v_sha;
  END IF;
  RETURN v_id;
END;
$$;
COMMENT ON FUNCTION public.register_canonical_evidence(text, uuid, jsonb, uuid, text, timestamptz, text) IS
  'Round 3819 — internal writer: registers a canonical jsonb record (sha256 of its text, size, metadata = record) in evidence_ledger for a repair_job source. Idempotent. Not a client RPC.';
REVOKE EXECUTE ON FUNCTION public.register_canonical_evidence(text, uuid, jsonb, uuid, text, timestamptz, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Trigger
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dsr_register_signature_evidence()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job_number text;
  v_eng_sha    text;
BEGIN
  SELECT job_number INTO v_job_number FROM public.repair_jobs WHERE id = NEW.repair_job_id;

  IF TG_OP = 'INSERT' THEN
    BEGIN
      NEW.engineer_signature_ledger := public.register_canonical_evidence(
        'signature_engineer', NEW.repair_job_id,
        public.dsr_engineer_attestation_record(NEW, v_job_number),
        NEW.engineer_user_id, 'engineer',
        NEW.engineer_signature_at, 'round3819-trigger'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'dsr_register_signature_evidence: engineer attestation not registered for dsr % (% / %)',
        NEW.id, SQLSTATE, SQLERRM;
    END;
    RETURN NEW;
  END IF;

  -- UPDATE: act only on the countersign transition.
  IF OLD.hospital_signature_at IS NULL AND NEW.hospital_signature_at IS NOT NULL THEN
    BEGIN
      SELECT content_sha256 INTO v_eng_sha
        FROM public.evidence_ledger WHERE id = NEW.engineer_signature_ledger;
      NEW.hospital_signature_ledger := public.register_canonical_evidence(
        'signature_hospital', NEW.repair_job_id,
        public.dsr_hospital_countersign_record(NEW, v_job_number, v_eng_sha),
        NEW.hospital_user_id, 'hospital',
        NEW.hospital_signature_at, 'round3819-trigger'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'dsr_register_signature_evidence: hospital countersign not registered for dsr % (% / %)',
        NEW.id, SQLSTATE, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.dsr_register_signature_evidence() IS
  'Round 3819 — BEFORE INSERT/UPDATE on dsr_reports: registers the engineer attestation (INSERT) and the hospital countersign (hospital_signature_at NULL→set) in evidence_ledger and sets the report''s ledger link columns in place. Each step is exception-guarded: it can never abort a submit or a sign.';
REVOKE EXECUTE ON FUNCTION public.dsr_register_signature_evidence() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS dsr_register_signature_evidence_trg ON public.dsr_reports;
CREATE TRIGGER dsr_register_signature_evidence_trg
  BEFORE INSERT OR UPDATE ON public.dsr_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.dsr_register_signature_evidence();

-- ---------------------------------------------------------------------
-- 4. Backfill existing reports (trigger disabled for the loop: these rows
--    must be flagged as backfill, and the UPDATE below must not re-fire)
-- ---------------------------------------------------------------------
ALTER TABLE public.dsr_reports DISABLE TRIGGER dsr_register_signature_evidence_trg;
DO $$
DECLARE
  r          public.dsr_reports%ROWTYPE;
  v_job_no   text;
  v_eng_id   uuid;
  v_eng_sha  text;
  v_hosp_id  uuid;
  v_n_eng    int := 0;
  v_n_hosp   int := 0;
BEGIN
  FOR r IN SELECT * FROM public.dsr_reports ORDER BY created_at LOOP
    SELECT job_number INTO v_job_no FROM public.repair_jobs WHERE id = r.repair_job_id;

    IF r.engineer_signature_ledger IS NULL THEN
      v_eng_id := public.register_canonical_evidence(
        'signature_engineer', r.repair_job_id,
        public.dsr_engineer_attestation_record(r, v_job_no),
        r.engineer_user_id, 'engineer', r.engineer_signature_at, 'round3819-backfill');
      UPDATE public.dsr_reports SET engineer_signature_ledger = v_eng_id WHERE id = r.id;
      r.engineer_signature_ledger := v_eng_id;
      v_n_eng := v_n_eng + 1;
    END IF;

    IF r.hospital_signature_at IS NOT NULL AND r.hospital_signature_ledger IS NULL THEN
      SELECT content_sha256 INTO v_eng_sha FROM public.evidence_ledger WHERE id = r.engineer_signature_ledger;
      v_hosp_id := public.register_canonical_evidence(
        'signature_hospital', r.repair_job_id,
        public.dsr_hospital_countersign_record(r, v_job_no, v_eng_sha),
        r.hospital_user_id, 'hospital', r.hospital_signature_at, 'round3819-backfill');
      UPDATE public.dsr_reports SET hospital_signature_ledger = v_hosp_id WHERE id = r.id;
      v_n_hosp := v_n_hosp + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'round 3819: back-filled % engineer attestation(s) and % hospital countersign(s)', v_n_eng, v_n_hosp;
END;
$$;
ALTER TABLE public.dsr_reports ENABLE TRIGGER dsr_register_signature_evidence_trg;

-- ---------------------------------------------------------------------
-- 5. Gate
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_unlinked_eng  int;
  v_unlinked_hosp int;
  v_job           record;
  v_eng_user      uuid;
  v_led_before    int;
  v_dsr_id        uuid;
  v_dsr           public.dsr_reports%ROWTYPE;
  v_eng           public.evidence_ledger%ROWTYPE;
  v_hosp          public.evidence_ledger%ROWTYPE;
  v_probed        boolean := false;
BEGIN
  SELECT count(*) INTO v_unlinked_eng FROM public.dsr_reports WHERE engineer_signature_ledger IS NULL;
  SELECT count(*) INTO v_unlinked_hosp FROM public.dsr_reports WHERE hospital_signature_at IS NOT NULL AND hospital_signature_ledger IS NULL;
  IF v_unlinked_eng <> 0 OR v_unlinked_hosp <> 0 THEN
    RAISE EXCEPTION 'round 3819 VERIFY FAILED: backfill left % engineer and % hospital links NULL', v_unlinked_eng, v_unlinked_hosp;
  END IF;

  SELECT rj.*, b.engineer_user_id AS accepted_engineer INTO v_job
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE rj.hospital_user_id IS NOT NULL
     AND rj.equipment_type IS NOT NULL          -- dsr_reports.equipment_type is NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.dsr_reports d WHERE d.repair_job_id = rj.id)
   LIMIT 1;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'round 3819 VERIFY FAILED: no job with an accepted engineer and no report to probe with';
  END IF;
  v_eng_user := v_job.accepted_engineer;

  SELECT count(*) INTO v_led_before FROM public.evidence_ledger;

  BEGIN
    -- submit-shaped INSERT (mirrors submit_dsr's column list)
    INSERT INTO public.dsr_reports (
      repair_job_id, engineer_user_id, hospital_user_id,
      equipment_brand, equipment_model, equipment_serial, equipment_type,
      pre_post_readings, iec_62353_passed, iec_62353_readings,
      calibration_performed, calibration_within_oem, calibration_readings, calibration_lab_ref,
      parts_replaced, work_summary, recommendations,
      engineer_signature_at, status
    ) VALUES (
      v_job.id, v_eng_user, v_job.hospital_user_id,
      coalesce(v_job.equipment_brand, 'probe-brand'), v_job.equipment_model, v_job.equipment_serial, v_job.equipment_type::text,
      '[]'::jsonb, true, '[]'::jsonb,
      false, NULL, '[]'::jsonb, NULL,
      '[]'::jsonb, 'round 3819 gate probe — this report is rolled back and never persists', NULL,
      now(), 'pending_hospital_sign'
    ) RETURNING id INTO v_dsr_id;

    SELECT * INTO v_dsr FROM public.dsr_reports WHERE id = v_dsr_id;
    IF v_dsr.engineer_signature_ledger IS NULL THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: submit did not link an engineer attestation (see NOTICE above)';
    END IF;
    SELECT * INTO v_eng FROM public.evidence_ledger WHERE id = v_dsr.engineer_signature_ledger;
    IF v_eng.evidence_kind <> 'signature_engineer' OR v_eng.source_id <> v_job.id OR v_eng.producer_user_id <> v_eng_user OR v_eng.producer_kind <> 'engineer' THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: engineer evidence mis-keyed (% % % %)', v_eng.evidence_kind, v_eng.source_id, v_eng.producer_user_id, v_eng.producer_kind;
    END IF;
    IF encode(extensions.digest(convert_to(v_eng.metadata::text, 'UTF8'), 'sha256'), 'hex') <> v_eng.content_sha256
       OR v_eng.content_size_bytes <> octet_length(v_eng.metadata::text) THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: engineer evidence hash/size do not recompute';
    END IF;
    IF v_eng.metadata->>'work_summary' <> v_dsr.work_summary OR (v_eng.metadata->>'dsr_id')::uuid <> v_dsr_id THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: engineer record does not describe the probed report';
    END IF;

    -- countersign-shaped UPDATE (mirrors hospital_sign_dsr)
    UPDATE public.dsr_reports
       SET status = 'signed', hospital_signature_at = now(),
           hospital_signer_name = 'Gate Probe', hospital_signer_role = 'Biomedical Coordinator',
           updated_at = now()
     WHERE id = v_dsr_id;

    SELECT * INTO v_dsr FROM public.dsr_reports WHERE id = v_dsr_id;
    IF v_dsr.hospital_signature_ledger IS NULL THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: countersign did not link a hospital signature (see NOTICE above)';
    END IF;
    IF v_dsr.engineer_signature_ledger <> v_eng.id THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: countersign UPDATE disturbed the engineer link';
    END IF;
    SELECT * INTO v_hosp FROM public.evidence_ledger WHERE id = v_dsr.hospital_signature_ledger;
    IF v_hosp.evidence_kind <> 'signature_hospital' OR v_hosp.source_id <> v_job.id OR v_hosp.producer_user_id <> v_job.hospital_user_id OR v_hosp.producer_kind <> 'hospital' THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: hospital evidence mis-keyed (% % % %)', v_hosp.evidence_kind, v_hosp.source_id, v_hosp.producer_user_id, v_hosp.producer_kind;
    END IF;
    IF encode(extensions.digest(convert_to(v_hosp.metadata::text, 'UTF8'), 'sha256'), 'hex') <> v_hosp.content_sha256 THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: hospital evidence hash does not recompute';
    END IF;
    IF v_hosp.metadata->>'attests_sha256' IS DISTINCT FROM v_eng.content_sha256 THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: chain broken — countersign attests % but engineer sha is %', v_hosp.metadata->>'attests_sha256', v_eng.content_sha256;
    END IF;
    IF v_hosp.metadata->>'hospital_signer_name' <> 'Gate Probe' THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: countersign record does not carry the signer';
    END IF;
    IF (SELECT count(*) FROM public.evidence_ledger) <> v_led_before + 2 THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: expected exactly +2 ledger rows';
    END IF;

    RAISE NOTICE 'round 3819: probe report % -> engineer evidence % (% bytes), countersign evidence % chained to it; both hashes recompute',
      v_dsr_id, v_eng.id, v_eng.content_size_bytes, v_hosp.id;
    RAISE EXCEPTION 'ROUND3819_PROBE_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      IF SQLERRM <> 'ROUND3819_PROBE_ROLLBACK' THEN RAISE; END IF;
      v_probed := true;
    WHEN OTHERS THEN
      RAISE EXCEPTION 'round 3819 VERIFY FAILED: probe errored: % %', SQLSTATE, SQLERRM;
  END;

  IF NOT v_probed THEN
    RAISE EXCEPTION 'round 3819 VERIFY FAILED: probe did not reach its rollback sentinel';
  END IF;
  RAISE NOTICE 'round 3819 verified + probe rolled back: DSR engineer attestations and hospital countersigns are §65B evidence, chained by sha256';
END;
$$;

COMMIT;
