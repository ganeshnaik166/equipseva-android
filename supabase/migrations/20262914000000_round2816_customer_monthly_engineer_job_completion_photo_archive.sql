BEGIN;

-- ============================================================================
-- Round 2816 — Customer Monthly Engineer Job Completion Photo Archive
-- Spec: job x photos x resolution proof x customer signoff x archive verdict
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: job_completion_photo_archive_r2816
-- One row per completed job's photo archive bundle
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.job_completion_photo_archive_r2816 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  archive_month date NOT NULL,
  customer_org_name text NOT NULL,
  engineer_name text NOT NULL,
  job_code text NOT NULL,
  job_kind text NOT NULL CHECK (job_kind IN ('repair','maintenance','amc_visit','installation')),
  equipment_label text NOT NULL,
  photos_uploaded int NOT NULL CHECK (photos_uploaded >= 0),
  photos_required int NOT NULL CHECK (photos_required >= 0),
  resolution_proof_ok boolean NOT NULL DEFAULT false,
  customer_signoff_received boolean NOT NULL DEFAULT false,
  customer_signoff_at timestamptz,
  archive_verdict text NOT NULL CHECK (archive_verdict IN ('clean','minor_gaps','rejected','pending_review')),
  archive_score_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (archive_score_pct >= 0 AND archive_score_pct <= 100),
  storage_bytes bigint NOT NULL DEFAULT 0 CHECK (storage_bytes >= 0),
  reviewer_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.job_completion_photo_archive_r2816 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.job_completion_photo_archive_r2816;
CREATE POLICY founder_all
  ON public.job_completion_photo_archive_r2816
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO public.job_completion_photo_archive_r2816
  (archive_month, customer_org_name, engineer_name, job_code, job_kind, equipment_label,
   photos_uploaded, photos_required, resolution_proof_ok, customer_signoff_received,
   customer_signoff_at, archive_verdict, archive_score_pct, storage_bytes, reviewer_note)
VALUES
  ('2026-06-01'::date, 'Apollo Hyderabad', 'Ravi Kumar', 'JOB-22001', 'repair',         'GE Logiq P9 Ultrasound',  8, 6, true,  true,  '2026-06-02 11:14+05:30'::timestamptz, 'clean',         98.50,  4823901, 'all angles + before/after captured'),
  ('2026-06-01'::date, 'Yashoda Secunderabad', 'Sneha Reddy', 'JOB-22014', 'amc_visit',    'Mindray BeneVision N15', 5, 6, true,  true,  '2026-06-05 09:42+05:30'::timestamptz, 'minor_gaps',    82.00,  2918244, 'missing rear panel shot'),
  ('2026-06-01'::date, 'KIMS Kondapur', 'Imran Pasha', 'JOB-22033', 'installation', 'Philips DigitalDiagnost C90', 12, 10, true, true,  '2026-06-07 16:08+05:30'::timestamptz, 'clean',         99.10,  9412877, 'commissioning bundle complete'),
  ('2026-06-01'::date, 'Care Banjara', 'Lakshmi Devi', 'JOB-22057', 'maintenance',  'Drager Fabius GS Anesthesia',  4, 6, false, false, NULL,                                       'rejected',      45.00,  1204337, 'blurry photos, no signoff'),
  ('2026-06-01'::date, 'Continental Gachibowli', 'Rahul Verma', 'JOB-22078', 'repair', 'Siemens Cios Alpha C-Arm',   7, 6, true,  true,  '2026-06-12 13:55+05:30'::timestamptz, 'clean',         95.20,  5612998, 'sharp images, OEM tag visible'),
  ('2026-06-01'::date, 'Sunshine Paradise', 'Kavya Iyer', 'JOB-22091', 'amc_visit',   'BPL Cardiart 9108',           6, 6, true,  false, NULL,                                       'pending_review', 70.00,  2099812, 'awaiting customer reply'),
  ('2026-06-01'::date, 'Rainbow Vikrampuri', 'Naveen Goud', 'JOB-22112', 'repair',     'Mindray DC-70 Ultrasound',    9, 8, true,  true,  '2026-06-15 10:21+05:30'::timestamptz, 'clean',         97.80,  6738451, 'serial + part swap proof');

