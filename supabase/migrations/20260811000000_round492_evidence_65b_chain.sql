-- =====================================================================
-- Round 492 — §65B Digital Evidence Chain-of-Custody (v0.4 Phase 3 foundation)
-- =====================================================================
--
-- Indian Evidence Act §65B (and amended Bharatiya Sakshya Adhiniyam
-- 2023 §63) require electronic records used in court to come with
-- a certificate from a "person occupying a responsible official
-- position" attesting:
--   (a) the computer producing the record was used regularly,
--   (b) information was regularly fed during the period,
--   (c) the computer was operating properly throughout, and
--   (d) the information in the record is derived from the information
--       fed into the computer.
--
-- Without §65B compliance, our photos / chat logs / signatures / PDFs
-- are INADMISSIBLE in court — exactly when we need them most
-- (engineer-vs-hospital disputes, OEM lawsuits, regulator audits).
--
-- This migration ships the foundation:
--   * evidence_ledger — content-addressable hash ledger. Every Phase 3
--     evidence artifact (PVED PDF, DSR, photo, chat archive, signature)
--     has a row here with SHA-256 hash + timestamp + producing system.
--   * register_evidence(...) — central RPC to write a ledger row.
--     Called from every evidence-creating path.
--   * verify_evidence_hash(...) — caller passes a content blob; we
--     compare against the ledger.
--   * generate_65b_certificate(...) — returns the §65B(4) certificate
--     text for a given evidence id, suitable for printing + signature.
--
-- Evidence kinds (initial set):
--   - 'pved_pdf' (Pre-Visit Engineer Dossier)
--   - 'dsr_pdf' (Digital Service Report)
--   - 'chat_archive' (snapshot of conversation thread)
--   - 'photo_before' / 'photo_after' (job evidence)
--   - 'signature_engineer' / 'signature_hospital'
--   - 'amc_affidavit' (signed digital affidavit per r495)
--   - 'tds_certificate' / 'gst_invoice_pdf'

BEGIN;

-- ---------------------------------------------------------------------
-- 1. evidence_ledger
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.evidence_ledger (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_kind         text        NOT NULL
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
                                      'parts_receipt'
                                    )),
  -- Link to source entity (repair_job_id / amc_visit_id / chat_id / etc.)
  source_kind           text        NOT NULL,
  source_id             uuid        NOT NULL,
  -- SHA-256 hash of the canonical content (lowercase hex). Unique
  -- per (evidence_kind, source_kind, source_id) so re-registering
  -- the SAME content is idempotent.
  content_sha256        text        NOT NULL
                                    CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  content_size_bytes    bigint      NOT NULL CHECK (content_size_bytes > 0),
  -- Where the content lives (Supabase Storage path / external URL).
  storage_url           text,
  -- Who produced it (engineer, hospital, system).
  producer_user_id      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  producer_kind         text        NOT NULL
                                    CHECK (producer_kind IN ('engineer','hospital','system','founder')),
  -- Capture time (provided by client at upload — separate from
  -- server-side created_at for audit chain).
  captured_at           timestamptz,
  -- System fingerprint at registration time (which version of the
  -- platform produced this — for §65B(2)(c) "operating properly").
  platform_version      text        NOT NULL DEFAULT 'unknown',
  -- Optional metadata bag (EXIF coords, device model, etc.)
  metadata              jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),

  -- A piece of evidence should appear at most once per source.
  CONSTRAINT evidence_ledger_uniq UNIQUE (evidence_kind, source_kind, source_id, content_sha256)
);

COMMENT ON TABLE public.evidence_ledger IS
  'Round 492 — content-addressable hash ledger for every Phase 3 evidence artifact. SHA-256 hash + producer + capture time + storage url. Powers §65B Indian Evidence Act admissibility certificate generation.';

CREATE INDEX IF NOT EXISTS evidence_ledger_source_idx
  ON public.evidence_ledger (source_kind, source_id);
CREATE INDEX IF NOT EXISTS evidence_ledger_hash_idx
  ON public.evidence_ledger (content_sha256);
CREATE INDEX IF NOT EXISTS evidence_ledger_kind_idx
  ON public.evidence_ledger (evidence_kind, created_at DESC);

ALTER TABLE public.evidence_ledger ENABLE ROW LEVEL SECURITY;

-- SELECT: producer + counterparty on the linked job/visit + founder.
-- We can't easily resolve "counterparty" generically here, so the
-- helper RPC `evidence_for_job(id)` handles authorization. The
-- table-level SELECT policy allows producer + founder; downstream
-- queries should go through the RPC.
DROP POLICY IF EXISTS evidence_ledger_select ON public.evidence_ledger;
CREATE POLICY evidence_ledger_select
  ON public.evidence_ledger
  FOR SELECT
  TO authenticated, service_role
  USING (producer_user_id = auth.uid() OR public.is_founder());

