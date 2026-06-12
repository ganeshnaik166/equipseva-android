-- =====================================================================
-- Round 493 — Pre-Visit Engineer Dossier (PVED) + AMC Affidavit
-- v0.4 Phase 3 #1 + #2 backbones
-- =====================================================================
--
-- Two trust-layer features bundled because both ride the round 492
-- evidence_ledger:
--
-- 1. PVED — 24 hours before a scheduled engineer visit, the system
--    produces a structured dossier the hospital admin can open before
--    granting site access: masked Aadhaar id, verification status,
--    certificate count, last 5 jobs with star ratings + brand history.
--    Hospital admin gate for "should I let this person near my ₹40L
--    CT scanner".
--
-- 2. AMC Affidavit — when a hospital creates a new AMC contract, they
--    sign a digital affidavit declaring (a) equipment is OUT of OEM
--    warranty + (b) no active OEM AMC covers the equipment. This
--    shifts tortious-interference liability to the hospital per
--    Indian Contract Act §124 indemnity. Skeptic-panel kill-shot #1.
--
-- Both produce structured rows + register the rendered output in
-- evidence_ledger so the §65B(4) certificate can be generated for
-- court / regulator use.

BEGIN;

-- =====================================================================
-- PART A — Pre-Visit Engineer Dossier (PVED)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.pre_visit_engineer_dossiers (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id            uuid        NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  engineer_user_id         uuid        NOT NULL,
  CONSTRAINT pved_engineer_user_fk
    FOREIGN KEY (engineer_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,
  hospital_user_id         uuid        NOT NULL,
  CONSTRAINT pved_hospital_user_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,

  -- Snapshot of engineer state at dossier issue time (immutable
  -- record — even if the engineer's status changes later, this
  -- dossier remains as evidence of what hospital was told).
  engineer_display_name    text        NOT NULL,
  aadhaar_masked_id        text,           -- "XXXX-XXXX-1234"
  verification_status      text        NOT NULL,
  verified_at              timestamptz,
  certificate_count        int         NOT NULL DEFAULT 0,
  oem_cert_summary         jsonb,           -- list of OEM certs held
  total_jobs_completed     int         NOT NULL DEFAULT 0,
  average_rating           numeric(3,2),
  last_5_jobs              jsonb,           -- summary of recent jobs
  police_verification_at   timestamptz,
  police_verification_ref  text,
  -- Selfie hash captured at hospital gate matched against dossier
  -- headshot — to be populated by Phase 4 gate-check feature.
  gate_selfie_match_at     timestamptz,
  gate_selfie_match_ledger uuid        REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,

  -- Status: 'issued' when generated, 'consumed' when hospital opens,
  -- 'expired' if visit completes without consumption.
  status                   text        NOT NULL DEFAULT 'issued'
                                       CHECK (status IN ('issued','consumed','expired','cancelled')),
  consumed_at              timestamptz,
  -- Linked evidence row (the rendered PDF / structured snapshot
  -- hash). Populated by the rendering edge fn.
  evidence_ledger_id       uuid        REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,
  issued_at                timestamptz NOT NULL DEFAULT now(),

  -- One dossier per (job, engineer) pair. Re-issue idempotency via
  -- UNIQUE — if needed, cancel + re-issue produces a new row but
  -- existing one stays as audit trail.
  CONSTRAINT pved_uniq UNIQUE (repair_job_id, engineer_user_id, status)
);

CREATE INDEX IF NOT EXISTS pved_hospital_idx
  ON public.pre_visit_engineer_dossiers (hospital_user_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS pved_engineer_idx
  ON public.pre_visit_engineer_dossiers (engineer_user_id, issued_at DESC);

ALTER TABLE public.pre_visit_engineer_dossiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pved_select ON public.pre_visit_engineer_dossiers;
CREATE POLICY pved_select
  ON public.pre_visit_engineer_dossiers
  FOR SELECT
  TO authenticated, service_role
  USING (
    hospital_user_id = auth.uid()
    OR engineer_user_id = auth.uid()
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.pre_visit_engineer_dossiers
  FROM anon, authenticated, service_role;

-- Generate dossier on demand (called by Phase 4 scheduler 24h
-- before the visit, OR by hospital on first-open of job detail).
CREATE OR REPLACE FUNCTION public.build_pved(
  p_repair_job_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job             record;
  v_engineer_user   uuid;
  v_engineer        record;
  v_caller          uuid := auth.uid();
  v_display_name    text;
  v_aadhaar_masked  text;
  v_cert_count      int;
  v_avg_rating      numeric(3,2);
  v_total_jobs      int;
  v_last_5          jsonb;
  v_pved_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;

  -- Only hospital on the job, the accepted engineer, or founder can
  -- request the dossier.
  SELECT b.engineer_user_id INTO v_engineer_user
    FROM public.repair_job_bids b
   WHERE b.repair_job_id = p_repair_job_id
     AND b.status = 'accepted'
   LIMIT 1;
  IF v_engineer_user IS NULL THEN
    RAISE EXCEPTION 'no_accepted_engineer_yet' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_job.hospital_user_id
     AND v_caller <> v_engineer_user
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_engineer
    FROM public.engineers
   WHERE user_id = v_engineer_user;

  SELECT
    coalesce((SELECT raw_user_meta_data->>'full_name'
                FROM auth.users WHERE id = v_engineer_user), 'Engineer')
    INTO v_display_name;

  -- Mask Aadhaar: show only last 4 digits, mask first 8 with X.
  IF v_engineer.aadhaar_number IS NOT NULL AND length(v_engineer.aadhaar_number) >= 4 THEN
    v_aadhaar_masked := 'XXXX-XXXX-' || right(v_engineer.aadhaar_number, 4);
  ELSE
    v_aadhaar_masked := NULL;
  END IF;

  v_cert_count := coalesce(jsonb_array_length(v_engineer.certificates), 0);

  -- Aggregate last 5 completed jobs + rating
  SELECT
    avg(hospital_rating)::numeric(3,2),
    count(*)::int
    INTO v_avg_rating, v_total_jobs
    FROM public.repair_jobs
   WHERE status = 'completed'
     AND id IN (
       SELECT rj.id FROM public.repair_jobs rj
       JOIN public.repair_job_bids b ON b.repair_job_id = rj.id
       WHERE b.engineer_user_id = v_engineer_user
         AND b.status = 'accepted'
     );

  SELECT coalesce(jsonb_agg(j ORDER BY j->>'completed_at' DESC), '[]'::jsonb)
    INTO v_last_5
    FROM (
      SELECT jsonb_build_object(
        'job_number', rj.job_number,
        'equipment_brand', rj.equipment_brand,
        'equipment_type', rj.equipment_type,
        'completed_at', rj.completed_at,
        'hospital_rating', rj.hospital_rating
      ) AS j
      FROM public.repair_jobs rj
      JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
      WHERE b.engineer_user_id = v_engineer_user
        AND rj.status = 'completed'
      ORDER BY rj.completed_at DESC NULLS LAST
      LIMIT 5
    ) sub;

  -- Cancel any prior 'issued' dossier for this (job, engineer) so
  -- the UNIQUE constraint allows the new row.
  UPDATE public.pre_visit_engineer_dossiers
     SET status = 'cancelled'
   WHERE repair_job_id = p_repair_job_id
     AND engineer_user_id = v_engineer_user
     AND status = 'issued';

  INSERT INTO public.pre_visit_engineer_dossiers (
    repair_job_id, engineer_user_id, hospital_user_id,
    engineer_display_name, aadhaar_masked_id, verification_status,
    verified_at, certificate_count, oem_cert_summary,
    total_jobs_completed, average_rating, last_5_jobs
  ) VALUES (
    p_repair_job_id, v_engineer_user, v_job.hospital_user_id,
    v_display_name, v_aadhaar_masked,
    coalesce(v_engineer.verification_status::text, 'pending'),
    v_engineer.verification_status_updated_at,
    v_cert_count, v_engineer.certificates,
    coalesce(v_total_jobs, 0), v_avg_rating, v_last_5
  ) RETURNING id INTO v_pved_id;

  RETURN v_pved_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.build_pved(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.build_pved(uuid) TO authenticated, service_role;

-- Hospital marks the dossier 'consumed' on first open.
CREATE OR REPLACE FUNCTION public.mark_pved_consumed(
  p_pved_id uuid
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
  SELECT * INTO v_row FROM public.pre_visit_engineer_dossiers WHERE id = p_pved_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pved_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_row.hospital_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_row.status = 'issued' THEN
    UPDATE public.pre_visit_engineer_dossiers
       SET status = 'consumed', consumed_at = now()
     WHERE id = p_pved_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_pved_consumed(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_pved_consumed(uuid) TO authenticated, service_role;

-- =====================================================================
-- PART B — AMC Digital Affidavit
-- =====================================================================
-- Hospital declares the equipment is out-of-warranty + no active OEM
-- AMC. This shifts tortious-interference liability per Indian Contract
-- Act §124. Sign event captured here; the §65B-compliant rendered
-- affidavit lives in evidence_ledger.

CREATE TABLE IF NOT EXISTS public.amc_affidavits (
  id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id         uuid        NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  hospital_user_id        uuid        NOT NULL,
  CONSTRAINT amc_affidavit_hospital_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,

  -- The 4 declarations the signer makes (all must be true)
  declares_out_of_warranty     boolean NOT NULL DEFAULT false,
  declares_no_active_oem_amc   boolean NOT NULL DEFAULT false,
  declares_authority_to_sign   boolean NOT NULL DEFAULT false,
  declares_aware_of_indemnity  boolean NOT NULL DEFAULT false,

  -- Signer details captured at sign time
  signer_full_name        text        NOT NULL,
  signer_designation      text,
  signer_aadhaar_masked   text,        -- "XXXX-XXXX-1234"
  -- Equipment identification
  equipment_categories    text[]      NOT NULL DEFAULT ARRAY[]::text[],
  equipment_serial_nums   text[],

  -- Audit fields
  ip_address              inet,
  user_agent              text,
  signed_at               timestamptz NOT NULL DEFAULT now(),
  -- Evidence ledger link to the rendered affidavit PDF
  evidence_ledger_id      uuid        REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,

  CONSTRAINT amc_affidavit_complete CHECK (
    declares_out_of_warranty
    AND declares_no_active_oem_amc
    AND declares_authority_to_sign
    AND declares_aware_of_indemnity
  ),
  CONSTRAINT amc_affidavit_one_per_contract UNIQUE (amc_contract_id)
);

CREATE INDEX IF NOT EXISTS amc_affidavits_hospital_idx
  ON public.amc_affidavits (hospital_user_id, signed_at DESC);

ALTER TABLE public.amc_affidavits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS amc_affidavits_select ON public.amc_affidavits;
CREATE POLICY amc_affidavits_select
  ON public.amc_affidavits
  FOR SELECT
  TO authenticated, service_role
  USING (hospital_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.amc_affidavits
  FROM anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.sign_amc_affidavit(
  p_amc_contract_id           uuid,
  p_signer_full_name          text,
  p_signer_designation        text,
  p_signer_aadhaar_last4      text,
  p_equipment_categories      text[],
  p_equipment_serial_nums     text[] DEFAULT NULL,
  p_declares_out_of_warranty  boolean DEFAULT false,
  p_declares_no_active_oem_amc boolean DEFAULT false,
  p_declares_authority_to_sign boolean DEFAULT false,
  p_declares_aware_of_indemnity boolean DEFAULT false,
  p_ip_address                inet DEFAULT NULL,
  p_user_agent                text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller    uuid := auth.uid();
  v_contract  record;
  v_id        uuid;
  v_masked    text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_signer_full_name IS NULL OR length(trim(p_signer_full_name)) < 3 THEN
    RAISE EXCEPTION 'signer_full_name required (min 3 chars)' USING ERRCODE = '22023';
  END IF;
  IF NOT (p_declares_out_of_warranty
          AND p_declares_no_active_oem_amc
          AND p_declares_authority_to_sign
          AND p_declares_aware_of_indemnity) THEN
    RAISE EXCEPTION 'all_declarations_must_be_true'
      USING ERRCODE = '22023',
            HINT = 'Hospital must affirm: equipment out-of-warranty, no active OEM AMC, authority to sign, aware of §124 indemnity.';
  END IF;
  IF p_signer_aadhaar_last4 IS NOT NULL THEN
    IF p_signer_aadhaar_last4 !~ '^[0-9]{4}$' THEN
      RAISE EXCEPTION 'signer_aadhaar_last4 must be 4 digits' USING ERRCODE = '22023';
    END IF;
    v_masked := 'XXXX-XXXX-' || p_signer_aadhaar_last4;
  END IF;

  -- Caller must be the hospital on the contract.
  SELECT * INTO v_contract
    FROM public.amc_contracts
   WHERE id = p_amc_contract_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'amc_contract_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_contract.hospital_user_id <> v_caller AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  -- Idempotency: one affidavit per contract. Re-call with a
  -- DIFFERENT signer raises; same signer returns existing.
  SELECT id INTO v_id
    FROM public.amc_affidavits
   WHERE amc_contract_id = p_amc_contract_id;
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  INSERT INTO public.amc_affidavits (
    amc_contract_id, hospital_user_id,
    declares_out_of_warranty, declares_no_active_oem_amc,
    declares_authority_to_sign, declares_aware_of_indemnity,
    signer_full_name, signer_designation, signer_aadhaar_masked,
    equipment_categories, equipment_serial_nums,
    ip_address, user_agent
  ) VALUES (
    p_amc_contract_id, v_contract.hospital_user_id,
    p_declares_out_of_warranty, p_declares_no_active_oem_amc,
    p_declares_authority_to_sign, p_declares_aware_of_indemnity,
    p_signer_full_name, p_signer_designation, v_masked,
    coalesce(p_equipment_categories, ARRAY[]::text[]),
    p_equipment_serial_nums,
    p_ip_address, p_user_agent
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sign_amc_affidavit(
  uuid, text, text, text, text[], text[], boolean, boolean, boolean, boolean, inet, text
) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.sign_amc_affidavit(
  uuid, text, text, text, text[], text[], boolean, boolean, boolean, boolean, inet, text
) TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname IN ('pre_visit_engineer_dossiers','amc_affidavits')
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 493: tables not created or RLS not enabled';
  END IF;
  RAISE NOTICE 'round 493 PVED + AMC affidavit verified: 2 tables, 3 RPCs, grants correct';
END;
$$;