-- ----------------------------------------------------------------------------
-- Table 2: photo_archive_audit_log_r2816
-- Audit events per archive bundle (reviewer actions + verdict transitions)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.photo_archive_audit_log_r2816 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  archive_id uuid REFERENCES public.job_completion_photo_archive_r2816(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('uploaded','resolution_check','customer_signoff','verdict_set','reviewer_note','escalated')),
  actor_role text NOT NULL CHECK (actor_role IN ('engineer','customer','reviewer','system','founder')),
  detail text NOT NULL,
  prior_verdict text,
  new_verdict text
);

ALTER TABLE public.photo_archive_audit_log_r2816 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.photo_archive_audit_log_r2816;
CREATE POLICY founder_all
  ON public.photo_archive_audit_log_r2816
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO public.photo_archive_audit_log_r2816
  (event_at, event_kind, actor_role, detail, prior_verdict, new_verdict)
VALUES
  ('2026-06-02 10:01+05:30'::timestamptz, 'uploaded',           'engineer', 'engineer uploaded 8 photos for JOB-22001', NULL, NULL),
  ('2026-06-02 10:30+05:30'::timestamptz, 'resolution_check',   'system',   'sharpness + EXIF metadata verified', NULL, 'clean'),
  ('2026-06-05 09:42+05:30'::timestamptz, 'customer_signoff',   'customer', 'Yashoda Secunderabad signoff received', NULL, NULL),
  ('2026-06-07 16:10+05:30'::timestamptz, 'verdict_set',        'reviewer', 'commissioning bundle verified clean', 'pending_review', 'clean'),
  ('2026-06-09 14:22+05:30'::timestamptz, 'reviewer_note',      'reviewer', 'Care Banjara photos blurry, reject', 'pending_review', 'rejected'),
  ('2026-06-12 11:00+05:30'::timestamptz, 'escalated',          'founder',  'escalated rejected archive to ops chief', 'rejected', 'rejected'),
  ('2026-06-15 10:25+05:30'::timestamptz, 'customer_signoff',   'customer', 'Rainbow Vikrampuri signed off', NULL, NULL);

-- ============================================================================
-- RPCs (7 SECDEF, all founder-gated)
-- ============================================================================

-- RPC 1: KPIs
DROP FUNCTION IF EXISTS public.kpis_photo_archive_r2816();
CREATE OR REPLACE FUNCTION public.kpis_photo_archive_r2816()
RETURNS TABLE (
  total_archives bigint,
  clean_count bigint,
  rejected_count bigint,
  pending_count bigint,
  avg_score_pct numeric,
  signoff_rate_pct numeric,
  total_storage_mb numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE archive_verdict = 'clean')::bigint,
    COUNT(*) FILTER (WHERE archive_verdict = 'rejected')::bigint,
    COUNT(*) FILTER (WHERE archive_verdict = 'pending_review')::bigint,
    ROUND(COALESCE(AVG(archive_score_pct), 0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE customer_signoff_received) / NULLIF(COUNT(*), 0), 2),
    ROUND(SUM(storage_bytes)::numeric / 1048576.0, 2)
  FROM public.job_completion_photo_archive_r2816;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.kpis_photo_archive_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kpis_photo_archive_r2816() TO authenticated;

