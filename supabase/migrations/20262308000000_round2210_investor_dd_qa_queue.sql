BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_dd_questions_r2210 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  question_topic text NOT NULL,
  question_text text NOT NULL,
  owner_user_id uuid REFERENCES public.profiles(id),
  owner_email text,
  asked_on date NOT NULL DEFAULT current_date,
  due_on date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','answered','blocked','withdrawn')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  response_text text,
  answered_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_dd_question_events_r2210 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.investor_dd_questions_r2210(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','status_changed','owner_assigned','answered','note_added','reopened')),
  note text,
  actor_user_id uuid REFERENCES public.profiles(id),
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_dd_questions_r2210 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_dd_question_events_r2210 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_dd_questions_r2210;
CREATE POLICY founder_all ON public.investor_dd_questions_r2210
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.investor_dd_question_events_r2210;
CREATE POLICY founder_all ON public.investor_dd_question_events_r2210
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_dd_q_r2210_status ON public.investor_dd_questions_r2210(status);
CREATE INDEX IF NOT EXISTS idx_dd_q_r2210_investor ON public.investor_dd_questions_r2210(investor_name);
CREATE INDEX IF NOT EXISTS idx_dd_q_r2210_asked ON public.investor_dd_questions_r2210(asked_on DESC);
CREATE INDEX IF NOT EXISTS idx_dd_qe_r2210_qid ON public.investor_dd_question_events_r2210(question_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.list_investor_dd_questions_r2210()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_firm text,
  question_topic text,
  question_text text,
  owner_email text,
  asked_on date,
  due_on date,
  status text,
  priority text,
  days_open int,
  answered_on date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      q.id,
      q.investor_name,
      q.investor_firm,
      q.question_topic,
      q.question_text,
      q.owner_email,
      q.asked_on,
      q.due_on,
      q.status,
      q.priority,
      (COALESCE(q.answered_on, current_date) - q.asked_on)::int AS days_open,
      q.answered_on
    FROM public.investor_dd_questions_r2210 q
    ORDER BY
      CASE q.status WHEN 'urgent' THEN 0 WHEN 'open' THEN 1 WHEN 'in_progress' THEN 2 ELSE 3 END,
      q.asked_on ASC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2210()
RETURNS TABLE (
  id uuid,
  question_id uuid,
  event_type text,
  note text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.question_id, e.event_type, e.note, e.actor_email, e.created_at
    FROM public.investor_dd_question_events_r2210 e
    ORDER BY e.created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_investors_r2210()
RETURNS TABLE (
  investor_name text,
  investor_firm text,
  total_questions int,
  open_questions int,
  answered_questions int,
  avg_days_to_answer numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      q.investor_name,
      MAX(q.investor_firm) AS investor_firm,
      COUNT(*)::int AS total_questions,
      (COUNT(*) FILTER (WHERE q.status IN ('open','in_progress')))::int AS open_questions,
      (COUNT(*) FILTER (WHERE q.status = 'answered'))::int AS answered_questions,
      ROUND(AVG(CASE WHEN q.answered_on IS NOT NULL THEN (q.answered_on - q.asked_on) END)::numeric, 1) AS avg_days_to_answer
    FROM public.investor_dd_questions_r2210 q
    GROUP BY q.investor_name
    ORDER BY open_questions DESC, total_questions DESC
    LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_dd_question_r2210(
  p_investor_name text,
  p_investor_firm text,
  p_question_topic text,
  p_question_text text,
  p_priority text,
  p_due_on date,
  p_owner_email text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_dd_questions_r2210(
    investor_name, investor_firm, question_topic, question_text,
    priority, due_on, owner_email
  ) VALUES (
    p_investor_name, p_investor_firm, p_question_topic, p_question_text,
    COALESCE(p_priority, 'normal'), p_due_on, p_owner_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.investor_dd_question_events_r2210(question_id, event_type, note, actor_user_id, actor_email)
  VALUES (v_id, 'created', 'Question logged', auth.uid(), (auth.jwt()->>'email'));

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2210',
    jsonb_build_object('action','create_question','question_id',v_id,'investor',p_investor_name));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2210(
  p_question_id uuid,
  p_event_type text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_dd_question_events_r2210(question_id, event_type, note, actor_user_id, actor_email)
  VALUES (p_question_id, COALESCE(p_event_type,'note_added'), p_note, auth.uid(), (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2210',
    jsonb_build_object('action','log_event','question_id',p_question_id,'event',p_event_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2210(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','in_progress','answered','blocked','withdrawn') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.investor_dd_questions_r2210
  SET status = p_status,
      answered_on = CASE WHEN p_status = 'answered' THEN current_date ELSE answered_on END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.investor_dd_question_events_r2210(question_id, event_type, note, actor_user_id, actor_email)
  VALUES (p_id, 'status_changed', 'Status -> ' || p_status, auth.uid(), (auth.jwt()->>'email'));

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2210',
    jsonb_build_object('action','mark_status','question_id',p_id,'status',p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_dd_queue_r2210()
RETURNS TABLE (
  total_questions int,
  open_count int,
  in_progress_count int,
  answered_count int,
  blocked_count int,
  withdrawn_count int,
  urgent_open int,
  overdue_count int,
  avg_days_open numeric,
  oldest_open_days int,
  unique_investors int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::int,
      (COUNT(*) FILTER (WHERE status = 'open'))::int,
      (COUNT(*) FILTER (WHERE status = 'in_progress'))::int,
      (COUNT(*) FILTER (WHERE status = 'answered'))::int,
      (COUNT(*) FILTER (WHERE status = 'blocked'))::int,
      (COUNT(*) FILTER (WHERE status = 'withdrawn'))::int,
      (COUNT(*) FILTER (WHERE priority = 'urgent' AND status IN ('open','in_progress')))::int,
      (COUNT(*) FILTER (WHERE due_on IS NOT NULL AND due_on < current_date AND status IN ('open','in_progress')))::int,
      ROUND(AVG(CASE WHEN status IN ('open','in_progress') THEN (current_date - asked_on) END)::numeric, 1),
      COALESCE(MAX(CASE WHEN status IN ('open','in_progress') THEN (current_date - asked_on) END), 0)::int,
      COUNT(DISTINCT investor_name)::int
    FROM public.investor_dd_questions_r2210;
END;
$$;

REVOKE ALL ON FUNCTION public.list_investor_dd_questions_r2210() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2210() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_investors_r2210() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_investor_dd_question_r2210(text,text,text,text,text,date,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2210(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2210(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_dd_queue_r2210() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_dd_questions_r2210() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2210() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_investors_r2210() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_dd_question_r2210(text,text,text,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2210(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2210(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_dd_queue_r2210() TO authenticated;

COMMIT;
