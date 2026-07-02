BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_training_videos_r2212 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_email text,
  video_code text NOT NULL,
  video_title text NOT NULL,
  category text NOT NULL CHECK (category IN ('safety','clinical','compliance','product','soft_skills','dpdp')),
  required boolean NOT NULL DEFAULT true,
  duration_minutes int NOT NULL DEFAULT 0,
  watched_percent numeric(5,2) NOT NULL DEFAULT 0 CHECK (watched_percent BETWEEN 0 AND 100),
  quiz_score int,
  quiz_pass boolean NOT NULL DEFAULT false,
  pass_threshold int NOT NULL DEFAULT 80,
  status text NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started','in_progress','completed','expired','failed')),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  recertify_due_on date,
  recertify_cycle_months int NOT NULL DEFAULT 12,
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_training_videos_r2212_engineer ON public.engineer_training_videos_r2212(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_training_videos_r2212_status ON public.engineer_training_videos_r2212(status);
CREATE INDEX IF NOT EXISTS idx_training_videos_r2212_due ON public.engineer_training_videos_r2212(recertify_due_on);

CREATE TABLE IF NOT EXISTS public.engineer_training_actions_r2212 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id uuid REFERENCES public.engineer_training_videos_r2212(id) ON DELETE CASCADE,
  action text NOT NULL,
  detail text,
  acted_by uuid REFERENCES public.profiles(id),
  acted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_training_actions_r2212_training ON public.engineer_training_actions_r2212(training_id);

ALTER TABLE public.engineer_training_videos_r2212 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_training_actions_r2212 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_training_videos_r2212;
CREATE POLICY founder_all ON public.engineer_training_videos_r2212 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_training_actions_r2212;
CREATE POLICY founder_all ON public.engineer_training_actions_r2212 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_training_videos_r2212()
RETURNS TABLE(
  id uuid,
  engineer_email text,
  video_code text,
  video_title text,
  category text,
  required boolean,
  watched_percent numeric,
  quiz_score int,
  quiz_pass boolean,
  status text,
  recertify_due_on date,
  last_activity_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_email, t.video_code, t.video_title, t.category, t.required,
         t.watched_percent, t.quiz_score, t.quiz_pass, t.status, t.recertify_due_on, t.last_activity_at
  FROM public.engineer_training_videos_r2212 t
  ORDER BY t.recertify_due_on NULLS LAST, t.last_activity_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2212()
RETURNS TABLE(id uuid, action text, detail text, acted_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.action, a.detail, a.acted_at
  FROM public.engineer_training_actions_r2212 a
  ORDER BY a.acted_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_category_r2212()
RETURNS TABLE(category text, total int, completed int, overdue int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.category,
         COUNT(*)::int AS total,
         (COUNT(*) FILTER (WHERE t.status = 'completed'))::int AS completed,
         (COUNT(*) FILTER (WHERE t.recertify_due_on IS NOT NULL AND t.recertify_due_on < CURRENT_DATE))::int AS overdue
  FROM public.engineer_training_videos_r2212 t
  GROUP BY t.category
  ORDER BY total DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_training_video_r2212(
  p_engineer_user_id uuid,
  p_engineer_email text,
  p_video_code text,
  p_video_title text,
  p_category text,
  p_duration_minutes int,
  p_required boolean,
  p_recertify_cycle_months int
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_training_videos_r2212(
    engineer_user_id, engineer_email, video_code, video_title, category,
    duration_minutes, required, recertify_cycle_months,
    recertify_due_on
  )
  VALUES (
    p_engineer_user_id, p_engineer_email, p_video_code, p_video_title, p_category,
    COALESCE(p_duration_minutes,0), COALESCE(p_required,true), COALESCE(p_recertify_cycle_months,12),
    (CURRENT_DATE + (COALESCE(p_recertify_cycle_months,12) || ' months')::interval)::date
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2212_log_training', jsonb_build_object('id', v_id, 'video_code', p_video_code));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2212(p_training_id uuid, p_action text, p_detail text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_training_actions_r2212(training_id, action, detail, acted_by)
  VALUES (p_training_id, p_action, p_detail, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2212_log_action', jsonb_build_object('training_id', p_training_id, 'action', p_action));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2212(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('not_started','in_progress','completed','expired','failed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.engineer_training_videos_r2212
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
      last_activity_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2212_mark_status', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_training_r2212()
RETURNS TABLE(
  total int,
  completed int,
  in_progress int,
  not_started int,
  overdue_recert int,
  quiz_pass_rate numeric,
  avg_watched_percent numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int AS total,
    (COUNT(*) FILTER (WHERE status='completed'))::int AS completed,
    (COUNT(*) FILTER (WHERE status='in_progress'))::int AS in_progress,
    (COUNT(*) FILTER (WHERE status='not_started'))::int AS not_started,
    (COUNT(*) FILTER (WHERE recertify_due_on IS NOT NULL AND recertify_due_on < CURRENT_DATE))::int AS overdue_recert,
    ROUND(
      (COUNT(*) FILTER (WHERE quiz_pass = true))::numeric
      / NULLIF(COUNT(*) FILTER (WHERE quiz_score IS NOT NULL),0) * 100, 2
    ) AS quiz_pass_rate,
    ROUND(AVG(watched_percent), 2) AS avg_watched_percent
  FROM public.engineer_training_videos_r2212;
END;
$$;

REVOKE ALL ON FUNCTION public.list_training_videos_r2212() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2212() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_category_r2212() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_training_video_r2212(uuid, text, text, text, text, int, boolean, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2212(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2212(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_training_r2212() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_training_videos_r2212() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2212() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_category_r2212() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_training_video_r2212(uuid, text, text, text, text, int, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2212(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2212(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_training_r2212() TO authenticated;

COMMIT;
