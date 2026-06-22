BEGIN;

-- ============================================================================
-- Round 2302: Engineer competency-test pass-rate dashboard
-- Periodic tests by topic; pass rate; gap -> training assignment
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_competency_tests_r2302 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text,
  topic text NOT NULL CHECK (topic IN ('electrical_safety','biomedical_basics','imaging_xray','imaging_ct','imaging_mri','ultrasound','ventilator','dialysis','anesthesia','sterilization','calibration','nabh_compliance','customer_handling','tool_proficiency','sop_adherence','triage_diagnosis','escalation_protocol')),
  test_cycle text NOT NULL CHECK (test_cycle IN ('quarterly_q1','quarterly_q2','quarterly_q3','quarterly_q4','onboarding','remedial','annual')),
  test_taken_at timestamptz NOT NULL DEFAULT now(),
  questions_total integer NOT NULL CHECK (questions_total > 0),
  questions_correct integer NOT NULL CHECK (questions_correct >= 0),
  score_pct numeric NOT NULL CHECK (score_pct >= 0 AND score_pct <= 100),
  pass_threshold_pct numeric NOT NULL DEFAULT 70 CHECK (pass_threshold_pct >= 0 AND pass_threshold_pct <= 100),
  result text NOT NULL CHECK (result IN ('pass','fail','marginal','retake_required')),
  attempt_number integer NOT NULL DEFAULT 1 CHECK (attempt_number >= 1),
  duration_minutes integer CHECK (duration_minutes IS NULL OR duration_minutes >= 0),
  weak_areas jsonb NOT NULL DEFAULT '[]'::jsonb,
  proctor_notes text,
  certification_eligible boolean NOT NULL DEFAULT false,
  region text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ect_r2302_engineer ON public.engineer_competency_tests_r2302(engineer_id, test_taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_ect_r2302_topic ON public.engineer_competency_tests_r2302(topic);
CREATE INDEX IF NOT EXISTS idx_ect_r2302_result ON public.engineer_competency_tests_r2302(result);
CREATE INDEX IF NOT EXISTS idx_ect_r2302_cycle ON public.engineer_competency_tests_r2302(test_cycle);
CREATE INDEX IF NOT EXISTS idx_ect_r2302_taken ON public.engineer_competency_tests_r2302(test_taken_at DESC);

ALTER TABLE public.engineer_competency_tests_r2302 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ect_r2302 ON public.engineer_competency_tests_r2302;
CREATE POLICY founder_all_ect_r2302 ON public.engineer_competency_tests_r2302
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_training_assignments_r2302 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source_test_id uuid REFERENCES public.engineer_competency_tests_r2302(id) ON DELETE SET NULL,
  topic text NOT NULL,
  training_module text NOT NULL,
  reason text NOT NULL CHECK (reason IN ('failed_test','marginal_score','weak_area','remedial','onboarding','annual_refresh','manual')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('critical','high','medium','low')),
  status text NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned','in_progress','completed','overdue','waived','cancelled')),
  due_date date,
  completed_at timestamptz,
  retake_test_id uuid REFERENCES public.engineer_competency_tests_r2302(id) ON DELETE SET NULL,
  assigned_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eta_r2302_engineer ON public.engineer_training_assignments_r2302(engineer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eta_r2302_status ON public.engineer_training_assignments_r2302(status);
CREATE INDEX IF NOT EXISTS idx_eta_r2302_topic ON public.engineer_training_assignments_r2302(topic);
CREATE INDEX IF NOT EXISTS idx_eta_r2302_priority ON public.engineer_training_assignments_r2302(priority);
CREATE INDEX IF NOT EXISTS idx_eta_r2302_due ON public.engineer_training_assignments_r2302(due_date);

ALTER TABLE public.engineer_training_assignments_r2302 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eta_r2302 ON public.engineer_training_assignments_r2302;
CREATE POLICY founder_all_eta_r2302 ON public.engineer_training_assignments_r2302
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7, all founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r2302_summary_stats()
RETURNS TABLE (
  total_tests integer,
  total_engineers_tested integer,
  passed_count integer,
  failed_count integer,
  marginal_count integer,
  overall_pass_rate_pct numeric,
  avg_score_pct numeric,
  open_training_assignments integer,
  overdue_assignments integer,
  last_90d_tests integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total integer;
  v_pass integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::integer, COUNT(*) FILTER (WHERE result = 'pass')::integer
    INTO v_total, v_pass
  FROM public.engineer_competency_tests_r2302;

  RETURN QUERY
  SELECT
    v_total,
    (SELECT COUNT(DISTINCT engineer_id)::integer FROM public.engineer_competency_tests_r2302),
    v_pass,
    (SELECT COUNT(*)::integer FROM public.engineer_competency_tests_r2302 WHERE result = 'fail'),
    (SELECT COUNT(*)::integer FROM public.engineer_competency_tests_r2302 WHERE result = 'marginal'),
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND((v_pass::numeric / v_total::numeric) * 100, 1) END,
    COALESCE((SELECT ROUND(AVG(score_pct), 1) FROM public.engineer_competency_tests_r2302), 0)::numeric,
    (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 WHERE status IN ('assigned','in_progress')),
    (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 WHERE status = 'overdue' OR (status IN ('assigned','in_progress') AND due_date IS NOT NULL AND due_date < CURRENT_DATE)),
    (SELECT COUNT(*)::integer FROM public.engineer_competency_tests_r2302 WHERE test_taken_at >= now() - interval '90 days');
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_pass_rate_by_topic()
RETURNS TABLE (
  topic text,
  total_tests integer,
  passed integer,
  failed integer,
  marginal integer,
  pass_rate_pct numeric,
  avg_score_pct numeric,
  open_assignments integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic,
         COUNT(*)::integer AS total_tests,
         COUNT(*) FILTER (WHERE t.result = 'pass')::integer AS passed,
         COUNT(*) FILTER (WHERE t.result = 'fail')::integer AS failed,
         COUNT(*) FILTER (WHERE t.result = 'marginal')::integer AS marginal,
         CASE WHEN COUNT(*) = 0 THEN 0::numeric
              ELSE ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / COUNT(*)::numeric) * 100, 1) END,
         ROUND(AVG(t.score_pct), 1)::numeric,
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.topic = t.topic AND a.status IN ('assigned','in_progress','overdue'))
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.topic
  ORDER BY pass_rate_pct ASC, total_tests DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_recent_tests(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  topic text,
  test_cycle text,
  test_taken_at timestamptz,
  score_pct numeric,
  pass_threshold_pct numeric,
  result text,
  attempt_number integer,
  region text,
  certification_eligible boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_id, t.engineer_name, t.topic, t.test_cycle,
         t.test_taken_at, t.score_pct, t.pass_threshold_pct, t.result,
         t.attempt_number, t.region, t.certification_eligible
  FROM public.engineer_competency_tests_r2302 t
  ORDER BY t.test_taken_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_engineer_leaderboard()
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  tests_taken integer,
  passed integer,
  failed integer,
  avg_score_pct numeric,
  pass_rate_pct numeric,
  last_test_at timestamptz,
  open_assignments integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_id,
         MAX(t.engineer_name) AS engineer_name,
         COUNT(*)::integer AS tests_taken,
         COUNT(*) FILTER (WHERE t.result = 'pass')::integer,
         COUNT(*) FILTER (WHERE t.result = 'fail')::integer,
         ROUND(AVG(t.score_pct), 1)::numeric,
         CASE WHEN COUNT(*) = 0 THEN 0::numeric
              ELSE ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / COUNT(*)::numeric) * 100, 1) END,
         MAX(t.test_taken_at),
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.engineer_id = t.engineer_id AND a.status IN ('assigned','in_progress','overdue'))
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.engineer_id
  ORDER BY pass_rate_pct ASC, tests_taken DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_open_training_assignments()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  topic text,
  training_module text,
  reason text,
  priority text,
  status text,
  due_date date,
  days_until_due integer,
  is_overdue boolean,
  assigned_by_email text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_id, a.topic, a.training_module, a.reason,
         a.priority, a.status, a.due_date,
         CASE WHEN a.due_date IS NULL THEN NULL
              ELSE (a.due_date - CURRENT_DATE)::integer END,
         (a.due_date IS NOT NULL AND a.due_date < CURRENT_DATE AND a.status IN ('assigned','in_progress')),
         a.assigned_by_email, a.created_at
  FROM public.engineer_training_assignments_r2302 a
  WHERE a.status IN ('assigned','in_progress','overdue')
  ORDER BY
    CASE a.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    a.due_date NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_assign_training(
  p_engineer_id uuid,
  p_topic text,
  p_training_module text,
  p_reason text,
  p_priority text DEFAULT 'medium',
  p_due_date date DEFAULT NULL,
  p_source_test_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_reason NOT IN ('failed_test','marginal_score','weak_area','remedial','onboarding','annual_refresh','manual') THEN
    RAISE EXCEPTION 'invalid_reason';
  END IF;
  IF p_priority NOT IN ('critical','high','medium','low') THEN
    RAISE EXCEPTION 'invalid_priority';
  END IF;

  v_email := auth.jwt()->>'email';

  INSERT INTO public.engineer_training_assignments_r2302
    (engineer_id, source_test_id, topic, training_module, reason, priority, due_date, assigned_by_email, notes)
  VALUES
    (p_engineer_id, p_source_test_id, p_topic, p_training_module, p_reason, p_priority, p_due_date, v_email, p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2302_topic_gap_alerts(p_min_tests integer DEFAULT 3, p_max_pass_rate numeric DEFAULT 70)
RETURNS TABLE (
  topic text,
  total_tests integer,
  pass_rate_pct numeric,
  avg_score_pct numeric,
  open_assignments integer,
  recommended_action text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic,
         COUNT(*)::integer,
         ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1)::numeric,
         ROUND(AVG(t.score_pct), 1)::numeric,
         (SELECT COUNT(*)::integer FROM public.engineer_training_assignments_r2302 a
           WHERE a.topic = t.topic AND a.status IN ('assigned','in_progress','overdue')),
         CASE
           WHEN ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) < 50
             THEN 'urgent_cohort_retraining'
           WHEN ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) < 65
             THEN 'targeted_remedial_module'
           ELSE 'monitor'
         END
  FROM public.engineer_competency_tests_r2302 t
  GROUP BY t.topic
  HAVING COUNT(*) >= GREATEST(p_min_tests, 1)
     AND ROUND((COUNT(*) FILTER (WHERE t.result = 'pass')::numeric / NULLIF(COUNT(*), 0)::numeric) * 100, 1) <= p_max_pass_rate
  ORDER BY pass_rate_pct ASC;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE ALL ON FUNCTION public.r2302_summary_stats() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_pass_rate_by_topic() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_recent_tests(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_engineer_leaderboard() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_open_training_assignments() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_assign_training(uuid, text, text, text, text, date, uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2302_topic_gap_alerts(integer, numeric) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2302_summary_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_pass_rate_by_topic() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_recent_tests(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_engineer_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_open_training_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_assign_training(uuid, text, text, text, text, date, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2302_topic_gap_alerts(integer, numeric) TO authenticated;

COMMIT;
