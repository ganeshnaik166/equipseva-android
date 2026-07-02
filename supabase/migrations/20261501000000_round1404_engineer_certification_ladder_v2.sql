BEGIN;
-- Round 1404 — Engineer certification ladder v2 (proctored exam infra)
-- 2 tables + 7 RPCs + RLS



-- =========================================================================
-- Table 1: engineer_certification_exams (exam catalog)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_certification_exams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_label text NOT NULL UNIQUE,
  exam_kind text NOT NULL CHECK (exam_kind IN (
    'foundation','tier_pro','specialty_radiology','specialty_dental',
    'specialty_lab_diagnostics','equipment_specific'
  )),
  passing_score_pct numeric NOT NULL DEFAULT 70 CHECK (passing_score_pct BETWEEN 0 AND 100),
  total_questions int NOT NULL DEFAULT 50 CHECK (total_questions > 0),
  time_limit_minutes int NOT NULL DEFAULT 60 CHECK (time_limit_minutes > 0),
  is_proctored boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','sunset')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_cert_exams_status ON public.engineer_certification_exams(status);
CREATE INDEX IF NOT EXISTS idx_eng_cert_exams_kind ON public.engineer_certification_exams(exam_kind);

ALTER TABLE public.engineer_certification_exams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_cert_exams_founder_all ON public.engineer_certification_exams;
CREATE POLICY eng_cert_exams_founder_all ON public.engineer_certification_exams
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eng_cert_exams_authenticated_read ON public.engineer_certification_exams;
CREATE POLICY eng_cert_exams_authenticated_read ON public.engineer_certification_exams
  FOR SELECT TO authenticated USING (status = 'active');

-- =========================================================================
-- Table 2: engineer_certification_attempts
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_certification_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exam_id uuid NOT NULL REFERENCES public.engineer_certification_exams(id) ON DELETE RESTRICT,
  attempt_status text NOT NULL DEFAULT 'scheduled' CHECK (attempt_status IN (
    'scheduled','in_progress','submitted','passed','failed','cancelled','disqualified'
  )),
  score_pct numeric CHECK (score_pct IS NULL OR score_pct BETWEEN 0 AND 100),
  score_correct int CHECK (score_correct IS NULL OR score_correct >= 0),
  score_total int CHECK (score_total IS NULL OR score_total >= 0),
  started_at timestamptz,
  submitted_at timestamptz,
  evaluated_at timestamptz,
  proctor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  integrity_flags jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_cert_attempts_engineer ON public.engineer_certification_attempts(engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng_cert_attempts_exam ON public.engineer_certification_attempts(exam_id);
CREATE INDEX IF NOT EXISTS idx_eng_cert_attempts_status ON public.engineer_certification_attempts(attempt_status);
CREATE INDEX IF NOT EXISTS idx_eng_cert_attempts_created ON public.engineer_certification_attempts(created_at DESC);

ALTER TABLE public.engineer_certification_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_cert_attempts_founder_all ON public.engineer_certification_attempts;
CREATE POLICY eng_cert_attempts_founder_all ON public.engineer_certification_attempts
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eng_cert_attempts_engineer_own ON public.engineer_certification_attempts;
CREATE POLICY eng_cert_attempts_engineer_own ON public.engineer_certification_attempts
  FOR SELECT TO authenticated USING (engineer_user_id = auth.uid());

-- =========================================================================
-- RPC 1: founder_engineer_cert_v2_summary (16 KPIs)
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_cert_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_cert_v2_summary()
RETURNS TABLE (
  total_exams int,
  active_exams int,
  draft_exams int,
  sunset_exams int,
  proctored_exams int,
  total_attempts int,
  attempts_scheduled int,
  attempts_in_progress int,
  attempts_submitted int,
  attempts_passed int,
  attempts_failed int,
  attempts_disqualified int,
  pass_rate_pct numeric,
  avg_score_pct numeric,
  unique_candidates int,
  attempts_30d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_certification_exams),
    (SELECT COUNT(*)::int FROM public.engineer_certification_exams WHERE status='active'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_exams WHERE status='draft'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_exams WHERE status='sunset'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_exams WHERE is_proctored=true),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='scheduled'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='in_progress'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='submitted'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='passed'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='failed'),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE attempt_status='disqualified'),
    COALESCE(ROUND(
      100.0 * (SELECT COUNT(*) FROM public.engineer_certification_attempts WHERE attempt_status='passed')::numeric
      / NULLIF((SELECT COUNT(*) FROM public.engineer_certification_attempts WHERE attempt_status IN ('passed','failed')), 0)
    , 2), 0),
    COALESCE((SELECT ROUND(AVG(score_pct)::numeric, 2) FROM public.engineer_certification_attempts WHERE score_pct IS NOT NULL), 0),
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM public.engineer_certification_attempts),
    (SELECT COUNT(*)::int FROM public.engineer_certification_attempts WHERE created_at >= now() - interval '30 days');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_cert_v2_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_cert_v2_summary() TO authenticated;

-- =========================================================================
-- RPC 2: founder_engineer_cert_v2_attempts_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_cert_v2_attempts_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_cert_v2_attempts_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  attempt_id uuid,
  engineer_user_id uuid,
  exam_label text,
  exam_kind text,
  attempt_status text,
  score_pct numeric,
  is_proctored boolean,
  started_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, e.exam_label, e.exam_kind, a.attempt_status,
         a.score_pct, e.is_proctored, a.started_at, a.submitted_at, a.created_at
  FROM public.engineer_certification_attempts a
  JOIN public.engineer_certification_exams e ON e.id = a.exam_id
  ORDER BY a.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_cert_v2_attempts_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_cert_v2_attempts_recent(int) TO authenticated;

