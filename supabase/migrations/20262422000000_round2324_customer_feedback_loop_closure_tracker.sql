BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_feedback_loop_entries_r2324 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  submitted_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  submitter_role text NOT NULL CHECK (submitter_role IN ('engineer','hospital_admin','supplier','manufacturer','logistics')),
  feedback_channel text NOT NULL CHECK (feedback_channel IN ('app_rating','support_ticket','email','phone','nps_survey','field_visit','escalation','other')),
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative','critical')),
  topic_tag text NOT NULL,
  feedback_summary text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('low','medium','high','urgent')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  response_sent_at timestamptz,
  loop_closed_at timestamptz,
  closure_response text,
  closed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_open boolean GENERATED ALWAYS AS (loop_closed_at IS NULL) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cfle_r2324_open ON public.customer_feedback_loop_entries_r2324(is_open, severity, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_cfle_r2324_submitted ON public.customer_feedback_loop_entries_r2324(submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_cfle_r2324_channel ON public.customer_feedback_loop_entries_r2324(feedback_channel);

ALTER TABLE public.customer_feedback_loop_entries_r2324 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_feedback_loop_entries_r2324;
CREATE POLICY founder_all ON public.customer_feedback_loop_entries_r2324
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_feedback_loop_actions_r2324 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid NOT NULL REFERENCES public.customer_feedback_loop_entries_r2324(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('acknowledged','investigated','responded','escalated','resolved','reopened','note')),
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  action_notes text,
  action_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cfla_r2324_feedback ON public.customer_feedback_loop_actions_r2324(feedback_id, action_at DESC);

ALTER TABLE public.customer_feedback_loop_actions_r2324 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_feedback_loop_actions_r2324;
CREATE POLICY founder_all ON public.customer_feedback_loop_actions_r2324
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_r2324_feedback_summary()
RETURNS TABLE (
  total_feedback bigint,
  open_count bigint,
  closed_count bigint,
  critical_open bigint,
  avg_close_hours numeric,
  median_close_hours numeric,
  oldest_open_age_hours numeric,
  unacknowledged_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE is_open)::bigint,
    COUNT(*) FILTER (WHERE NOT is_open)::bigint,
    COUNT(*) FILTER (WHERE is_open AND severity IN ('high','urgent'))::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (loop_closed_at - submitted_at))/3600.0)::numeric, 2),
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (loop_closed_at - submitted_at))/3600.0))::numeric, 2),
    ROUND((EXTRACT(EPOCH FROM (now() - MIN(submitted_at) FILTER (WHERE is_open)))/3600.0)::numeric, 2),
    COUNT(*) FILTER (WHERE acknowledged_at IS NULL AND is_open)::bigint
  FROM public.customer_feedback_loop_entries_r2324;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_feedback_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_feedback_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_open_backlog()
RETURNS TABLE (
  id uuid,
  topic_tag text,
  feedback_channel text,
  sentiment text,
  severity text,
  submitter_role text,
  feedback_summary text,
  submitted_at timestamptz,
  age_hours numeric,
  acknowledged boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.topic_tag, f.feedback_channel, f.sentiment, f.severity, f.submitter_role,
    f.feedback_summary, f.submitted_at,
    ROUND((EXTRACT(EPOCH FROM (now() - f.submitted_at))/3600.0)::numeric, 1),
    (f.acknowledged_at IS NOT NULL)
  FROM public.customer_feedback_loop_entries_r2324 f
  WHERE f.is_open
  ORDER BY CASE f.severity WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, f.submitted_at ASC
  LIMIT 200;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_open_backlog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_open_backlog() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_closure_by_channel()
RETURNS TABLE (
  feedback_channel text,
  total bigint,
  closed bigint,
  open bigint,
  closure_rate_pct numeric,
  avg_close_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.feedback_channel,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE NOT f.is_open)::bigint,
    COUNT(*) FILTER (WHERE f.is_open)::bigint,
    ROUND((COUNT(*) FILTER (WHERE NOT f.is_open)::numeric * 100.0 / NULLIF(COUNT(*), 0))::numeric, 1),
    ROUND(AVG(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/3600.0)::numeric, 2)
  FROM public.customer_feedback_loop_entries_r2324 f
  GROUP BY f.feedback_channel
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_closure_by_channel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_closure_by_channel() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_topic_breakdown()
RETURNS TABLE (
  topic_tag text,
  total bigint,
  open_count bigint,
  negative_count bigint,
  avg_close_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.topic_tag,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE f.is_open)::bigint,
    COUNT(*) FILTER (WHERE f.sentiment IN ('negative','critical'))::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/3600.0)::numeric, 2)
  FROM public.customer_feedback_loop_entries_r2324 f
  GROUP BY f.topic_tag
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_topic_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_topic_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_weekly_trend()
RETURNS TABLE (
  week_start date,
  total_in bigint,
  total_closed bigint,
  avg_close_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', f.submitted_at)::date AS wk,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE NOT f.is_open)::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/3600.0)::numeric, 2)
  FROM public.customer_feedback_loop_entries_r2324 f
  WHERE f.submitted_at >= now() - interval '12 weeks'
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_weekly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_weekly_trend() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_recent_closures()
RETURNS TABLE (
  id uuid,
  topic_tag text,
  feedback_channel text,
  severity text,
  closure_response text,
  loop_closed_at timestamptz,
  close_hours numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.topic_tag, f.feedback_channel, f.severity, f.closure_response, f.loop_closed_at,
    ROUND((EXTRACT(EPOCH FROM (f.loop_closed_at - f.submitted_at))/3600.0)::numeric, 1)
  FROM public.customer_feedback_loop_entries_r2324 f
  WHERE f.loop_closed_at IS NOT NULL
  ORDER BY f.loop_closed_at DESC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_recent_closures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_recent_closures() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_r2324_close_loop(
  p_feedback_id uuid,
  p_closure_response text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  SELECT id INTO v_actor_id FROM public.profiles WHERE email = v_email LIMIT 1;

  UPDATE public.customer_feedback_loop_entries_r2324
  SET loop_closed_at = now(),
      response_sent_at = COALESCE(response_sent_at, now()),
      acknowledged_at = COALESCE(acknowledged_at, now()),
      closure_response = p_closure_response,
      closed_by = v_actor_id,
      updated_at = now()
  WHERE id = p_feedback_id AND is_open;

  INSERT INTO public.customer_feedback_loop_actions_r2324(feedback_id, action_type, actor_id, actor_email, action_notes)
  VALUES (p_feedback_id, 'resolved', v_actor_id, v_email, p_closure_response);

  RETURN p_feedback_id;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_r2324_close_loop(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2324_close_loop(uuid, text) TO authenticated;

COMMIT;
