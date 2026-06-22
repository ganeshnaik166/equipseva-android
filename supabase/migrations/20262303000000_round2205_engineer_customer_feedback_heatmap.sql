BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_feedback_entries_r2205 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  engineer_city text,
  month_bucket date NOT NULL,
  feedback_type text NOT NULL CHECK (feedback_type IN ('rating','complaint','compliment')),
  rating_value int CHECK (rating_value BETWEEN 1 AND 5),
  customer_org text,
  job_kind text,
  feedback_summary text,
  severity text DEFAULT 'normal' CHECK (severity IN ('normal','elevated','severe')),
  coaching_flag boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_coaching_notes_r2205 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  coaching_topic text NOT NULL,
  coaching_status text NOT NULL DEFAULT 'open' CHECK (coaching_status IN ('open','scheduled','in_progress','completed','escalated')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  notes text,
  assigned_mentor text,
  due_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  actor_user_id uuid REFERENCES public.profiles(id),
  actor_email text
);

CREATE INDEX IF NOT EXISTS idx_ecfe_r2205_engineer ON public.engineer_feedback_entries_r2205(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecfe_r2205_month ON public.engineer_feedback_entries_r2205(month_bucket);
CREATE INDEX IF NOT EXISTS idx_ecfe_r2205_type ON public.engineer_feedback_entries_r2205(feedback_type);
CREATE INDEX IF NOT EXISTS idx_ecn_r2205_engineer ON public.engineer_coaching_notes_r2205(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecn_r2205_status ON public.engineer_coaching_notes_r2205(coaching_status);

ALTER TABLE public.engineer_feedback_entries_r2205 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_coaching_notes_r2205 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_feedback_entries_r2205;
CREATE POLICY founder_all ON public.engineer_feedback_entries_r2205 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_coaching_notes_r2205;
CREATE POLICY founder_all ON public.engineer_coaching_notes_r2205 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_feedback_r2205()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  engineer_city text,
  month_bucket date,
  feedback_type text,
  rating_value int,
  customer_org text,
  job_kind text,
  feedback_summary text,
  severity text,
  coaching_flag boolean,
  created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_name, e.engineer_city, e.month_bucket, e.feedback_type,
         e.rating_value, e.customer_org, e.job_kind, e.feedback_summary,
         e.severity, e.coaching_flag, e.created_at
  FROM public.engineer_feedback_entries_r2205 e
  ORDER BY e.month_bucket DESC, e.created_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2205()
RETURNS TABLE(
  op_name text,
  actor_email text,
  after_value jsonb,
  created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.op_name, f.actor_email, f.after_value, f.created_at
  FROM public.founder_action_log f
  WHERE f.op_name LIKE '%_r2205'
  ORDER BY f.created_at DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.top_engineers_r2205()
RETURNS TABLE(
  engineer_name text,
  total_feedback int,
  avg_rating numeric,
  complaint_count int,
  compliment_count int,
  coaching_flagged int
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_name,
    COUNT(*)::int AS total_feedback,
    ROUND(AVG(e.rating_value) FILTER (WHERE e.feedback_type = 'rating'), 2) AS avg_rating,
    (COUNT(*) FILTER (WHERE e.feedback_type = 'complaint'))::int AS complaint_count,
    (COUNT(*) FILTER (WHERE e.feedback_type = 'compliment'))::int AS compliment_count,
    (COUNT(*) FILTER (WHERE e.coaching_flag = true))::int AS coaching_flagged
  FROM public.engineer_feedback_entries_r2205 e
  GROUP BY e.engineer_name
  ORDER BY complaint_count DESC, avg_rating ASC NULLS LAST
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.log_feedback_r2205(
  p_engineer_user_id uuid,
  p_engineer_name text,
  p_engineer_city text,
  p_month_bucket date,
  p_feedback_type text,
  p_rating_value int,
  p_customer_org text,
  p_job_kind text,
  p_feedback_summary text,
  p_severity text,
  p_coaching_flag boolean
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_feedback_entries_r2205(
    engineer_user_id, engineer_name, engineer_city, month_bucket, feedback_type,
    rating_value, customer_org, job_kind, feedback_summary, severity, coaching_flag
  ) VALUES (
    p_engineer_user_id, p_engineer_name, p_engineer_city, p_month_bucket, p_feedback_type,
    p_rating_value, p_customer_org, p_job_kind, p_feedback_summary,
    COALESCE(p_severity, 'normal'), COALESCE(p_coaching_flag, false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_feedback_r2205',
    jsonb_build_object('id', v_id, 'engineer', p_engineer_name, 'type', p_feedback_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2205(
  p_engineer_user_id uuid,
  p_engineer_name text,
  p_coaching_topic text,
  p_priority text,
  p_notes text,
  p_assigned_mentor text,
  p_due_date date
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_coaching_notes_r2205(
    engineer_user_id, engineer_name, coaching_topic, priority,
    notes, assigned_mentor, due_date, actor_user_id, actor_email
  ) VALUES (
    p_engineer_user_id, p_engineer_name, p_coaching_topic, COALESCE(p_priority, 'medium'),
    p_notes, p_assigned_mentor, p_due_date, auth.uid(), (auth.jwt()->>'email')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2205',
    jsonb_build_object('id', v_id, 'engineer', p_engineer_name, 'topic', p_coaching_topic));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2205(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','scheduled','in_progress','completed','escalated') THEN
    RAISE EXCEPTION 'bad status';
  END IF;
  UPDATE public.engineer_coaching_notes_r2205
    SET coaching_status = p_status, updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2205',
    jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.aggregate_or_search_r2205()
RETURNS TABLE(
  month_bucket date,
  total_feedback int,
  avg_rating numeric,
  complaints int,
  compliments int,
  coaching_flagged int,
  severe_count int
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.month_bucket,
    COUNT(*)::int AS total_feedback,
    ROUND(AVG(e.rating_value) FILTER (WHERE e.feedback_type = 'rating'), 2) AS avg_rating,
    (COUNT(*) FILTER (WHERE e.feedback_type = 'complaint'))::int AS complaints,
    (COUNT(*) FILTER (WHERE e.feedback_type = 'compliment'))::int AS compliments,
    (COUNT(*) FILTER (WHERE e.coaching_flag = true))::int AS coaching_flagged,
    (COUNT(*) FILTER (WHERE e.severity = 'severe'))::int AS severe_count
  FROM public.engineer_feedback_entries_r2205 e
  GROUP BY e.month_bucket
  ORDER BY e.month_bucket DESC
  LIMIT 24;
END $$;

REVOKE ALL ON FUNCTION public.list_feedback_r2205() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2205() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_engineers_r2205() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_feedback_r2205(uuid, text, text, date, text, int, text, text, text, text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2205(uuid, text, text, text, text, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2205(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_or_search_r2205() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_feedback_r2205() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2205() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineers_r2205() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_feedback_r2205(uuid, text, text, date, text, int, text, text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2205(uuid, text, text, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2205(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_or_search_r2205() TO authenticated;

COMMIT;