-- =========================================================================
-- RPC 3: founder_engineer_cert_v2_exams_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_cert_v2_exams_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_cert_v2_exams_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  exam_id uuid,
  exam_label text,
  exam_kind text,
  passing_score_pct numeric,
  total_questions int,
  time_limit_minutes int,
  is_proctored boolean,
  status text,
  attempts_count int,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT e.id, e.exam_label, e.exam_kind, e.passing_score_pct, e.total_questions,
         e.time_limit_minutes, e.is_proctored, e.status,
         (SELECT COUNT(*)::int FROM public.engineer_certification_attempts a WHERE a.exam_id = e.id),
         e.created_at
  FROM public.engineer_certification_exams e
  ORDER BY e.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_cert_v2_exams_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_cert_v2_exams_recent(int) TO authenticated;

-- =========================================================================
-- RPC 4: engineer_cert_v2_my_attempts (engineer self-view)
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_cert_v2_my_attempts(int);
CREATE OR REPLACE FUNCTION public.engineer_cert_v2_my_attempts(p_limit int DEFAULT 20)
RETURNS TABLE (
  attempt_id uuid,
  exam_label text,
  exam_kind text,
  attempt_status text,
  score_pct numeric,
  passing_score_pct numeric,
  is_proctored boolean,
  started_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, e.exam_label, e.exam_kind, a.attempt_status, a.score_pct,
         e.passing_score_pct, e.is_proctored, a.started_at, a.submitted_at, a.created_at
  FROM public.engineer_certification_attempts a
  JOIN public.engineer_certification_exams e ON e.id = a.exam_id
  WHERE a.engineer_user_id = auth.uid()
  ORDER BY a.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_cert_v2_my_attempts(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_cert_v2_my_attempts(int) TO authenticated;

-- =========================================================================
-- RPC 5: engineer_cert_v2_register_attempt (engineer self-register)
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_cert_v2_register_attempt(uuid);
CREATE OR REPLACE FUNCTION public.engineer_cert_v2_register_attempt(p_exam_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempt_id uuid;
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT status INTO v_status FROM public.engineer_certification_exams WHERE id = p_exam_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'exam not found' USING ERRCODE = '22023';
  END IF;
  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'exam not active' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.engineer_certification_attempts (engineer_user_id, exam_id, attempt_status)
  VALUES (auth.uid(), p_exam_id, 'scheduled')
  RETURNING id INTO v_attempt_id;
  RETURN v_attempt_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_cert_v2_register_attempt(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_cert_v2_register_attempt(uuid) TO authenticated;

-- =========================================================================
-- RPC 6: log_founder_cert_v2_register_exam (founder writes exam catalog row)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_cert_v2_register_exam(text, text, numeric, int, int, boolean, text);
CREATE OR REPLACE FUNCTION public.log_founder_cert_v2_register_exam(
  p_exam_label text,
  p_exam_kind text,
  p_passing_score_pct numeric DEFAULT 70,
  p_total_questions int DEFAULT 50,
  p_time_limit_minutes int DEFAULT 60,
  p_is_proctored boolean DEFAULT false,
  p_status text DEFAULT 'draft'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_exam_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.engineer_certification_exams (
    exam_label, exam_kind, passing_score_pct, total_questions,
    time_limit_minutes, is_proctored, status
  )
  VALUES (
    p_exam_label, p_exam_kind, p_passing_score_pct, p_total_questions,
    p_time_limit_minutes, p_is_proctored, p_status
  )
  RETURNING id INTO v_exam_id;
  RETURN v_exam_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cert_v2_register_exam(text, text, numeric, int, int, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cert_v2_register_exam(text, text, numeric, int, int, boolean, text) TO authenticated;

-- =========================================================================
-- RPC 7: log_founder_cert_v2_record_attempt_result (founder writes result)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_cert_v2_record_attempt_result(uuid, text, numeric, int, int, jsonb);
CREATE OR REPLACE FUNCTION public.log_founder_cert_v2_record_attempt_result(
  p_attempt_id uuid,
  p_attempt_status text,
  p_score_pct numeric DEFAULT NULL,
  p_score_correct int DEFAULT NULL,
  p_score_total int DEFAULT NULL,
  p_integrity_flags jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_attempt_status NOT IN ('scheduled','in_progress','submitted','passed','failed','cancelled','disqualified') THEN
    RAISE EXCEPTION 'invalid attempt_status' USING ERRCODE = '22023';
  END IF;
  UPDATE public.engineer_certification_attempts
  SET attempt_status = p_attempt_status,
      score_pct = COALESCE(p_score_pct, score_pct),
      score_correct = COALESCE(p_score_correct, score_correct),
      score_total = COALESCE(p_score_total, score_total),
      integrity_flags = COALESCE(p_integrity_flags, integrity_flags),
      evaluated_at = CASE WHEN p_attempt_status IN ('passed','failed','disqualified') THEN now() ELSE evaluated_at END,
      submitted_at = CASE WHEN p_attempt_status = 'submitted' AND submitted_at IS NULL THEN now() ELSE submitted_at END
  WHERE id = p_attempt_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt not found' USING ERRCODE = '22023';
  END IF;
  RETURN p_attempt_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cert_v2_record_attempt_result(uuid, text, numeric, int, int, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cert_v2_record_attempt_result(uuid, text, numeric, int, int, jsonb) TO authenticated;

COMMIT;