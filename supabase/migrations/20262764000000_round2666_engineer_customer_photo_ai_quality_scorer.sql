-- Round 2666: Engineer Customer Photo AI Quality Scorer
-- Score engineer-uploaded photos via AI quality heuristics and track action followups.

BEGIN;

-- =========================================================================
-- TABLE 1: engineer_photo_ai_scores_r2666
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_photo_ai_scores_r2666 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  photo_url text NOT NULL,
  scored_at timestamptz NOT NULL DEFAULT now(),
  ai_quality_score int NOT NULL DEFAULT 0 CHECK (ai_quality_score BETWEEN 0 AND 100),
  blur_detected boolean NOT NULL DEFAULT false,
  patient_data_detected boolean NOT NULL DEFAULT false,
  equipment_visible boolean NOT NULL DEFAULT true,
  suggested_redo boolean NOT NULL DEFAULT false,
  owner_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','needs_redo','rejected')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_epas_r2666_engineer ON public.engineer_photo_ai_scores_r2666(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_epas_r2666_status ON public.engineer_photo_ai_scores_r2666(status);
CREATE INDEX IF NOT EXISTS idx_epas_r2666_scored_at ON public.engineer_photo_ai_scores_r2666(scored_at);
CREATE INDEX IF NOT EXISTS idx_epas_r2666_score ON public.engineer_photo_ai_scores_r2666(ai_quality_score);