-- RPC 2: list archives
DROP FUNCTION IF EXISTS public.list_photo_archives_r2816();
CREATE OR REPLACE FUNCTION public.list_photo_archives_r2816()
RETURNS TABLE (
  id uuid,
  customer_org_name text,
  engineer_name text,
  job_code text,
  job_kind text,
  equipment_label text,
  photos_uploaded int,
  photos_required int,
  archive_verdict text,
  archive_score_pct numeric,
  customer_signoff_received boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.customer_org_name, a.engineer_name, a.job_code, a.job_kind,
         a.equipment_label, a.photos_uploaded, a.photos_required, a.archive_verdict,
         a.archive_score_pct, a.customer_signoff_received
  FROM public.job_completion_photo_archive_r2816 a
  ORDER BY a.archive_score_pct DESC, a.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_photo_archives_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photo_archives_r2816() TO authenticated;

-- RPC 3: verdict breakdown
DROP FUNCTION IF EXISTS public.verdict_breakdown_r2816();
CREATE OR REPLACE FUNCTION public.verdict_breakdown_r2816()
RETURNS TABLE (
  verdict text,
  bundle_count bigint,
  avg_score numeric,
  total_photos bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.archive_verdict,
    COUNT(*)::bigint,
    ROUND(AVG(a.archive_score_pct), 2),
    SUM(a.photos_uploaded)::bigint
  FROM public.job_completion_photo_archive_r2816 a
  GROUP BY a.archive_verdict
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.verdict_breakdown_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verdict_breakdown_r2816() TO authenticated;

-- RPC 4: engineer leaderboard
DROP FUNCTION IF EXISTS public.engineer_archive_leaderboard_r2816();
CREATE OR REPLACE FUNCTION public.engineer_archive_leaderboard_r2816()
RETURNS TABLE (
  engineer_name text,
  archives bigint,
  clean_archives bigint,
  avg_score numeric,
  signoff_rate numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.engineer_name,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE a.archive_verdict = 'clean')::bigint,
    ROUND(AVG(a.archive_score_pct), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.customer_signoff_received) / NULLIF(COUNT(*), 0), 2)
  FROM public.job_completion_photo_archive_r2816 a
  GROUP BY a.engineer_name
  ORDER BY AVG(a.archive_score_pct) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_archive_leaderboard_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_archive_leaderboard_r2816() TO authenticated;

-- RPC 5: gaps watchlist (photos short of required)
DROP FUNCTION IF EXISTS public.archive_gaps_r2816();
CREATE OR REPLACE FUNCTION public.archive_gaps_r2816()
RETURNS TABLE (
  job_code text,
  customer_org_name text,
  engineer_name text,
  photos_uploaded int,
  photos_required int,
  gap int,
  archive_verdict text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.job_code, a.customer_org_name, a.engineer_name,
         a.photos_uploaded, a.photos_required,
         (a.photos_required - a.photos_uploaded) AS gap,
         a.archive_verdict
  FROM public.job_completion_photo_archive_r2816 a
  WHERE a.photos_uploaded < a.photos_required
     OR NOT a.resolution_proof_ok
     OR NOT a.customer_signoff_received
  ORDER BY (a.photos_required - a.photos_uploaded) DESC, a.archive_verdict;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.archive_gaps_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.archive_gaps_r2816() TO authenticated;

-- RPC 6: audit timeline
DROP FUNCTION IF EXISTS public.audit_log_timeline_r2816();
CREATE OR REPLACE FUNCTION public.audit_log_timeline_r2816()
RETURNS TABLE (
  event_at timestamptz,
  event_kind text,
  actor_role text,
  detail text,
  prior_verdict text,
  new_verdict text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT l.event_at, l.event_kind, l.actor_role, l.detail, l.prior_verdict, l.new_verdict
  FROM public.photo_archive_audit_log_r2816 l
  ORDER BY l.event_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.audit_log_timeline_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_log_timeline_r2816() TO authenticated;

-- RPC 7: set verdict (write path)
DROP FUNCTION IF EXISTS public.set_archive_verdict_r2816(uuid, text, text);
CREATE OR REPLACE FUNCTION public.set_archive_verdict_r2816(p_id uuid, p_new_verdict text, p_note text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prior text;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_verdict NOT IN ('clean','minor_gaps','rejected','pending_review') THEN
    RAISE EXCEPTION 'invalid verdict %', p_new_verdict;
  END IF;
  SELECT archive_verdict INTO v_prior
  FROM public.job_completion_photo_archive_r2816
  WHERE id = p_id;
  IF v_prior IS NULL THEN
    RAISE EXCEPTION 'archive not found %', p_id;
  END IF;
  UPDATE public.job_completion_photo_archive_r2816
     SET archive_verdict = p_new_verdict,
         reviewer_note = COALESCE(p_note, reviewer_note)
   WHERE id = p_id;
  INSERT INTO public.photo_archive_audit_log_r2816
    (archive_id, event_kind, actor_role, detail, prior_verdict, new_verdict)
  VALUES
    (p_id, 'verdict_set', 'founder', COALESCE(p_note, 'verdict updated'), v_prior, p_new_verdict);
  RETURN p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_archive_verdict_r2816(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_archive_verdict_r2816(uuid, text, text) TO authenticated;

-- RPC 8: storage rollup by job kind
DROP FUNCTION IF EXISTS public.storage_rollup_r2816();
CREATE OR REPLACE FUNCTION public.storage_rollup_r2816()
RETURNS TABLE (
  job_kind text,
  bundle_count bigint,
  total_photos bigint,
  storage_mb numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.job_kind,
         COUNT(*)::bigint,
         SUM(a.photos_uploaded)::bigint,
         ROUND(SUM(a.storage_bytes)::numeric / 1048576.0, 2)
  FROM public.job_completion_photo_archive_r2816 a
  GROUP BY a.job_kind
  ORDER BY SUM(a.storage_bytes) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.storage_rollup_r2816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.storage_rollup_r2816() TO authenticated;

COMMIT;
