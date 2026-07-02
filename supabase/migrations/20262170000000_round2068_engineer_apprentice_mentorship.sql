BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_apprentice_mentorship_r2068 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES public.profiles(id),
  apprentice_user_id uuid NOT NULL REFERENCES public.profiles(id),
  mentorship_focus text NOT NULL CHECK (mentorship_focus IN ('technical','business','customer','safety','leadership')),
  paired_at timestamptz NOT NULL DEFAULT now(),
  expected_completion_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','abandoned')),
  last_meeting_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_mentorship_meeting_log_r2068 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id uuid NOT NULL REFERENCES public.engineer_apprentice_mentorship_r2068(id) ON DELETE CASCADE,
  meeting_date date NOT NULL,
  topic_md text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('progress','struggle','breakthrough','blocker','escalation')),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_apprentice_mentorship_r2068 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mentorship_meeting_log_r2068 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pairs_r2068 ON public.engineer_apprentice_mentorship_r2068;
CREATE POLICY founder_all_pairs_r2068 ON public.engineer_apprentice_mentorship_r2068
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_meetings_r2068 ON public.engineer_mentorship_meeting_log_r2068;
CREATE POLICY founder_all_meetings_r2068 ON public.engineer_mentorship_meeting_log_r2068
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_pairs_r2068()
RETURNS TABLE(id uuid, mentor_user_id uuid, apprentice_user_id uuid, mentorship_focus text, paired_at timestamptz, expected_completion_date date, status text, last_meeting_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.mentor_user_id, p.apprentice_user_id, p.mentorship_focus, p.paired_at, p.expected_completion_date, p.status, p.last_meeting_at
  FROM public.engineer_apprentice_mentorship_r2068 p ORDER BY p.paired_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_pair_r2068(
  p_mentor uuid, p_apprentice uuid, p_focus text, p_expected date
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_apprentice_mentorship_r2068(mentor_user_id, apprentice_user_id, mentorship_focus, expected_completion_date)
  VALUES (p_mentor, p_apprentice, p_focus, p_expected) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pair_r2068', jsonb_build_object('id', v_id, 'mentor', p_mentor, 'apprentice', p_apprentice, 'focus', p_focus));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_meetings_r2068(p_pair uuid)
RETURNS TABLE(id uuid, pair_id uuid, meeting_date date, topic_md text, outcome text, by_email text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.id, m.pair_id, m.meeting_date, m.topic_md, m.outcome, m.by_email, m.created_at
  FROM public.engineer_mentorship_meeting_log_r2068 m WHERE m.pair_id = p_pair ORDER BY m.meeting_date DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_meeting_r2068(
  p_pair uuid, p_date date, p_topic text, p_outcome text, p_by text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_mentorship_meeting_log_r2068(pair_id, meeting_date, topic_md, outcome, by_email)
  VALUES (p_pair, p_date, p_topic, p_outcome, p_by) RETURNING id INTO v_id;
  UPDATE public.engineer_apprentice_mentorship_r2068 SET last_meeting_at = now(), updated_at = now() WHERE id = p_pair;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_meeting_r2068', jsonb_build_object('id', v_id, 'pair', p_pair, 'outcome', p_outcome));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2068(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_apprentice_mentorship_r2068 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2068', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.active_pairs_r2068()
RETURNS TABLE(id uuid, mentor_user_id uuid, apprentice_user_id uuid, mentorship_focus text, paired_at timestamptz, last_meeting_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.mentor_user_id, p.apprentice_user_id, p.mentorship_focus, p.paired_at, p.last_meeting_at
  FROM public.engineer_apprentice_mentorship_r2068 p WHERE p.status = 'active' ORDER BY p.paired_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_meetings_r2068()
RETURNS TABLE(id uuid, pair_id uuid, meeting_date date, topic_md text, outcome text, by_email text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.id, m.pair_id, m.meeting_date, m.topic_md, m.outcome, m.by_email, m.created_at
  FROM public.engineer_mentorship_meeting_log_r2068 m ORDER BY m.created_at DESC LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_pairs_r2068() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pair_r2068(uuid, uuid, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r2068(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_meeting_r2068(uuid, date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2068(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_pairs_r2068() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_meetings_r2068() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pairs_r2068() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pair_r2068(uuid, uuid, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_meetings_r2068(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_meeting_r2068(uuid, date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2068(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_pairs_r2068() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_meetings_r2068() TO authenticated;

COMMIT;
