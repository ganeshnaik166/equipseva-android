-- Round 2586: engineer-customer-photo-evidence-archive
-- Photo x job x customer x privacy review x archive x retrieval x DPDP

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_photo_archive_r2586 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  photo_url text NOT NULL,
  job_external_ref text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  privacy_review_status text NOT NULL DEFAULT 'pending'
    CHECK (privacy_review_status IN ('pending','approved','redacted','rejected')),
  redaction_reason_md text,
  archive_kind text NOT NULL DEFAULT 'active'
    CHECK (archive_kind IN ('active','cold_storage','expired')),
  dpdp_compliance_status text NOT NULL DEFAULT 'compliant'
    CHECK (dpdp_compliance_status IN ('compliant','marginal','non_compliant')),
  owner_email text,
  status text NOT NULL DEFAULT 'captured'
    CHECK (status IN ('captured','under_review','approved','archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.photo_retrieval_requests_r2586 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.engineer_photo_archive_r2586(id) ON DELETE CASCADE,
  requested_at timestamptz NOT NULL DEFAULT now(),
  requester_email text,
  request_kind text NOT NULL DEFAULT 'audit'
    CHECK (request_kind IN ('audit','legal','dispute','training','clinical_outcome')),
  approval_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','denied','expired')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.engineer_photo_archive_r2586 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_retrieval_requests_r2586 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_photo_archive_r2586;
CREATE POLICY founder_all ON public.engineer_photo_archive_r2586
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.photo_retrieval_requests_r2586;
CREATE POLICY founder_all ON public.photo_retrieval_requests_r2586
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.engineer_photo_archive_r2586
  (photo_url, job_external_ref, captured_at, privacy_review_status, redaction_reason_md, archive_kind, dpdp_compliance_status, owner_email, status, notes)
VALUES
  ('https://cdn.equipseva.in/photos/job-9001-pre.jpg', 'JOB-9001', now() - interval '120 days', 'approved', NULL, 'active', 'compliant', 'archive@equipseva.in', 'approved', 'Pre-service shot of ventilator front panel.'),
  ('https://cdn.equipseva.in/photos/job-9002-post.jpg', 'JOB-9002', now() - interval '95 days', 'redacted', 'Patient ID band visible; redacted in V2.', 'active', 'marginal', 'archive@equipseva.in', 'under_review', 'Reshoot recommended next visit.'),
  ('https://cdn.equipseva.in/photos/job-9003-error.jpg', 'JOB-9003', now() - interval '210 days', 'approved', NULL, 'cold_storage', 'compliant', 'archive@equipseva.in', 'archived', 'Error screen capture for vendor RCA.'),
  ('https://cdn.equipseva.in/photos/job-9004-mri.jpg', 'JOB-9004', now() - interval '400 days', 'rejected', 'Patient face visible behind machine.', 'expired', 'non_compliant', 'archive@equipseva.in', 'archived', 'Purged from cold storage; retain metadata only.'),
  ('https://cdn.equipseva.in/photos/job-9005-pcb.jpg', 'JOB-9005', now() - interval '30 days', 'pending', NULL, 'active', 'compliant', 'archive@equipseva.in', 'captured', 'PCB closeup; queued for privacy review.');

INSERT INTO public.photo_retrieval_requests_r2586
  (photo_id, requested_at, requester_email, request_kind, approval_at, owner_email, status, notes)
SELECT id, now() - interval '20 days', 'audit@equipseva.in', 'audit', now() - interval '19 days', 'archive@equipseva.in', 'approved',
       'NABH spot audit pulled pre-service evidence.'
FROM public.engineer_photo_archive_r2586 WHERE job_external_ref = 'JOB-9001';

INSERT INTO public.photo_retrieval_requests_r2586
  (photo_id, requested_at, requester_email, request_kind, approval_at, owner_email, status, notes)
SELECT id, now() - interval '10 days', 'legal@equipseva.in', 'legal', NULL, 'archive@equipseva.in', 'pending',
       'Counsel reviewing for hospital dispute.'
FROM public.engineer_photo_archive_r2586 WHERE job_external_ref = 'JOB-9002';

INSERT INTO public.photo_retrieval_requests_r2586
  (photo_id, requested_at, requester_email, request_kind, approval_at, owner_email, status, notes)
SELECT id, now() - interval '60 days', 'qa@equipseva.in', 'training', now() - interval '59 days', 'archive@equipseva.in', 'denied',
       'Photo failed DPDP screen; cannot use for training set.'
FROM public.engineer_photo_archive_r2586 WHERE job_external_ref = 'JOB-9004';

INSERT INTO public.photo_retrieval_requests_r2586
  (photo_id, requested_at, requester_email, request_kind, approval_at, owner_email, status, notes)
SELECT id, now() - interval '5 days', 'clinical@equipseva.in', 'clinical_outcome', now() - interval '4 days', 'archive@equipseva.in', 'approved',
       'Cardiology outcome study pulled error capture.'
FROM public.engineer_photo_archive_r2586 WHERE job_external_ref = 'JOB-9003';

INSERT INTO public.photo_retrieval_requests_r2586
  (photo_id, requested_at, requester_email, request_kind, approval_at, owner_email, status, notes)
SELECT id, now() - interval '90 days', 'dispute@equipseva.in', 'dispute', NULL, 'archive@equipseva.in', 'expired',
       'Hospital dispute auto-closed; request expired.'
FROM public.engineer_photo_archive_r2586 WHERE job_external_ref = 'JOB-9001';

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_photo_archive_r2586()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  photo_url text,
  job_external_ref text,
  captured_at timestamptz,
  privacy_review_status text,
  redaction_reason_md text,
  archive_kind text,
  dpdp_compliance_status text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, a.hospital_user_id, a.photo_url, a.job_external_ref,
         a.captured_at, a.privacy_review_status, a.redaction_reason_md, a.archive_kind,
         a.dpdp_compliance_status, a.owner_email, a.status, a.notes, a.created_at
  FROM public.engineer_photo_archive_r2586 a
  ORDER BY a.captured_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_photo_archive_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photo_archive_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_retrieval_requests_r2586()
RETURNS TABLE (
  id uuid,
  photo_id uuid,
  job_external_ref text,
  requested_at timestamptz,
  requester_email text,
  request_kind text,
  approval_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.photo_id, a.job_external_ref, r.requested_at, r.requester_email,
         r.request_kind, r.approval_at, r.owner_email, r.status, r.notes, r.created_at
  FROM public.photo_retrieval_requests_r2586 r
  LEFT JOIN public.engineer_photo_archive_r2586 a ON a.id = r.photo_id
  ORDER BY r.requested_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_retrieval_requests_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_retrieval_requests_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_redacted_photos_r2586()
RETURNS TABLE (
  job_external_ref text,
  privacy_review_status text,
  redaction_reason_md text,
  dpdp_compliance_status text,
  captured_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.job_external_ref, a.privacy_review_status, a.redaction_reason_md,
         a.dpdp_compliance_status, a.captured_at
  FROM public.engineer_photo_archive_r2586 a
  WHERE a.privacy_review_status IN ('redacted','rejected')
  ORDER BY a.captured_at DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_redacted_photos_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_redacted_photos_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.archive_kind_distribution_r2586()
RETURNS TABLE (
  archive_kind text,
  photo_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.archive_kind, count(*)::bigint
  FROM public.engineer_photo_archive_r2586 a
  GROUP BY a.archive_kind
  ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.archive_kind_distribution_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.archive_kind_distribution_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.dpdp_compliance_summary_r2586()
RETURNS TABLE (
  compliant_count bigint,
  marginal_count bigint,
  non_compliant_count bigint,
  compliant_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_compliant bigint;
  v_marginal bigint;
  v_non bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM public.engineer_photo_archive_r2586;
  SELECT count(*) INTO v_compliant FROM public.engineer_photo_archive_r2586 WHERE dpdp_compliance_status = 'compliant';
  SELECT count(*) INTO v_marginal FROM public.engineer_photo_archive_r2586 WHERE dpdp_compliance_status = 'marginal';
  SELECT count(*) INTO v_non FROM public.engineer_photo_archive_r2586 WHERE dpdp_compliance_status = 'non_compliant';
  RETURN QUERY SELECT
    v_compliant,
    v_marginal,
    v_non,
    CASE WHEN v_total > 0 THEN round((v_compliant::numeric / v_total::numeric) * 100, 1) ELSE 0 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dpdp_compliance_summary_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dpdp_compliance_summary_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.request_kind_breakdown_r2586()
RETURNS TABLE (
  request_kind text,
  request_count bigint,
  approved_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.request_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE r.status = 'approved')::bigint
  FROM public.photo_retrieval_requests_r2586 r
  GROUP BY r.request_kind
  ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.request_kind_breakdown_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_kind_breakdown_r2586() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_retrieval_trend_r2586()
RETURNS TABLE (
  month_label text,
  request_count bigint,
  approved_count bigint,
  denied_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', r.requested_at), 'YYYY-MM') AS month_label,
         count(*)::bigint,
         count(*) FILTER (WHERE r.status = 'approved')::bigint,
         count(*) FILTER (WHERE r.status = 'denied')::bigint
  FROM public.photo_retrieval_requests_r2586 r
  GROUP BY date_trunc('month', r.requested_at)
  ORDER BY date_trunc('month', r.requested_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_retrieval_trend_r2586() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_retrieval_trend_r2586() TO authenticated;

