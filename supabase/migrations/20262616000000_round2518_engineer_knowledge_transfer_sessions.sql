-- Round 2518: Engineer Knowledge Transfer Sessions
-- Senior-to-junior knowledge transfer sessions with per-junior pre/post assessments.

CREATE TABLE IF NOT EXISTS public.engineer_kt_sessions_r2518 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  senior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  junior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 60 CHECK (duration_minutes >= 0),
  topic_kind text NOT NULL DEFAULT 'equipment'
    CHECK (topic_kind IN ('equipment','process','safety','customer','tools','career')),
  topic_summary text NOT NULL,
  attendance_score int NOT NULL DEFAULT 0 CHECK (attendance_score BETWEEN 0 AND 100),
  juniors_attended int NOT NULL DEFAULT 1 CHECK (juniors_attended >= 0),
  feedback_score int NOT NULL DEFAULT 0 CHECK (feedback_score BETWEEN 0 AND 10),
  knowledge_gain_assessment text NOT NULL DEFAULT 'partial'
    CHECK (knowledge_gain_assessment IN ('none','partial','strong','transformative')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','done','cancelled','rescheduled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kt_session_assessments_r2518 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.engineer_kt_sessions_r2518(id) ON DELETE CASCADE,
  junior_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  pre_score int NOT NULL DEFAULT 0 CHECK (pre_score BETWEEN 0 AND 100),
  post_score int NOT NULL DEFAULT 0 CHECK (post_score BETWEEN 0 AND 100),
  gain_delta int NOT NULL DEFAULT 0,
  confidence_kind text NOT NULL DEFAULT 'medium'
    CHECK (confidence_kind IN ('low','medium','high','expert')),
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_kt_sessions_r2518 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kt_session_assessments_r2518 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_kt_sessions_r2518;
CREATE POLICY founder_all ON public.engineer_kt_sessions_r2518
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.kt_session_assessments_r2518;
CREATE POLICY founder_all ON public.kt_session_assessments_r2518
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed sessions + per-junior assessments
DO $seed$
DECLARE
  s1 uuid; s2 uuid; s3 uuid; s4 uuid; s5 uuid;
BEGIN
  INSERT INTO public.engineer_kt_sessions_r2518
    (session_at, duration_minutes, topic_kind, topic_summary, attendance_score, juniors_attended, feedback_score, knowledge_gain_assessment, owner_email, status, notes)
  VALUES ('2026-05-06 11:00:00+05:30'::timestamptz, 90, 'equipment', 'Ventilator preventive maintenance checklist — Drager V500', 95, 4, 9, 'strong', 'training@equipseva.in', 'done', 'Hands-on; 4 of 4 juniors completed')
  RETURNING id INTO s1;

  INSERT INTO public.engineer_kt_sessions_r2518
    (session_at, duration_minutes, topic_kind, topic_summary, attendance_score, juniors_attended, feedback_score, knowledge_gain_assessment, owner_email, status, notes)
  VALUES ('2026-05-13 15:30:00+05:30'::timestamptz, 60, 'safety', 'Electrical isolation lockout-tagout procedure for OT equipment', 88, 3, 8, 'partial', 'training@equipseva.in', 'done', 'One junior missed practical demo — schedule follow-up')
  RETURNING id INTO s2;

  INSERT INTO public.engineer_kt_sessions_r2518
    (session_at, duration_minutes, topic_kind, topic_summary, attendance_score, juniors_attended, feedback_score, knowledge_gain_assessment, owner_email, status, notes)
  VALUES ('2026-05-20 10:00:00+05:30'::timestamptz, 75, 'customer', 'De-escalation playbook for hospital admin complaints', 100, 5, 10, 'transformative', 'training@equipseva.in', 'done', 'Role-play heavy; juniors rated session 10/10')
  RETURNING id INTO s3;

  INSERT INTO public.engineer_kt_sessions_r2518
    (session_at, duration_minutes, topic_kind, topic_summary, attendance_score, juniors_attended, feedback_score, knowledge_gain_assessment, owner_email, status, notes)
  VALUES ('2026-06-03 14:00:00+05:30'::timestamptz, 45, 'tools', 'Calibrated multimeter usage + insulation tester walkthrough', 75, 2, 7, 'partial', 'training@equipseva.in', 'done', 'Short session; needs deeper hands-on follow-up')
  RETURNING id INTO s4;

  INSERT INTO public.engineer_kt_sessions_r2518
    (session_at, duration_minutes, topic_kind, topic_summary, attendance_score, juniors_attended, feedback_score, knowledge_gain_assessment, owner_email, status, notes)
  VALUES ('2026-06-15 16:00:00+05:30'::timestamptz, 60, 'career', 'Engineer tier progression — what gold/platinum needs', 90, 4, 9, 'strong', 'training@equipseva.in', 'scheduled', 'Career growth Q&A planned')
  RETURNING id INTO s5;

  -- Assessments
  INSERT INTO public.kt_session_assessments_r2518
    (session_id, pre_score, post_score, gain_delta, confidence_kind, follow_up_required, follow_up_at, notes)
  VALUES (s1, 45, 82, 37, 'high', false, NULL, 'Ventilator PM — junior aced post-test');

  INSERT INTO public.kt_session_assessments_r2518
    (session_id, pre_score, post_score, gain_delta, confidence_kind, follow_up_required, follow_up_at, notes)
  VALUES (s1, 50, 88, 38, 'expert', false, NULL, 'Strong improvement; ready to lead');

  INSERT INTO public.kt_session_assessments_r2518
    (session_id, pre_score, post_score, gain_delta, confidence_kind, follow_up_required, follow_up_at, notes)
  VALUES (s2, 30, 55, 25, 'low', true, '2026-05-25 11:00:00+05:30'::timestamptz, 'Missed practical; needs re-do');

  INSERT INTO public.kt_session_assessments_r2518
    (session_id, pre_score, post_score, gain_delta, confidence_kind, follow_up_required, follow_up_at, notes)
  VALUES (s3, 40, 95, 55, 'expert', false, NULL, 'Transformative — junior leading next role-play');

  INSERT INTO public.kt_session_assessments_r2518
    (session_id, pre_score, post_score, gain_delta, confidence_kind, follow_up_required, follow_up_at, notes)
  VALUES (s4, 55, 70, 15, 'medium', true, '2026-06-18 10:00:00+05:30'::timestamptz, 'Needs deeper multimeter walkthrough');
END $seed$;

-- RPC 1: list_kt_sessions_r2518
CREATE OR REPLACE FUNCTION public.list_kt_sessions_r2518()
RETURNS TABLE (
  id uuid,
  session_at timestamptz,
  duration_minutes int,
  topic_kind text,
  topic_summary text,
  attendance_score int,
  juniors_attended int,
  feedback_score int,
  knowledge_gain_assessment text,
  owner_email text,
  status text,
  notes text,
  assessment_count bigint,
  avg_gain_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.session_at,
    s.duration_minutes,
    s.topic_kind,
    s.topic_summary,
    s.attendance_score,
    s.juniors_attended,
    s.feedback_score,
    s.knowledge_gain_assessment,
    s.owner_email,
    s.status,
    s.notes,
    COALESCE(COUNT(a.id), 0) AS assessment_count,
    COALESCE(AVG(a.gain_delta)::numeric(10,2), 0) AS avg_gain_delta
  FROM public.engineer_kt_sessions_r2518 s
  LEFT JOIN public.kt_session_assessments_r2518 a ON a.session_id = s.id
  GROUP BY s.id
  ORDER BY s.session_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_kt_sessions_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_kt_sessions_r2518() TO authenticated;

-- RPC 2: list_assessments_r2518
CREATE OR REPLACE FUNCTION public.list_assessments_r2518()
RETURNS TABLE (
  id uuid,
  session_id uuid,
  topic_summary text,
  topic_kind text,
  session_at timestamptz,
  pre_score int,
  post_score int,
  gain_delta int,
  confidence_kind text,
  follow_up_required boolean,
  follow_up_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.session_id,
    s.topic_summary,
    s.topic_kind,
    s.session_at,
    a.pre_score,
    a.post_score,
    a.gain_delta,
    a.confidence_kind,
    a.follow_up_required,
    a.follow_up_at,
    a.notes
  FROM public.kt_session_assessments_r2518 a
  JOIN public.engineer_kt_sessions_r2518 s ON s.id = a.session_id
  ORDER BY s.session_at DESC, a.gain_delta DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_assessments_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_assessments_r2518() TO authenticated;

-- RPC 3: top_senior_trainers_r2518
CREATE OR REPLACE FUNCTION public.top_senior_trainers_r2518()
RETURNS TABLE (
  owner_email text,
  sessions_count bigint,
  juniors_trained bigint,
  avg_feedback_score numeric,
  avg_attendance numeric,
  transformative_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.owner_email,
    COUNT(*) AS sessions_count,
    COALESCE(SUM(s.juniors_attended), 0)::bigint AS juniors_trained,
    COALESCE(AVG(s.feedback_score)::numeric(10,2), 0) AS avg_feedback_score,
    COALESCE(AVG(s.attendance_score)::numeric(10,2), 0) AS avg_attendance,
    COUNT(*) FILTER (WHERE s.knowledge_gain_assessment = 'transformative') AS transformative_count
  FROM public.engineer_kt_sessions_r2518 s
  GROUP BY s.owner_email
  ORDER BY sessions_count DESC, avg_feedback_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_senior_trainers_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_senior_trainers_r2518() TO authenticated;

-- RPC 4: topic_kind_breakdown_r2518
CREATE OR REPLACE FUNCTION public.topic_kind_breakdown_r2518()
RETURNS TABLE (
  topic_kind text,
  sessions_count bigint,
  juniors_total bigint,
  avg_feedback numeric,
  avg_gain_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.topic_kind,
    COUNT(DISTINCT s.id) AS sessions_count,
    COALESCE(SUM(s.juniors_attended), 0)::bigint AS juniors_total,
    COALESCE(AVG(s.feedback_score)::numeric(10,2), 0) AS avg_feedback,
    COALESCE(AVG(a.gain_delta)::numeric(10,2), 0) AS avg_gain_delta
  FROM public.engineer_kt_sessions_r2518 s
  LEFT JOIN public.kt_session_assessments_r2518 a ON a.session_id = s.id
  GROUP BY s.topic_kind
  ORDER BY sessions_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.topic_kind_breakdown_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.topic_kind_breakdown_r2518() TO authenticated;

-- RPC 5: knowledge_gain_distribution_r2518
CREATE OR REPLACE FUNCTION public.knowledge_gain_distribution_r2518()
RETURNS TABLE (
  knowledge_gain_assessment text,
  sessions_count bigint,
  juniors_total bigint,
  avg_feedback numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.knowledge_gain_assessment,
    COUNT(*) AS sessions_count,
    COALESCE(SUM(s.juniors_attended), 0)::bigint AS juniors_total,
    COALESCE(AVG(s.feedback_score)::numeric(10,2), 0) AS avg_feedback
  FROM public.engineer_kt_sessions_r2518 s
  GROUP BY s.knowledge_gain_assessment
  ORDER BY sessions_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.knowledge_gain_distribution_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.knowledge_gain_distribution_r2518() TO authenticated;

-- RPC 6: monthly_session_trend_r2518
CREATE OR REPLACE FUNCTION public.monthly_session_trend_r2518()
RETURNS TABLE (
  month_label text,
  sessions_count bigint,
  juniors_total bigint,
  avg_feedback numeric,
  follow_ups_needed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', s.session_at), 'YYYY-MM') AS month_label,
    COUNT(*) AS sessions_count,
    COALESCE(SUM(s.juniors_attended), 0)::bigint AS juniors_total,
    COALESCE(AVG(s.feedback_score)::numeric(10,2), 0) AS avg_feedback,
    COUNT(a.id) FILTER (WHERE a.follow_up_required) AS follow_ups_needed
  FROM public.engineer_kt_sessions_r2518 s
  LEFT JOIN public.kt_session_assessments_r2518 a ON a.session_id = s.id
  GROUP BY date_trunc('month', s.session_at)
  ORDER BY month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_session_trend_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_session_trend_r2518() TO authenticated;

-- RPC 7: top_juniors_progress_r2518
CREATE OR REPLACE FUNCTION public.top_juniors_progress_r2518()
RETURNS TABLE (
  assessment_id uuid,
  session_id uuid,
  topic_summary text,
  topic_kind text,
  session_at timestamptz,
  pre_score int,
  post_score int,
  gain_delta int,
  confidence_kind text,
  follow_up_required boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id AS assessment_id,
    a.session_id,
    s.topic_summary,
    s.topic_kind,
    s.session_at,
    a.pre_score,
    a.post_score,
    a.gain_delta,
    a.confidence_kind,
    a.follow_up_required
  FROM public.kt_session_assessments_r2518 a
  JOIN public.engineer_kt_sessions_r2518 s ON s.id = a.session_id
  ORDER BY a.gain_delta DESC, a.post_score DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_juniors_progress_r2518() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_juniors_progress_r2518() TO authenticated;
