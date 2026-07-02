BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_voice_aggregator_r2035 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voice_source text NOT NULL CHECK (voice_source IN ('survey','call','visit','social_post','email','incident')),
  voice_text_md text NOT NULL,
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','addressed','escalated','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_voice_action_log_r2035 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_id uuid NOT NULL REFERENCES public.hospital_customer_voice_aggregator_r2035(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('addressed','escalated','celebrated','follow_up','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_voice_aggregator_r2035 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_voice_action_log_r2035 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_voices_r2035 ON public.hospital_customer_voice_aggregator_r2035;
CREATE POLICY founder_all_voices_r2035 ON public.hospital_customer_voice_aggregator_r2035
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2035 ON public.hospital_voice_action_log_r2035;
CREATE POLICY founder_all_actions_r2035 ON public.hospital_voice_action_log_r2035
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_voices
CREATE OR REPLACE FUNCTION public.list_voices_r2035()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  voice_source text,
  voice_text_md text,
  sentiment text,
  captured_at timestamptz,
  status text
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
  SELECT v.id, v.hospital_id, o.name, v.voice_source, v.voice_text_md, v.sentiment, v.captured_at, v.status
  FROM public.hospital_customer_voice_aggregator_r2035 v
  LEFT JOIN public.profiles p ON p.id = v.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY v.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_voice
CREATE OR REPLACE FUNCTION public.log_voice_r2035(
  p_hospital_id uuid,
  p_voice_source text,
  p_voice_text_md text,
  p_sentiment text
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
  INSERT INTO public.hospital_customer_voice_aggregator_r2035 (hospital_id, voice_source, voice_text_md, sentiment)
  VALUES (p_hospital_id, p_voice_source, p_voice_text_md, p_sentiment)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_voice_r2035',
    jsonb_build_object('voice_id', v_id, 'hospital_id', p_hospital_id, 'sentiment', p_sentiment));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2035(p_voice_id uuid)
RETURNS TABLE (
  id uuid,
  voice_id uuid,
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
  SELECT a.id, a.voice_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_voice_action_log_r2035 a
  WHERE a.voice_id = p_voice_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2035(
  p_voice_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_voice_action_log_r2035 (voice_id, action_type, by_email, notes_md)
  VALUES (p_voice_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2035',
    jsonb_build_object('action_id', v_id, 'voice_id', p_voice_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2035(
  p_voice_id uuid,
  p_status text
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
  UPDATE public.hospital_customer_voice_aggregator_r2035
  SET status = p_status, updated_at = now()
  WHERE id = p_voice_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2035',
    jsonb_build_object('voice_id', p_voice_id, 'status', p_status));
END;
$$;

-- 6. by_sentiment
CREATE OR REPLACE FUNCTION public.by_sentiment_r2035()
RETURNS TABLE (
  sentiment text,
  voice_count bigint,
  active_count bigint,
  escalated_count bigint
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
  SELECT
    v.sentiment,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE v.status = 'active')::bigint,
    COUNT(*) FILTER (WHERE v.status = 'escalated')::bigint
  FROM public.hospital_customer_voice_aggregator_r2035 v
  GROUP BY v.sentiment
  ORDER BY v.sentiment;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2035()
RETURNS TABLE (
  id uuid,
  voice_id uuid,
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
  SELECT a.id, a.voice_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_voice_action_log_r2035 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_voices_r2035() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_voice_r2035(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2035(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2035(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2035(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.by_sentiment_r2035() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2035() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_voices_r2035() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_voice_r2035(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2035(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2035(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2035(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.by_sentiment_r2035() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2035() TO authenticated;

COMMIT;
