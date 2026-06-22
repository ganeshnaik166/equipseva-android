BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_survey_insights_r2191 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  survey_label text NOT NULL,
  insight_md text NOT NULL,
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','actioned','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_survey_action_log_r2191 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  insight_id uuid NOT NULL REFERENCES public.hospital_customer_survey_insights_r2191(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('addressed','feature_requested','escalated','celebrated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_survey_insights_r2191 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_survey_action_log_r2191 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_insights_r2191 ON public.hospital_customer_survey_insights_r2191;
CREATE POLICY founder_all_insights_r2191 ON public.hospital_customer_survey_insights_r2191
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2191 ON public.hospital_survey_action_log_r2191;
CREATE POLICY founder_all_action_log_r2191 ON public.hospital_survey_action_log_r2191
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_hcsi_r2191_hospital ON public.hospital_customer_survey_insights_r2191(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hcsi_r2191_captured ON public.hospital_customer_survey_insights_r2191(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_hsal_r2191_insight ON public.hospital_survey_action_log_r2191(insight_id);
CREATE INDEX IF NOT EXISTS idx_hsal_r2191_taken ON public.hospital_survey_action_log_r2191(taken_at DESC);

-- list_insights
DROP FUNCTION IF EXISTS public.list_insights_r2191(int);
CREATE FUNCTION public.list_insights_r2191(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, hospital_id uuid, survey_label text, insight_md text, sentiment text, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.hospital_id, i.survey_label, i.insight_md, i.sentiment, i.status, i.captured_at
    FROM public.hospital_customer_survey_insights_r2191 i
    ORDER BY i.captured_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_insights_r2191(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_insights_r2191(int) TO authenticated;

-- log_insight
DROP FUNCTION IF EXISTS public.log_insight_r2191(uuid, text, text, text);
CREATE FUNCTION public.log_insight_r2191(p_hospital_id uuid, p_survey_label text, p_insight_md text, p_sentiment text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_survey_insights_r2191(hospital_id, survey_label, insight_md, sentiment)
    VALUES (p_hospital_id, p_survey_label, p_insight_md, p_sentiment)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_insight_r2191',
      jsonb_build_object('insight_id', v_id, 'hospital_id', p_hospital_id, 'sentiment', p_sentiment));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_insight_r2191(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_insight_r2191(uuid, text, text, text) TO authenticated;

-- list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2191(uuid);
CREATE FUNCTION public.list_actions_r2191(p_insight_id uuid)
RETURNS TABLE(id uuid, insight_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.insight_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_survey_action_log_r2191 a
    WHERE a.insight_id = p_insight_id
    ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2191(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2191(uuid) TO authenticated;

-- log_action
DROP FUNCTION IF EXISTS public.log_action_r2191(uuid, text, text, text);
CREATE FUNCTION public.log_action_r2191(p_insight_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_survey_action_log_r2191(insight_id, action_type, by_email, notes_md)
    VALUES (p_insight_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2191',
      jsonb_build_object('action_id', v_id, 'insight_id', p_insight_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2191(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2191(uuid, text, text, text) TO authenticated;

-- mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2191(uuid, text);
CREATE FUNCTION public.mark_status_r2191(p_insight_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_survey_insights_r2191
    SET status = p_status, updated_at = now()
    WHERE id = p_insight_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2191',
      jsonb_build_object('insight_id', p_insight_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2191(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2191(uuid, text) TO authenticated;

-- negative_insights
DROP FUNCTION IF EXISTS public.negative_insights_r2191(int);
CREATE FUNCTION public.negative_insights_r2191(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, hospital_id uuid, survey_label text, insight_md text, sentiment text, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.hospital_id, i.survey_label, i.insight_md, i.sentiment, i.status, i.captured_at
    FROM public.hospital_customer_survey_insights_r2191 i
    WHERE i.sentiment IN ('negative','very_negative')
      AND i.status <> 'closed'
    ORDER BY i.captured_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.negative_insights_r2191(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.negative_insights_r2191(int) TO authenticated;

-- recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2191(int);
CREATE FUNCTION public.recent_actions_r2191(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, insight_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.insight_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_survey_action_log_r2191 a
    ORDER BY a.taken_at DESC
    LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2191(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2191(int) TO authenticated;

COMMIT;
