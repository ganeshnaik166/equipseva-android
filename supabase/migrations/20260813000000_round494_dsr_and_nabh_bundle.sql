-- =====================================================================
-- Round 494 — Digital Service Report (DSR) + NABH Bundle backbone
-- v0.4 Phase 3 #3 + #4
-- =====================================================================
--
-- The DSR is the post-job structured report NABH 5th-edition Chapter
-- COP-6 (Medical Equipment Management) requires for every equipment
-- service event:
--   - Pre/post readings (measured electrical values vs OEM tolerance)
--   - IEC 62353 electrical safety test result (mandatory for life-
--     support + Class C/D; we capture for all classes for posterity)
--   - Parts replaced (manufacturer + part_no + batch + serial)
--   - Engineer + hospital signature
--   - Calibration values + tolerance flag
--
-- Without a DSR, the hospital's NABH auditor refuses the service
-- record as evidence + accreditation status drops. We CURRENTLY have
-- no structured DSR; engineers improvise free-text notes that
-- auditors reject.
--
-- The NABH bundle export is the per-equipment trailing 24-month
-- aggregate the auditor demands during accreditation visits:
--   - All DSRs for the equipment_serial
--   - All calibration certs
--   - All breakdown reports
--   - Engineer competency certs (linked via PVED)
--   - AERB returns (for radiation equipment — out of v0.4 scope)
--
-- This migration ships the BACKBONE. PDF/ZIP rendering edge fn lands
-- next round.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. dsr_reports table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dsr_reports (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id            uuid        NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  engineer_user_id         uuid        NOT NULL,
  hospital_user_id         uuid        NOT NULL,
  -- Equipment identification (denormalized from repair_job for
  -- forensic immutability — even if the job's equipment fields
  -- change, the DSR's snapshot holds).
  equipment_brand          text        NOT NULL,
  equipment_model          text,
  equipment_serial         text,
  equipment_type           text        NOT NULL,

  -- Pre/post readings (structured but flexible — different equipment
  -- types have different measurable parameters). jsonb shape:
  -- [{"label":"input_voltage","unit":"V","pre":230.4,"post":230.1,"oem_tolerance":"±2%","passes":true}, ...]
  pre_post_readings        jsonb       NOT NULL DEFAULT '[]'::jsonb,

  -- IEC 62353 electrical safety test result. NULL when the test
  -- doesn't apply (cosmetic-only repair).
  iec_62353_passed         boolean,
  iec_62353_readings       jsonb,      -- structured readings

  -- Calibration result
  calibration_performed    boolean     NOT NULL DEFAULT false,
  calibration_within_oem   boolean,    -- TRUE only if within OEM tolerance
  calibration_readings     jsonb,      -- structured calibration values
  calibration_lab_ref      text,       -- NPL / NABL lab reference if external cal used

  -- Parts replaced (jsonb array of objects)
  -- [{"manufacturer":"GE","part_no":"5174532-3","batch_no":"BX-2401","serial_no":"S-9001","unit_cost_rupees":3500}, ...]
  parts_replaced           jsonb       NOT NULL DEFAULT '[]'::jsonb,

  -- Free-text + signature
  work_summary             text        NOT NULL CHECK (length(work_summary) BETWEEN 20 AND 5000),
  recommendations          text,       -- engineer's follow-up advice
  engineer_signature_at    timestamptz NOT NULL DEFAULT now(),
  hospital_signature_at    timestamptz,  -- populated when hospital signs off
  hospital_signer_name     text,
  hospital_signer_role     text,         -- "Biomedical Coordinator" / "Maintenance Manager" / etc.

  -- Linked evidence rows (r492)
  engineer_signature_ledger uuid       REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,
  hospital_signature_ledger uuid       REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,
  rendered_pdf_ledger       uuid       REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,

  status                   text        NOT NULL DEFAULT 'pending_hospital_sign'
                                       CHECK (status IN (
                                         'pending_hospital_sign',
                                         'signed',
                                         'disputed',
                                         'invalidated'
                                       )),
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT dsr_one_per_job UNIQUE (repair_job_id)
);

CREATE INDEX IF NOT EXISTS dsr_engineer_idx
  ON public.dsr_reports (engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS dsr_hospital_idx
  ON public.dsr_reports (hospital_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS dsr_equipment_serial_idx
  ON public.dsr_reports (equipment_serial, created_at DESC)
  WHERE equipment_serial IS NOT NULL;
CREATE INDEX IF NOT EXISTS dsr_status_idx
  ON public.dsr_reports (status, created_at DESC);

ALTER TABLE public.dsr_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dsr_reports_select ON public.dsr_reports;
CREATE POLICY dsr_reports_select
  ON public.dsr_reports
  FOR SELECT
  TO authenticated, service_role
  USING (
    hospital_user_id = auth.uid()
    OR engineer_user_id = auth.uid()
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.dsr_reports
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. submit_dsr — engineer files post-job DSR
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_dsr(
  p_repair_job_id        uuid,
  p_pre_post_readings    jsonb,
  p_iec_62353_passed     boolean,
  p_iec_62353_readings   jsonb,
  p_calibration_performed boolean,
  p_calibration_within_oem boolean,
  p_calibration_readings jsonb,
  p_calibration_lab_ref  text,
  p_parts_replaced       jsonb,
  p_work_summary         text,
  p_recommendations      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller         uuid := auth.uid();
  v_job            record;
  v_engineer_user  uuid;
  v_dsr_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_work_summary IS NULL OR length(trim(p_work_summary)) < 20 THEN
    RAISE EXCEPTION 'work_summary required (min 20 chars)' USING ERRCODE = '22023';
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

  -- Idempotency: one DSR per job. Re-submit replaces (deletes the old
  -- via the UNIQUE constraint).
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
    v_job.equipment_brand, v_job.equipment_model, v_job.equipment_serial, v_job.equipment_type,
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

REVOKE EXECUTE ON FUNCTION public.submit_dsr(
  uuid, jsonb, boolean, jsonb, boolean, boolean, jsonb, text, jsonb, text, text
) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_dsr(
  uuid, jsonb, boolean, jsonb, boolean, boolean, jsonb, text, jsonb, text, text
) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. hospital_sign_dsr — hospital coordinator signs off
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hospital_sign_dsr(
  p_dsr_id              uuid,
  p_signer_name         text,
  p_signer_role         text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_signer_name IS NULL OR length(trim(p_signer_name)) < 3 THEN
    RAISE EXCEPTION 'signer_name required' USING ERRCODE = '22023';
  END IF;
  IF p_signer_role IS NULL OR length(trim(p_signer_role)) < 3 THEN
    RAISE EXCEPTION 'signer_role required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.dsr_reports WHERE id = p_dsr_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'dsr_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.hospital_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'hospital_only_can_sign' USING ERRCODE = '42501';
  END IF;
  IF v_row.status <> 'pending_hospital_sign' THEN
    RAISE EXCEPTION 'dsr_not_pending_sign (status=%)', v_row.status
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.dsr_reports
     SET status = 'signed',
         hospital_signature_at = now(),
         hospital_signer_name = p_signer_name,
         hospital_signer_role = p_signer_role,
         updated_at = now()
   WHERE id = p_dsr_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hospital_sign_dsr(uuid, text, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.hospital_sign_dsr(uuid, text, text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. NABH bundle export — per equipment_serial, trailing N months
-- ---------------------------------------------------------------------
-- Returns the structured payload for the NABH audit ZIP. The edge
-- fn that renders this into a downloadable archive calls this RPC
-- and then assembles the actual files.
CREATE OR REPLACE FUNCTION public.nabh_bundle_for_equipment(
  p_hospital_user_id uuid,
  p_equipment_serial text,
  p_months           integer DEFAULT 24
)
RETURNS TABLE(
  dsr_id              uuid,
  repair_job_id       uuid,
  equipment_brand     text,
  equipment_model     text,
  equipment_type      text,
  engineer_signature_at timestamptz,
  hospital_signature_at timestamptz,
  hospital_signer_name text,
  hospital_signer_role text,
  iec_62353_passed    boolean,
  calibration_within_oem boolean,
  pre_post_readings   jsonb,
  parts_replaced      jsonb,
  status              text
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
  -- Hospital can pull their own equipment bundle; founder any.
  IF auth.uid() <> p_hospital_user_id AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF p_equipment_serial IS NULL THEN
    RAISE EXCEPTION 'equipment_serial required' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT d.id, d.repair_job_id, d.equipment_brand, d.equipment_model, d.equipment_type,
         d.engineer_signature_at, d.hospital_signature_at,
         d.hospital_signer_name, d.hospital_signer_role,
         d.iec_62353_passed, d.calibration_within_oem,
         d.pre_post_readings, d.parts_replaced, d.status
    FROM public.dsr_reports d
   WHERE d.hospital_user_id = p_hospital_user_id
     AND d.equipment_serial = p_equipment_serial
     AND d.created_at >= now() - (greatest(coalesce(p_months, 24), 1)::text || ' months')::interval
   ORDER BY d.engineer_signature_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.nabh_bundle_for_equipment(uuid, text, integer)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.nabh_bundle_for_equipment(uuid, text, integer)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. dsr_for_job — quick read helper
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dsr_for_job(
  p_repair_job_id uuid
)
RETURNS TABLE(
  id                    uuid,
  status                text,
  engineer_signature_at timestamptz,
  hospital_signature_at timestamptz,
  iec_62353_passed      boolean,
  calibration_within_oem boolean,
  work_summary          text,
  recommendations       text,
  pre_post_readings     jsonb,
  parts_replaced        jsonb
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
         d.work_summary, d.recommendations, d.pre_post_readings, d.parts_replaced
    FROM public.dsr_reports d
   WHERE d.repair_job_id = p_repair_job_id
     AND (d.hospital_user_id = auth.uid() OR d.engineer_user_id = auth.uid() OR public.is_founder());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.dsr_for_job(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.dsr_for_job(uuid)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'dsr_reports'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 494: dsr_reports RLS not enabled';
  END IF;
  RAISE NOTICE 'round 494 DSR + NABH bundle verified: table + 4 RPCs, grants correct';
END;
$$;
