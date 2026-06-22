BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_speaker_engagements_r1946 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_date date NOT NULL,
  audience_label text NOT NULL,
  audience_size int NOT NULL DEFAULT 0,
  talk_title text NOT NULL,
  talk_status text NOT NULL CHECK (talk_status IN ('accepted','declined','delivered','cancelled','postponed')),
  recording_url text,
  slides_url text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_speaker_followup_log_r1946 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id uuid NOT NULL REFERENCES public.founder_speaker_engagements_r1946(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_you_sent','recording_published','audience_followup','repurpose_content','decline_followup')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_speaker_engagements_r1946 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_speaker_followup_log_r1946 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engagements_r1946 ON public.founder_speaker_engagements_r1946;
CREATE POLICY founder_all_engagements_r1946 ON public.founder_speaker_engagements_r1946
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_followups_r1946 ON public.founder_speaker_followup_log_r1946;
CREATE POLICY founder_all_followups_r1946 ON public.founder_speaker_followup_log_r1946
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_engagements_r1946()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  audience_label text,
  audience_size int,
  talk_title text,
  talk_status text,
  recording_url text,
  slides_url text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.id, e.event_name, e.event_date, e.audience_label, e.audience_size,
         e.talk_title, e.talk_status, e.recording_url, e.slides_url, e.captured_at
  FROM public.founder_speaker_engagements_r1946 e
  ORDER BY e.event_date DESC NULLS LAST, e.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_engagement_r1946(
  p_event_name text,
  p_event_date date,
  p_audience_label text,
  p_audience_size int,
  p_talk_title text,
  p_talk_status text,
  p_recording_url text,
  p_slides_url text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_speaker_engagements_r1946(
    event_name, event_date, audience_label, audience_size, talk_title, talk_status, recording_url, slides_url
  ) VALUES (
    p_event_name, p_event_date, p_audience_label, COALESCE(p_audience_size, 0), p_talk_title, p_talk_status, p_recording_url, p_slides_url
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_engagement_r1946',
    jsonb_build_object('id', v_id, 'event_name', p_event_name, 'event_date', p_event_date, 'talk_status', p_talk_status)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_followups_r1946(p_engagement_id uuid)
RETURNS TABLE (
  id uuid,
  engagement_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.engagement_id, f.action_type, f.taken_at, f.by_email, f.notes_md
  FROM public.founder_speaker_followup_log_r1946 f
  WHERE f.engagement_id = p_engagement_id
  ORDER BY f.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_followup_r1946(
  p_engagement_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_speaker_followup_log_r1946(engagement_id, action_type, by_email, notes_md)
  VALUES (p_engagement_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_followup_r1946',
    jsonb_build_object('id', v_id, 'engagement_id', p_engagement_id, 'action_type', p_action_type)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1946(
  p_engagement_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_new_status NOT IN ('accepted','declined','delivered','cancelled','postponed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.founder_speaker_engagements_r1946
  SET talk_status = p_new_status, updated_at = now()
  WHERE id = p_engagement_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1946',
    jsonb_build_object('engagement_id', p_engagement_id, 'new_status', p_new_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.upcoming_events_r1946()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  audience_label text,
  audience_size int,
  talk_title text,
  talk_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.id, e.event_name, e.event_date, e.audience_label, e.audience_size, e.talk_title, e.talk_status
  FROM public.founder_speaker_engagements_r1946 e
  WHERE e.event_date >= CURRENT_DATE
    AND e.talk_status IN ('accepted','postponed')
  ORDER BY e.event_date ASC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_followups_r1946()
RETURNS TABLE (
  id uuid,
  engagement_id uuid,
  event_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.engagement_id, e.event_name, f.action_type, f.taken_at, f.by_email, f.notes_md
  FROM public.founder_speaker_followup_log_r1946 f
  JOIN public.founder_speaker_engagements_r1946 e ON e.id = f.engagement_id
  ORDER BY f.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engagements_r1946() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1946(text, date, text, int, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_followups_r1946(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_followup_r1946(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1946(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_events_r1946() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_followups_r1946() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_engagements_r1946() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1946(text, date, text, int, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_followups_r1946(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_followup_r1946(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1946(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_events_r1946() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_followups_r1946() TO authenticated;

COMMIT;
