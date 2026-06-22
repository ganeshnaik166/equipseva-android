BEGIN;

-- =============================================================================
-- Round 1908: Engineer Knowledge Gap Tracker
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_knowledge_gaps_r1908 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  gap_topic text NOT NULL,
  gap_source text NOT NULL CHECK (gap_source IN ('self_reported','supervisor_flagged','job_failure','customer_complaint')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_training','closed','escalated')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ekg_r1908_engineer ON public.engineer_knowledge_gaps_r1908(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ekg_r1908_status ON public.engineer_knowledge_gaps_r1908(status);
CREATE INDEX IF NOT EXISTS idx_ekg_r1908_severity ON public.engineer_knowledge_gaps_r1908(severity);

CREATE TABLE IF NOT EXISTS public.engineer_gap_remediation_log_r1908 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gap_id uuid NOT NULL REFERENCES public.engineer_knowledge_gaps_r1908(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('training_assigned','shadow_assigned','escalated_to_specialist','closed_remediated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  outcome_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_egrl_r1908_gap ON public.engineer_gap_remediation_log_r1908(gap_id);
CREATE INDEX IF NOT EXISTS idx_egrl_r1908_taken ON public.engineer_gap_remediation_log_r1908(taken_at DESC);

ALTER TABLE public.engineer_knowledge_gaps_r1908 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_gap_remediation_log_r1908 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ekg_r1908_founder_all ON public.engineer_knowledge_gaps_r1908;
CREATE POLICY ekg_r1908_founder_all ON public.engineer_knowledge_gaps_r1908
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS egrl_r1908_founder_all ON public.engineer_gap_remediation_log_r1908;
CREATE POLICY egrl_r1908_founder_all ON public.engineer_gap_remediation_log_r1908
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs
-- =============================================================================

CREATE OR REPLACE FUNCTION public.list_gaps_r1908()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  gap_topic text,
  gap_source text,
  severity text,
  status text,
  opened_at timestamptz,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.engineer_user_id, p.email, g.gap_topic, g.gap_source, g.severity, g.status, g.opened_at, g.closed_at
  FROM public.engineer_knowledge_gaps_r1908 g
  LEFT JOIN public.profiles p ON p.id = g.engineer_user_id
  ORDER BY g.opened_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_gap_r1908(
  p_engineer_user_id uuid,
  p_gap_topic text,
  p_gap_source text,
  p_severity text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_knowledge_gaps_r1908(engineer_user_id, gap_topic, gap_source, severity)
  VALUES (p_engineer_user_id, p_gap_topic, p_gap_source, p_severity)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_gap_r1908', jsonb_build_object('gap_id', v_id, 'engineer_user_id', p_engineer_user_id, 'topic', p_gap_topic, 'source', p_gap_source, 'severity', p_severity));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_remediation_r1908(p_gap_id uuid)
RETURNS TABLE (
  id uuid,
  gap_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.gap_id, r.action_type, r.taken_at, r.by_email, r.outcome_md
  FROM public.engineer_gap_remediation_log_r1908 r
  WHERE r.gap_id = p_gap_id
  ORDER BY r.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_remediation_r1908(
  p_gap_id uuid,
  p_action_type text,
  p_outcome_md text
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.engineer_gap_remediation_log_r1908(gap_id, action_type, by_email, outcome_md)
  VALUES (p_gap_id, p_action_type, COALESCE(v_email,''), COALESCE(p_outcome_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_remediation_r1908', jsonb_build_object('remediation_id', v_id, 'gap_id', p_gap_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_gap_status_r1908(
  p_gap_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_knowledge_gaps_r1908
  SET status = p_status,
      closed_at = CASE WHEN p_status IN ('closed','escalated') THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_gap_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_gap_status_r1908', jsonb_build_object('gap_id', p_gap_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.gaps_by_severity_r1908()
RETURNS TABLE (
  severity text,
  open_count int,
  in_training_count int,
  closed_count int,
  escalated_count int,
  total_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.severity,
    (COUNT(*) FILTER (WHERE g.status = 'open'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'in_training'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'closed'))::int,
    (COUNT(*) FILTER (WHERE g.status = 'escalated'))::int,
    (COUNT(*))::int
  FROM public.engineer_knowledge_gaps_r1908 g
  GROUP BY g.severity
  ORDER BY CASE g.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_remediations_r1908()
RETURNS TABLE (
  id uuid,
  gap_id uuid,
  gap_topic text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.gap_id, g.gap_topic, r.action_type, r.taken_at, r.by_email
  FROM public.engineer_gap_remediation_log_r1908 r
  LEFT JOIN public.engineer_knowledge_gaps_r1908 g ON g.id = r.gap_id
  ORDER BY r.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_gaps_r1908() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_gap_r1908(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_remediation_r1908(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_remediation_r1908(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_gap_status_r1908(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.gaps_by_severity_r1908() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_remediations_r1908() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_gaps_r1908() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_gap_r1908(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_remediation_r1908(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_remediation_r1908(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_gap_status_r1908(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gaps_by_severity_r1908() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_remediations_r1908() TO authenticated;

COMMIT;