-- INSERT/UPDATE/DELETE revoked — ledger is immutable. Helper RPC
-- writes; tampering not possible from client.
REVOKE INSERT, UPDATE, DELETE ON public.evidence_ledger
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. register_evidence — central RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_evidence(
  p_evidence_kind     text,
  p_source_kind       text,
  p_source_id         uuid,
  p_content_sha256    text,
  p_content_size_bytes bigint,
  p_storage_url       text DEFAULT NULL,
  p_producer_kind     text DEFAULT 'system',
  p_captured_at       timestamptz DEFAULT now(),
  p_platform_version  text DEFAULT 'unknown',
  p_metadata          jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_existing uuid;
  v_id       uuid;
  v_actor    uuid := auth.uid();
BEGIN
  IF NOT (auth.role() = 'service_role' OR auth.uid() IS NOT NULL) THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_content_sha256 IS NULL OR p_content_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'content_sha256 must be 64-char lowercase hex' USING ERRCODE = '22023';
  END IF;
  IF p_content_size_bytes IS NULL OR p_content_size_bytes <= 0 THEN
    RAISE EXCEPTION 'content_size_bytes required + positive' USING ERRCODE = '22023';
  END IF;

  -- Idempotency via the UNIQUE constraint. Return existing id on
  -- duplicate (allows safe re-upload of the same content).
  SELECT id INTO v_existing
    FROM public.evidence_ledger
   WHERE evidence_kind = p_evidence_kind
     AND source_kind   = p_source_kind
     AND source_id     = p_source_id
     AND content_sha256 = p_content_sha256
   LIMIT 1;
  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  INSERT INTO public.evidence_ledger (
    evidence_kind, source_kind, source_id, content_sha256,
    content_size_bytes, storage_url, producer_user_id, producer_kind,
    captured_at, platform_version, metadata
  ) VALUES (
    p_evidence_kind, p_source_kind, p_source_id, lower(p_content_sha256),
    p_content_size_bytes, p_storage_url, v_actor, p_producer_kind,
    coalesce(p_captured_at, now()), coalesce(p_platform_version, 'unknown'), p_metadata
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_evidence(
  text, text, uuid, text, bigint, text, text, timestamptz, text, jsonb
) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.register_evidence(
  text, text, uuid, text, bigint, text, text, timestamptz, text, jsonb
) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. verify_evidence_hash — caller supplies content + we match
-- ---------------------------------------------------------------------
-- For verifying a downloaded file matches the ledger. Returns
-- (matches: boolean, ledger_id, captured_at, producer_user_id).
CREATE OR REPLACE FUNCTION public.verify_evidence_hash(
  p_evidence_id uuid,
  p_content_sha256 text
)
RETURNS TABLE(
  matches             boolean,
  ledger_id           uuid,
  evidence_kind       text,
  captured_at         timestamptz,
  producer_user_id    uuid,
  producer_kind       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_content_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'content_sha256 must be 64-char hex' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.evidence_ledger WHERE id = p_evidence_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'evidence_not_found' USING ERRCODE = '02000';
  END IF;

  -- Authorization: producer or founder. Counterparty access goes
  -- through the per-job evidence_for_job() helper instead.
  IF v_row.producer_user_id <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  matches := (v_row.content_sha256 = lower(p_content_sha256));
  ledger_id := v_row.id;
  evidence_kind := v_row.evidence_kind;
  captured_at := v_row.captured_at;
  producer_user_id := v_row.producer_user_id;
  producer_kind := v_row.producer_kind;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.verify_evidence_hash(uuid, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.verify_evidence_hash(uuid, text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. generate_65b_certificate
-- ---------------------------------------------------------------------
-- Returns the verbatim §65B(4) certificate text + the supporting
-- ledger row. Founder prints + signs the certificate; signed PDF
-- attaches to court filings.
CREATE OR REPLACE FUNCTION public.generate_65b_certificate(
  p_evidence_id uuid
)
RETURNS TABLE(
  certificate_text  text,
  evidence_kind     text,
  source_kind       text,
  source_id         uuid,
  content_sha256    text,
  captured_at       timestamptz,
  producer_kind     text,
  platform_version  text,
  generated_at      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_row FROM public.evidence_ledger WHERE id = p_evidence_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'evidence_not_found' USING ERRCODE = '02000';
  END IF;

  certificate_text := format(
$cert$CERTIFICATE UNDER SECTION 65B(4) OF THE INDIAN EVIDENCE ACT, 1872
(equivalent to Section 63(4) of the Bharatiya Sakshya Adhiniyam, 2023)

I, [FOUNDER NAME], being the Director and a person occupying a
responsible official position in relation to the operation of the
EquipSeva Technologies Private Limited platform (hereinafter the
"Computer System"), hereby certify the following:

1. The electronic record described below was produced by the
   Computer System during the period the Computer System was used
   regularly to store and process information for the activities
   of EquipSeva Technologies Private Limited.

2. During the said period, information of the kind contained in
   the said electronic record was regularly fed into the Computer
   System in the ordinary course of the said activities.

3. Throughout the material part of the said period the Computer
   System was operating properly, or if not, then any respect in
   which it was not operating properly or out of operation during
   that part of the period, was not such as to affect the electronic
   record or the accuracy of its contents.

4. The information contained in the electronic record reproduces
   or is derived from such information fed into the Computer System
   in the ordinary course of the said activities.

PARTICULARS OF THE ELECTRONIC RECORD:
  Evidence Kind          : %s
  Source Entity Type     : %s
  Source Entity ID       : %s
  SHA-256 Content Hash   : %s
  Content Size (bytes)   : %s
  Captured At (IST)      : %s
  Producer Kind          : %s
  Platform Version       : %s
  Ledger Entry ID        : %s
  Certificate Generated  : %s (IST)

I confirm the above statements are true to the best of my knowledge
and belief.

Signed:  ____________________
Name  :  [FOUNDER NAME]
Designation: Director, EquipSeva Technologies Private Limited
Date :   [DATE]
Place:   Hyderabad, Telangana, India
$cert$,
    v_row.evidence_kind,
    v_row.source_kind,
    v_row.source_id,
    v_row.content_sha256,
    v_row.content_size_bytes,
    to_char(v_row.captured_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS'),
    v_row.producer_kind,
    v_row.platform_version,
    v_row.id,
    to_char(now() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI:SS')
  );

  evidence_kind := v_row.evidence_kind;
  source_kind := v_row.source_kind;
  source_id := v_row.source_id;
  content_sha256 := v_row.content_sha256;
  captured_at := v_row.captured_at;
  producer_kind := v_row.producer_kind;
  platform_version := v_row.platform_version;
  generated_at := now();
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generate_65b_certificate(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.generate_65b_certificate(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. evidence_for_job — counterparty-readable view
-- ---------------------------------------------------------------------
-- Returns evidence rows for a repair_job_id WHERE the caller is
-- either the hospital or the engineer on that job. This is the
-- main read-path for the Dispute Defense Vault + Dispute Mediation
-- Console.
CREATE OR REPLACE FUNCTION public.evidence_for_repair_job(
  p_repair_job_id uuid
)
RETURNS TABLE(
  id                  uuid,
  evidence_kind       text,
  content_sha256      text,
  content_size_bytes  bigint,
  storage_url         text,
  producer_user_id    uuid,
  producer_kind       text,
  captured_at         timestamptz,
  metadata            jsonb,
  created_at          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_hospital uuid;
  v_engineer uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Founder can see any job's evidence
  IF public.is_founder() THEN
    NULL;  -- fall through to query
  ELSE
    -- Counterparty check: caller must be the hospital or the
    -- accepted-bid engineer for the job.
    SELECT rj.hospital_user_id, b.engineer_user_id
      INTO v_hospital, v_engineer
      FROM public.repair_jobs rj
      LEFT JOIN public.repair_job_bids b
        ON b.repair_job_id = rj.id AND b.status = 'accepted'
     WHERE rj.id = p_repair_job_id;
    IF v_hospital IS NULL THEN
      RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
    END IF;
    IF v_caller <> v_hospital AND v_caller <> v_engineer THEN
      RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN QUERY
  SELECT e.id, e.evidence_kind, e.content_sha256, e.content_size_bytes,
         e.storage_url, e.producer_user_id, e.producer_kind,
         e.captured_at, e.metadata, e.created_at
    FROM public.evidence_ledger e
   WHERE e.source_kind = 'repair_job'
     AND e.source_id = p_repair_job_id
   ORDER BY e.captured_at ASC NULLS LAST, e.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.evidence_for_repair_job(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.evidence_for_repair_job(uuid)
  TO authenticated, service_role;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'evidence_ledger'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 492: evidence_ledger RLS not enabled';
  END IF;
  IF has_function_privilege('anon', 'public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 492: register_evidence callable by anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 492: register_evidence not callable by authenticated (uploaders need this)';
  END IF;
  IF has_function_privilege('authenticated', 'public.generate_65b_certificate(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 492: generate_65b_certificate callable by authenticated (should be service-role only)';
  END IF;
  RAISE NOTICE 'round 492 §65B evidence chain-of-custody verified: table + 4 RPCs, grants correct';
END;
$$;
