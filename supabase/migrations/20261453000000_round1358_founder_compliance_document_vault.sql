BEGIN;
-- round1358 — Founder compliance document vault
-- Regulatory document storage tracker with renewal cadence enforcement.
-- All RPCs founder-gated. STABLE SECURITY DEFINER plpgsql.

-- 1. Compliance documents ledger
CREATE TABLE IF NOT EXISTS public.founder_compliance_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_label text UNIQUE NOT NULL,
  doc_kind text CHECK (doc_kind IN (
    'udyam_cert','gst_cert','cdsco_license','nabh_cert','iso_cert',
    'msme_cert','company_pan','board_resolution','founder_id_proof',
    'rbi_clearance','dpdp_consent_template','insurance_policy','other'
  )),
  document_number text,
  issued_by text,
  issued_at date,
  valid_until date,
  status text DEFAULT 'active' CHECK (status IN (
    'active','expired','renewed','revoked','draft'
  )),
  storage_kind text CHECK (storage_kind IN (
    'drive_link','s3','onedrive','physical_archive','founder_email','other'
  )),
  storage_uri text,
  owner_user_id uuid REFERENCES auth.users(id),
  renewal_due_date date,
  renewal_reminder_days int DEFAULT 30,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_compliance_documents_status_idx
  ON public.founder_compliance_documents (status, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_compliance_documents_kind_idx
  ON public.founder_compliance_documents (doc_kind);
CREATE INDEX IF NOT EXISTS founder_compliance_documents_renewal_idx
  ON public.founder_compliance_documents (renewal_due_date)
  WHERE status = 'active';

ALTER TABLE public.founder_compliance_documents ENABLE ROW LEVEL SECURITY;

-- 2. Summary RPC — 14 KPIs
DROP FUNCTION IF EXISTS public.founder_compliance_document_vault_summary();
CREATE OR REPLACE FUNCTION public.founder_compliance_document_vault_summary()
RETURNS TABLE (
  total_docs              bigint,
  active_count            bigint,
  expired_count           bigint,
  renewed_count           bigint,
  revoked_count           bigint,
  renewal_due_30d_count   bigint,
  renewal_due_90d_count   bigint,
  renewal_overdue_count   bigint,
  by_kind_udyam           bigint,
  by_kind_gst             bigint,
  by_kind_cdsco           bigint,
  by_kind_nabh            bigint,
  by_kind_iso             bigint,
  oldest_active_age_days  int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO total_docs FROM public.founder_compliance_documents;

  SELECT COUNT(*) FILTER (WHERE status = 'active'),
         COUNT(*) FILTER (WHERE status = 'expired'),
         COUNT(*) FILTER (WHERE status = 'renewed'),
         COUNT(*) FILTER (WHERE status = 'revoked')
    INTO active_count, expired_count, renewed_count, revoked_count
    FROM public.founder_compliance_documents;

  SELECT COUNT(*) FILTER (
           WHERE status = 'active'
             AND renewal_due_date IS NOT NULL
             AND renewal_due_date >= CURRENT_DATE
             AND renewal_due_date <= CURRENT_DATE + INTERVAL '30 days'),
         COUNT(*) FILTER (
           WHERE status = 'active'
             AND renewal_due_date IS NOT NULL
             AND renewal_due_date >= CURRENT_DATE
             AND renewal_due_date <= CURRENT_DATE + INTERVAL '90 days'),
         COUNT(*) FILTER (
           WHERE status = 'active'
             AND renewal_due_date IS NOT NULL
             AND renewal_due_date < CURRENT_DATE)
    INTO renewal_due_30d_count, renewal_due_90d_count, renewal_overdue_count
    FROM public.founder_compliance_documents;

  SELECT COUNT(*) FILTER (WHERE doc_kind = 'udyam_cert'),
         COUNT(*) FILTER (WHERE doc_kind = 'gst_cert'),
         COUNT(*) FILTER (WHERE doc_kind = 'cdsco_license'),
         COUNT(*) FILTER (WHERE doc_kind = 'nabh_cert'),
         COUNT(*) FILTER (WHERE doc_kind = 'iso_cert')
    INTO by_kind_udyam, by_kind_gst, by_kind_cdsco, by_kind_nabh, by_kind_iso
    FROM public.founder_compliance_documents;

  SELECT GREATEST(EXTRACT(DAY FROM (now() - MIN(created_at)))::int, 0)
    INTO oldest_active_age_days
    FROM public.founder_compliance_documents
   WHERE status = 'active';

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compliance_document_vault_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_compliance_document_vault_summary() TO authenticated;

-- 3. Recent documents RPC
DROP FUNCTION IF EXISTS public.founder_compliance_documents_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_compliance_documents_recent(
  p_status text DEFAULT NULL,
  p_kind   text DEFAULT NULL,
  p_limit  int  DEFAULT 100
)
RETURNS TABLE (
  id                 uuid,
  doc_label          text,
  doc_kind           text,
  document_number    text,
  issued_by          text,
  issued_at          date,
  valid_until        date,
  status             text,
  storage_kind       text,
  storage_uri        text,
  renewal_due_date   date,
  days_until_renewal int,
  age_days           int,
  notes              text,
  created_at         timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.doc_label,
    d.doc_kind,
    d.document_number,
    d.issued_by,
    d.issued_at,
    d.valid_until,
    d.status,
    d.storage_kind,
    d.storage_uri,
    d.renewal_due_date,
    CASE
      WHEN d.renewal_due_date IS NOT NULL
      THEN (d.renewal_due_date - CURRENT_DATE)::int
      ELSE NULL
    END,
    GREATEST(EXTRACT(DAY FROM (now() - d.created_at))::int, 0),
    d.notes,
    d.created_at
  FROM public.founder_compliance_documents d
  WHERE (p_status IS NULL OR d.status = p_status)
    AND (p_kind   IS NULL OR d.doc_kind = p_kind)
  ORDER BY d.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compliance_documents_recent(text, text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_compliance_documents_recent(text, text, int) TO authenticated;

-- 4. Renewal-due RPC
DROP FUNCTION IF EXISTS public.founder_compliance_documents_renewal_due(int);
CREATE OR REPLACE FUNCTION public.founder_compliance_documents_renewal_due(
  p_window_days int DEFAULT 90
)
RETURNS TABLE (
  id                 uuid,
  doc_label          text,
  doc_kind           text,
  renewal_due_date   date,
  days_until_renewal int,
  status             text,
  issued_by          text,
  valid_until        date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.doc_label,
    d.doc_kind,
    d.renewal_due_date,
    (d.renewal_due_date - CURRENT_DATE)::int,
    d.status,
    d.issued_by,
    d.valid_until
  FROM public.founder_compliance_documents d
  WHERE d.status = 'active'
    AND d.renewal_due_date IS NOT NULL
    AND d.renewal_due_date <= CURRENT_DATE + (GREATEST(p_window_days, 1) || ' days')::interval
  ORDER BY d.renewal_due_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compliance_documents_renewal_due(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_compliance_documents_renewal_due(int) TO authenticated;

-- 5. Register document
DROP FUNCTION IF EXISTS public.log_founder_compliance_doc_register(text, text, text, text, date, date, text, text, date, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_compliance_doc_register(
  p_doc_label       text,
  p_doc_kind        text,
  p_document_number text    DEFAULT NULL,
  p_issued_by       text    DEFAULT NULL,
  p_issued_at       date    DEFAULT NULL,
  p_valid_until     date    DEFAULT NULL,
  p_storage_kind    text    DEFAULT 'drive_link',
  p_storage_uri     text    DEFAULT NULL,
  p_renewal_due_date date   DEFAULT NULL,
  p_renewal_reminder_days int DEFAULT 30,
  p_notes           text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_compliance_documents (
    doc_label, doc_kind, document_number, issued_by, issued_at, valid_until,
    storage_kind, storage_uri, renewal_due_date, renewal_reminder_days, notes
  ) VALUES (
    p_doc_label, COALESCE(p_doc_kind, 'other'), p_document_number, p_issued_by,
    p_issued_at, p_valid_until,
    COALESCE(p_storage_kind, 'drive_link'), p_storage_uri,
    p_renewal_due_date, COALESCE(p_renewal_reminder_days, 30), p_notes
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_compliance_doc_register(text, text, text, text, date, date, text, text, date, int, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_compliance_doc_register(text, text, text, text, date, date, text, text, date, int, text) TO authenticated;

-- 6. Renew document
DROP FUNCTION IF EXISTS public.log_founder_compliance_doc_renew(uuid, date);
CREATE OR REPLACE FUNCTION public.log_founder_compliance_doc_renew(
  p_id              uuid,
  p_new_valid_until date
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_compliance_documents
     SET valid_until      = p_new_valid_until,
         renewal_due_date = p_new_valid_until - INTERVAL '30 days',
         status           = 'active',
         updated_at       = now()
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_compliance_doc_renew(uuid, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_compliance_doc_renew(uuid, date) TO authenticated;

-- 7. Status update
DROP FUNCTION IF EXISTS public.log_founder_compliance_doc_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_compliance_doc_status(
  p_id         uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('active','expired','renewed','revoked','draft') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.founder_compliance_documents
     SET status     = p_new_status,
         updated_at = now()
   WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_compliance_doc_status(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_compliance_doc_status(uuid, text) TO authenticated;

COMMIT;