ALTER TABLE public.engineer_photo_ai_scores_r2666 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_photo_ai_scores_r2666;
CREATE POLICY founder_all ON public.engineer_photo_ai_scores_r2666
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: photo_ai_action_log_r2666
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.photo_ai_action_log_r2666 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.engineer_photo_ai_scores_r2666(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('approve','redo','redact','reject')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_paal_r2666_photo ON public.photo_ai_action_log_r2666(photo_id);
CREATE INDEX IF NOT EXISTS idx_paal_r2666_status ON public.photo_ai_action_log_r2666(status);
CREATE INDEX IF NOT EXISTS idx_paal_r2666_action_at ON public.photo_ai_action_log_r2666(action_at);

ALTER TABLE public.photo_ai_action_log_r2666 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.photo_ai_action_log_r2666;
CREATE POLICY founder_all ON public.photo_ai_action_log_r2666
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
INSERT INTO public.engineer_photo_ai_scores_r2666
  (photo_url, scored_at, ai_quality_score, blur_detected, patient_data_detected, equipment_visible, suggested_redo, owner_email, status, notes)
VALUES
  ('https://cdn.equipseva.in/photos/job_1001_before.jpg', now() - interval '2 days', 88, false, false, true, false, 'ops@equipseva.in', 'approved', 'Sharp focus on ventilator panel'),
  ('https://cdn.equipseva.in/photos/job_1002_after.jpg', now() - interval '3 days', 42, true, false, true, true, 'ops@equipseva.in', 'needs_redo', 'Heavy motion blur on serial number'),
  ('https://cdn.equipseva.in/photos/job_1003_patient.jpg', now() - interval '4 days', 25, false, true, true, true, 'ops@equipseva.in', 'rejected', 'Patient face visible behind monitor'),
  ('https://cdn.equipseva.in/photos/job_1004_before.jpg', now() - interval '1 days', 73, false, false, true, false, 'ops@equipseva.in', 'pending', 'Slight glare on display'),
  ('https://cdn.equipseva.in/photos/job_1005_after.jpg', now() - interval '12 hours', 91, false, false, true, false, 'ops@equipseva.in', 'approved', 'Clean shot of calibration label');

INSERT INTO public.photo_ai_action_log_r2666
  (photo_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '36 hours', 'approve', 'positive', 'ops@equipseva.in', 'done', 'Approved for invoice attachment'
FROM public.engineer_photo_ai_scores_r2666 WHERE ai_quality_score = 88 LIMIT 1;

INSERT INTO public.photo_ai_action_log_r2666
  (photo_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '60 hours', 'redo', 'neutral', 'ops@equipseva.in', 'open', 'Engineer notified to retake'
FROM public.engineer_photo_ai_scores_r2666 WHERE ai_quality_score = 42 LIMIT 1;

INSERT INTO public.photo_ai_action_log_r2666
  (photo_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '80 hours', 'redact', 'positive', 'ops@equipseva.in', 'done', 'Auto-redacted patient pixels and re-stored'
FROM public.engineer_photo_ai_scores_r2666 WHERE patient_data_detected = true LIMIT 1;

INSERT INTO public.photo_ai_action_log_r2666
  (photo_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '20 hours', 'approve', 'pending', 'ops@equipseva.in', 'open', 'Pending second reviewer'
FROM public.engineer_photo_ai_scores_r2666 WHERE ai_quality_score = 73 LIMIT 1;

INSERT INTO public.photo_ai_action_log_r2666
  (photo_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '6 hours', 'approve', 'positive', 'ops@equipseva.in', 'done', 'Top tier shot; used in marketing carousel'
FROM public.engineer_photo_ai_scores_r2666 WHERE ai_quality_score = 91 LIMIT 1;

-- =========================================================================
-- RPC 1: list_photo_scores_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_photo_scores_r2666();
CREATE FUNCTION public.list_photo_scores_r2666()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  photo_url text,
  scored_at timestamptz,
  ai_quality_score int,
  blur_detected boolean,
  patient_data_detected boolean,
  equipment_visible boolean,
  suggested_redo boolean,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.photo_url, p.scored_at, p.ai_quality_score,
         p.blur_detected, p.patient_data_detected, p.equipment_visible, p.suggested_redo,
         p.owner_email, p.status, p.notes, p.created_at
  FROM public.engineer_photo_ai_scores_r2666 p
  ORDER BY p.scored_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_photo_scores_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photo_scores_r2666() TO authenticated;

-- =========================================================================
-- RPC 2: list_action_log_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_action_log_r2666();
CREATE FUNCTION public.list_action_log_r2666()
RETURNS TABLE (
  id uuid,
  photo_url text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, p.photo_url, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.photo_ai_action_log_r2666 a
  JOIN public.engineer_photo_ai_scores_r2666 p ON p.id = a.photo_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_log_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_log_r2666() TO authenticated;

-- =========================================================================
-- RPC 3: top_low_score_focus_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_low_score_focus_r2666();
CREATE FUNCTION public.top_low_score_focus_r2666()
RETURNS TABLE (
  id uuid,
  photo_url text,
  ai_quality_score int,
  blur_detected boolean,
  patient_data_detected boolean,
  status text,
  owner_email text,
  scored_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.photo_url, p.ai_quality_score, p.blur_detected, p.patient_data_detected,
         p.status, p.owner_email, p.scored_at
  FROM public.engineer_photo_ai_scores_r2666 p
  WHERE p.ai_quality_score <= 60
  ORDER BY p.ai_quality_score ASC, p.scored_at DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_low_score_focus_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_low_score_focus_r2666() TO authenticated;

-- =========================================================================
-- RPC 4: status_funnel_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_funnel_r2666();
CREATE FUNCTION public.status_funnel_r2666()
RETURNS TABLE (
  status text,
  photo_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.status, count(*)::bigint
  FROM public.engineer_photo_ai_scores_r2666 p
  GROUP BY p.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2666() TO authenticated;

-- =========================================================================
-- RPC 5: monthly_score_trend_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.monthly_score_trend_r2666();
CREATE FUNCTION public.monthly_score_trend_r2666()
RETURNS TABLE (
  month_label text,
  total_photos bigint,
  avg_score numeric,
  blur_count bigint,
  patient_data_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', p.scored_at), 'YYYY-MM') AS month_label,
         count(*)::bigint,
         round(coalesce(avg(p.ai_quality_score), 0)::numeric, 2),
         count(*) FILTER (WHERE p.blur_detected)::bigint,
         count(*) FILTER (WHERE p.patient_data_detected)::bigint
  FROM public.engineer_photo_ai_scores_r2666 p
  GROUP BY date_trunc('month', p.scored_at)
  ORDER BY date_trunc('month', p.scored_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_score_trend_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_score_trend_r2666() TO authenticated;

-- =========================================================================
-- RPC 6: blur_rate_summary_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.blur_rate_summary_r2666();
CREATE FUNCTION public.blur_rate_summary_r2666()
RETURNS TABLE (
  total_photos bigint,
  blur_photos bigint,
  blur_pct numeric,
  patient_data_photos bigint,
  patient_data_pct numeric,
  suggested_redo_photos bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE p.blur_detected)::bigint,
    CASE WHEN count(*) = 0 THEN 0
         ELSE round(100.0 * count(*) FILTER (WHERE p.blur_detected) / count(*)::numeric, 2)
    END,
    count(*) FILTER (WHERE p.patient_data_detected)::bigint,
    CASE WHEN count(*) = 0 THEN 0
         ELSE round(100.0 * count(*) FILTER (WHERE p.patient_data_detected) / count(*)::numeric, 2)
    END,
    count(*) FILTER (WHERE p.suggested_redo)::bigint
  FROM public.engineer_photo_ai_scores_r2666 p;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.blur_rate_summary_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blur_rate_summary_r2666() TO authenticated;

-- =========================================================================
-- RPC 7: owner_load_r2666
-- =========================================================================
DROP FUNCTION IF EXISTS public.owner_load_r2666();
CREATE FUNCTION public.owner_load_r2666()
RETURNS TABLE (
  owner_email text,
  total_photos bigint,
  pending_photos bigint,
  redo_photos bigint,
  rejected_photos bigint,
  approved_photos bigint,
  avg_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(p.owner_email, 'unassigned') AS owner_email,
         count(*)::bigint,
         count(*) FILTER (WHERE p.status = 'pending')::bigint,
         count(*) FILTER (WHERE p.status = 'needs_redo')::bigint,
         count(*) FILTER (WHERE p.status = 'rejected')::bigint,
         count(*) FILTER (WHERE p.status = 'approved')::bigint,
         round(coalesce(avg(p.ai_quality_score), 0)::numeric, 2)
  FROM public.engineer_photo_ai_scores_r2666 p
  GROUP BY coalesce(p.owner_email, 'unassigned')
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2666() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2666() TO authenticated;

COMMIT;
