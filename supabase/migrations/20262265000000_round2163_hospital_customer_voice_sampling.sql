BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_voice_sampling_r2163 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sample_date date NOT NULL DEFAULT current_date,
  response_text_md text,
  response_rating int CHECK (response_rating BETWEEN 1 AND 10),
  sentiment text CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','follow_up','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_voice_action_log_r2163 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sample_id uuid NOT NULL REFERENCES public.hospital_customer_voice_sampling_r2163(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('follow_up_sent','escalated','closed','positive_celebrated','concern_addressed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_voice_sampling_r2163 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_voice_action_log_r2163 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcvs_r2163_founder_all ON public.hospital_customer_voice_sampling_r2163;
CREATE POLICY hcvs_r2163_founder_all ON public.hospital_customer_voice_sampling_r2163
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hval_r2163_founder_all ON public.hospital_voice_action_log_r2163;
CREATE POLICY hval_r2163_founder_all ON public.hospital_voice_action_log_r2163
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS hcvs_r2163_hospital_idx ON public.hospital_customer_voice_sampling_r2163(hospital_id);
CREATE INDEX IF NOT EXISTS hcvs_r2163_date_idx ON public.hospital_customer_voice_sampling_r2163(sample_date DESC);
CREATE INDEX IF NOT EXISTS hcvs_r2163_status_idx ON public.hospital_customer_voice_sampling_r2163(status);
CREATE INDEX IF NOT EXISTS hval_r2163_sample_idx ON public.hospital_voice_action_log_r2163(sample_id);
CREATE INDEX IF NOT EXISTS hval_r2163_taken_idx ON public.hospital_voice_action_log_r2163(taken_at DESC);

-- list_samples
DROP FUNCTION IF EXISTS public.list_samples_r2163();
CREATE OR REPLACE FUNCTION public.list_samples_r2163()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  sample_date date,
  response_text_md text,
  response_rating int,
  sentiment text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, COALESCE(o.name, p.full_name, p.email) AS hospital_name,
         s.sample_date, s.response_text_md, s.response_rating, s.sentiment, s.status, s.captured_at
  FROM public.hospital_customer_voice_sampling_r2163 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_samples_r2163() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_samples_r2163() TO authenticated;

-- log_sample
DROP FUNCTION IF EXISTS public.log_sample_r2163(uuid, date, text, int, text, text);
CREATE OR REPLACE FUNCTION public.log_sample_r2163(
  p_hospital_id uuid,
  p_sample_date date,
  p_response_text_md text,
  p_response_rating int,
  p_sentiment text,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_voice_sampling_r2163(
    hospital_id, sample_date, response_text_md, response_rating, sentiment, status
  ) VALUES (
    p_hospital_id, COALESCE(p_sample_date, current_date), p_response_text_md, p_response_rating, p_sentiment, COALESCE(p_status, 'captured')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_sample_r2163',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'rating', p_response_rating, 'sentiment', p_sentiment));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_sample_r2163(uuid, date, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_sample_r2163(uuid, date, text, int, text, text) TO authenticated;

-- list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2163(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2163(p_sample_id uuid)
RETURNS TABLE (
  id uuid,
  sample_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.sample_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_voice_action_log_r2163 a
  WHERE a.sample_id = p_sample_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2163(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2163(uuid) TO authenticated;

-- log_action
DROP FUNCTION IF EXISTS public.log_action_r2163(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2163(
  p_sample_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_voice_action_log_r2163(sample_id, action_type, by_email, notes_md)
  VALUES (p_sample_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2163',
          jsonb_build_object('id', v_id, 'sample_id', p_sample_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2163(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2163(uuid, text, text) TO authenticated;

-- mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2163(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2163(p_sample_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_voice_sampling_r2163
     SET status = p_status, updated_at = now()
   WHERE id = p_sample_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2163',
          jsonb_build_object('sample_id', p_sample_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2163(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2163(uuid, text) TO authenticated;

-- low_ratings
DROP FUNCTION IF EXISTS public.low_ratings_r2163();
CREATE OR REPLACE FUNCTION public.low_ratings_r2163()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  response_rating int,
  sentiment text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, COALESCE(o.name, p.full_name, p.email) AS hospital_name,
         s.response_rating, s.sentiment, s.status, s.captured_at
  FROM public.hospital_customer_voice_sampling_r2163 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE s.response_rating IS NOT NULL AND s.response_rating <= 5
  ORDER BY s.response_rating ASC, s.captured_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.low_ratings_r2163() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_ratings_r2163() TO authenticated;

-- recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2163();
CREATE OR REPLACE FUNCTION public.recent_actions_r2163()
RETURNS TABLE (
  id uuid,
  sample_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.sample_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_voice_action_log_r2163 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2163() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2163() TO authenticated;

COMMIT;
