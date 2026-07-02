-- Round 2494: engineer-photo-quality-evidence-audit
-- Founder-only audit of engineer job photo evidence quality + coaching follow-up

BEGIN;

-- ============================================================
-- Table 1: engineer_job_photo_audits_r2494
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_job_photo_audits_r2494 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  job_external_ref text NOT NULL,
  audit_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  total_photos int NOT NULL DEFAULT 0 CHECK (total_photos >= 0),
  required_photo_count int NOT NULL DEFAULT 0 CHECK (required_photo_count >= 0),
  photo_quality_score int NOT NULL DEFAULT 0 CHECK (photo_quality_score BETWEEN 0 AND 100),
  evidence_completeness_pct int NOT NULL DEFAULT 0 CHECK (evidence_completeness_pct BETWEEN 0 AND 100),
  insurance_legal_grade text NOT NULL DEFAULT 'marginal' CHECK (insurance_legal_grade IN ('yes','marginal','no')),
  top_gap text,
  coaching_required boolean NOT NULL DEFAULT false,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','coached','passed','escalated')),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_eng_photo_audits_r2494_eng
  ON public.engineer_job_photo_audits_r2494(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_photo_audits_r2494_date
  ON public.engineer_job_photo_audits_r2494(audit_date);
CREATE INDEX IF NOT EXISTS idx_eng_photo_audits_r2494_status
  ON public.engineer_job_photo_audits_r2494(status);

ALTER TABLE public.engineer_job_photo_audits_r2494 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_job_photo_audits_r2494;
CREATE POLICY founder_all ON public.engineer_job_photo_audits_r2494
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: photo_audit_coaching_sessions_r2494
-- ============================================================
CREATE TABLE IF NOT EXISTS public.photo_audit_coaching_sessions_r2494 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_id uuid NOT NULL REFERENCES public.engineer_job_photo_audits_r2494(id) ON DELETE CASCADE,
  session_at timestamptz NOT NULL DEFAULT now(),
  coach_email text,
  focus_md text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_photo_audit_coaching_r2494_audit
  ON public.photo_audit_coaching_sessions_r2494(audit_id);
CREATE INDEX IF NOT EXISTS idx_photo_audit_coaching_r2494_session_at
  ON public.photo_audit_coaching_sessions_r2494(session_at);

ALTER TABLE public.photo_audit_coaching_sessions_r2494 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.photo_audit_coaching_sessions_r2494;
CREATE POLICY founder_all ON public.photo_audit_coaching_sessions_r2494
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC: list_audits_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_audits_r2494()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_tier text,
  job_external_ref text,
  audit_date date,
  total_photos int,
  required_photo_count int,
  photo_quality_score int,
  evidence_completeness_pct int,
  insurance_legal_grade text,
  top_gap text,
  coaching_required boolean,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id,
         e.cached_highest_tier::text,
         a.job_external_ref, a.audit_date,
         a.total_photos, a.required_photo_count,
         a.photo_quality_score, a.evidence_completeness_pct,
         a.insurance_legal_grade, a.top_gap,
         a.coaching_required, a.owner_email, a.status, a.notes, a.created_at
  FROM public.engineer_job_photo_audits_r2494 a
  LEFT JOIN public.engineers e ON e.id = a.engineer_user_id
  ORDER BY a.audit_date DESC, a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_audits_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2494() TO authenticated;

-- ============================================================
-- RPC: list_coaching_sessions_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_coaching_sessions_r2494()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  job_external_ref text,
  engineer_user_id uuid,
  session_at timestamptz,
  coach_email text,
  focus_md text,
  outcome text,
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.audit_id,
         a.job_external_ref, a.engineer_user_id,
         s.session_at, s.coach_email, s.focus_md, s.outcome,
         s.follow_up_at, s.notes, s.created_at
  FROM public.photo_audit_coaching_sessions_r2494 s
  LEFT JOIN public.engineer_job_photo_audits_r2494 a ON a.id = s.audit_id
  ORDER BY s.session_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_coaching_sessions_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_sessions_r2494() TO authenticated;

-- ============================================================
-- RPC: low_quality_audits_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.low_quality_audits_r2494()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  job_external_ref text,
  audit_date date,
  photo_quality_score int,
  evidence_completeness_pct int,
  insurance_legal_grade text,
  top_gap text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, a.job_external_ref, a.audit_date,
         a.photo_quality_score, a.evidence_completeness_pct,
         a.insurance_legal_grade, a.top_gap, a.status
  FROM public.engineer_job_photo_audits_r2494 a
  WHERE a.photo_quality_score < 70
     OR a.evidence_completeness_pct < 70
     OR a.insurance_legal_grade = 'no'
  ORDER BY a.photo_quality_score ASC, a.evidence_completeness_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.low_quality_audits_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_quality_audits_r2494() TO authenticated;

-- ============================================================
-- RPC: top_coaching_engineers_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_coaching_engineers_r2494()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_tier text,
  audits int,
  coaching_required_count int,
  avg_quality numeric,
  avg_completeness numeric,
  insurance_no_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_user_id,
         MAX(e.cached_highest_tier::text) AS engineer_tier,
         COUNT(*)::int AS audits,
         SUM(CASE WHEN a.coaching_required THEN 1 ELSE 0 END)::int AS coaching_required_count,
         ROUND(AVG(a.photo_quality_score)::numeric, 1) AS avg_quality,
         ROUND(AVG(a.evidence_completeness_pct)::numeric, 1) AS avg_completeness,
         SUM(CASE WHEN a.insurance_legal_grade = 'no' THEN 1 ELSE 0 END)::int AS insurance_no_count
  FROM public.engineer_job_photo_audits_r2494 a
  LEFT JOIN public.engineers e ON e.id = a.engineer_user_id
  GROUP BY a.engineer_user_id
  ORDER BY coaching_required_count DESC, avg_quality ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_coaching_engineers_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_coaching_engineers_r2494() TO authenticated;

-- ============================================================
-- RPC: weekly_completeness_trend_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.weekly_completeness_trend_r2494()
RETURNS TABLE (
  week_start date,
  audits int,
  avg_quality numeric,
  avg_completeness numeric,
  insurance_yes_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', a.audit_date)::date AS week_start,
         COUNT(*)::int AS audits,
         ROUND(AVG(a.photo_quality_score)::numeric, 1) AS avg_quality,
         ROUND(AVG(a.evidence_completeness_pct)::numeric, 1) AS avg_completeness,
         ROUND(
           100.0 * SUM(CASE WHEN a.insurance_legal_grade = 'yes' THEN 1 ELSE 0 END)::numeric
                 / NULLIF(COUNT(*), 0)::numeric,
           1
         ) AS insurance_yes_pct
  FROM public.engineer_job_photo_audits_r2494 a
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_completeness_trend_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_completeness_trend_r2494() TO authenticated;

-- ============================================================
-- RPC: insurance_grade_summary_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.insurance_grade_summary_r2494()
RETURNS TABLE (
  insurance_legal_grade text,
  audits int,
  avg_quality numeric,
  avg_completeness numeric,
  escalated_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.insurance_legal_grade,
         COUNT(*)::int AS audits,
         ROUND(AVG(a.photo_quality_score)::numeric, 1) AS avg_quality,
         ROUND(AVG(a.evidence_completeness_pct)::numeric, 1) AS avg_completeness,
         SUM(CASE WHEN a.status = 'escalated' THEN 1 ELSE 0 END)::int AS escalated_count
  FROM public.engineer_job_photo_audits_r2494 a
  GROUP BY a.insurance_legal_grade
  ORDER BY a.insurance_legal_grade;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.insurance_grade_summary_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.insurance_grade_summary_r2494() TO authenticated;

-- ============================================================
-- RPC: owner_load_r2494
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2494()
RETURNS TABLE (
  owner_email text,
  open_audits int,
  coaching_required_count int,
  escalated_count int,
  avg_quality numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, '(unassigned)') AS owner_email,
         SUM(CASE WHEN a.status = 'open' THEN 1 ELSE 0 END)::int AS open_audits,
         SUM(CASE WHEN a.coaching_required THEN 1 ELSE 0 END)::int AS coaching_required_count,
         SUM(CASE WHEN a.status = 'escalated' THEN 1 ELSE 0 END)::int AS escalated_count,
         ROUND(AVG(a.photo_quality_score)::numeric, 1) AS avg_quality
  FROM public.engineer_job_photo_audits_r2494 a
  GROUP BY COALESCE(a.owner_email, '(unassigned)')
  ORDER BY open_audits DESC, escalated_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2494() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2494() TO authenticated;

-- ============================================================
-- Seed data
-- ============================================================
DO $seed$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_eng_c uuid;
  v_audit_1 uuid;
  v_audit_2 uuid;
  v_audit_3 uuid;
  v_audit_4 uuid;
  v_audit_5 uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.engineers ORDER BY created_at ASC OFFSET 0 LIMIT 1;
  SELECT id INTO v_eng_b FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng_c FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;
  IF v_eng_b IS NULL THEN v_eng_b := v_eng_a; END IF;
  IF v_eng_c IS NULL THEN v_eng_c := v_eng_a; END IF;

  IF v_eng_a IS NOT NULL THEN
    INSERT INTO public.engineer_job_photo_audits_r2494
      (engineer_user_id, job_external_ref, audit_date, total_photos, required_photo_count,
       photo_quality_score, evidence_completeness_pct, insurance_legal_grade, top_gap,
       coaching_required, owner_email, status, notes)
    VALUES (v_eng_a, 'JOB-IMG-9001', current_date - 2, 12, 12, 88, 95, 'yes',
            'minor blur on serial plate', false, 'qa@equipseva.com', 'passed',
            'clean evidence pack; flagged for case study')
    RETURNING id INTO v_audit_1;

    INSERT INTO public.engineer_job_photo_audits_r2494
      (engineer_user_id, job_external_ref, audit_date, total_photos, required_photo_count,
       photo_quality_score, evidence_completeness_pct, insurance_legal_grade, top_gap,
       coaching_required, owner_email, status, notes)
    VALUES (v_eng_b, 'JOB-IMG-9002', current_date - 1, 6, 12, 52, 58, 'no',
            'missing before/after pair on PCB swap', true, 'qa@equipseva.com', 'open',
            'insurance claim would fail; immediate coach')
    RETURNING id INTO v_audit_2;

    INSERT INTO public.engineer_job_photo_audits_r2494
      (engineer_user_id, job_external_ref, audit_date, total_photos, required_photo_count,
       photo_quality_score, evidence_completeness_pct, insurance_legal_grade, top_gap,
       coaching_required, owner_email, status, notes)
    VALUES (v_eng_c, 'JOB-IMG-9003', current_date - 7, 9, 12, 68, 72, 'marginal',
            'low light on equipment ID tag', true, 'ops@equipseva.com', 'coached',
            'coached on tag lighting + macro mode')
    RETURNING id INTO v_audit_3;

    INSERT INTO public.engineer_job_photo_audits_r2494
      (engineer_user_id, job_external_ref, audit_date, total_photos, required_photo_count,
       photo_quality_score, evidence_completeness_pct, insurance_legal_grade, top_gap,
       coaching_required, owner_email, status, notes)
    VALUES (v_eng_a, 'JOB-IMG-9004', current_date - 10, 14, 12, 92, 100, 'yes',
            NULL, false, 'qa@equipseva.com', 'passed',
            'gold-standard evidence; reference example')
    RETURNING id INTO v_audit_4;

    INSERT INTO public.engineer_job_photo_audits_r2494
      (engineer_user_id, job_external_ref, audit_date, total_photos, required_photo_count,
       photo_quality_score, evidence_completeness_pct, insurance_legal_grade, top_gap,
       coaching_required, owner_email, status, notes)
    VALUES (v_eng_b, 'JOB-IMG-9005', current_date - 14, 4, 12, 41, 45, 'no',
            'no part box + serial photo', true, 'ops@equipseva.com', 'escalated',
            'second incident this month; tier hold')
    RETURNING id INTO v_audit_5;

    INSERT INTO public.photo_audit_coaching_sessions_r2494
      (audit_id, session_at, coach_email, focus_md, outcome, follow_up_at, notes)
    VALUES (v_audit_2, now() - interval '1 day', 'coach@equipseva.com',
            '- before/after pair discipline\n- part-box serial capture',
            'positive', now() + interval '7 days', 'engineer receptive; demo replays ok');

    INSERT INTO public.photo_audit_coaching_sessions_r2494
      (audit_id, session_at, coach_email, focus_md, outcome, follow_up_at, notes)
    VALUES (v_audit_3, now() - interval '6 days', 'coach@equipseva.com',
            '- macro mode for ID tags\n- portable light usage',
            'neutral', now() + interval '14 days', 'follow-up audit pending');

    INSERT INTO public.photo_audit_coaching_sessions_r2494
      (audit_id, session_at, coach_email, focus_md, outcome, follow_up_at, notes)
    VALUES (v_audit_5, now() - interval '12 days', 'coach@equipseva.com',
            '- mandatory 12-photo checklist enforcement',
            'negative', now() + interval '3 days', 'still missing photos on next job; tier hold continues');
  END IF;
END
$seed$;

