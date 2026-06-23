BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_escalations_r2374 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_org text NOT NULL,
  escalation_title text NOT NULL,
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  occurred_on date NOT NULL,
  postmortem_due_on date GENERATED ALWAYS AS ((occurred_on + INTERVAL '7 days')::date) STORED,
  postmortem_done_on date,
  postmortem_status text NOT NULL DEFAULT 'pending' CHECK (postmortem_status IN ('pending','done_on_time','done_late','skipped')),
  summary_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_postmortem_insights_r2374 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escalation_id uuid NOT NULL REFERENCES public.engineer_escalations_r2374(id) ON DELETE CASCADE,
  insight_text text NOT NULL,
  category text NOT NULL DEFAULT 'process' CHECK (category IN ('process','training','tooling','policy','other')),
  is_recurring boolean NOT NULL DEFAULT false,
  recurring_theme text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  logged_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_esc_r2374_engineer ON public.engineer_escalations_r2374(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_esc_r2374_status ON public.engineer_escalations_r2374(postmortem_status);
CREATE INDEX IF NOT EXISTS idx_ins_r2374_esc ON public.engineer_postmortem_insights_r2374(escalation_id);
CREATE INDEX IF NOT EXISTS idx_ins_r2374_recurring ON public.engineer_postmortem_insights_r2374(is_recurring) WHERE is_recurring;

ALTER TABLE public.engineer_escalations_r2374 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_postmortem_insights_r2374 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_esc_r2374 ON public.engineer_escalations_r2374;
CREATE POLICY founder_all_esc_r2374 ON public.engineer_escalations_r2374
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ins_r2374 ON public.engineer_postmortem_insights_r2374;
CREATE POLICY founder_all_ins_r2374 ON public.engineer_postmortem_insights_r2374
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_escalations
CREATE OR REPLACE FUNCTION public.list_escalations_r2374()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  customer_org text,
  escalation_title text,
  severity text,
  occurred_on date,
  postmortem_due_on date,
  postmortem_done_on date,
  postmortem_status text,
  days_to_postmortem int,
  insight_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_user_id, p.email AS engineer_email, e.customer_org, e.escalation_title,
    e.severity, e.occurred_on, e.postmortem_due_on, e.postmortem_done_on, e.postmortem_status,
    CASE WHEN e.postmortem_done_on IS NULL THEN NULL
         ELSE (e.postmortem_done_on - e.occurred_on)::int END AS days_to_postmortem,
    (SELECT (COUNT(*))::int FROM public.engineer_postmortem_insights_r2374 i WHERE i.escalation_id = e.id) AS insight_count
  FROM public.engineer_escalations_r2374 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  ORDER BY e.occurred_on DESC, e.severity ASC;
END;
$$;

-- RPC 2: log_escalation
CREATE OR REPLACE FUNCTION public.log_escalation_r2374(
  p_engineer_user_id uuid,
  p_customer_org text,
  p_escalation_title text,
  p_severity text,
  p_occurred_on date,
  p_summary_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_escalations_r2374 (engineer_user_id, customer_org, escalation_title, severity, occurred_on, summary_md)
  VALUES (p_engineer_user_id, p_customer_org, p_escalation_title, COALESCE(p_severity,'p2'), p_occurred_on, COALESCE(p_summary_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_escalation_r2374', jsonb_build_object('escalation_id', v_id, 'engineer_user_id', p_engineer_user_id, 'severity', p_severity));
  RETURN v_id;
END;
$$;

-- RPC 3: mark_postmortem_done
CREATE OR REPLACE FUNCTION public.mark_postmortem_done_r2374(
  p_escalation_id uuid,
  p_done_on date
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_due date; v_occurred date; v_done date; v_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_done := COALESCE(p_done_on, CURRENT_DATE);
  SELECT postmortem_due_on, occurred_on INTO v_due, v_occurred
  FROM public.engineer_escalations_r2374 WHERE id = p_escalation_id;
  IF v_occurred IS NULL THEN RAISE EXCEPTION 'escalation not found'; END IF;
  v_status := CASE WHEN v_done <= v_due THEN 'done_on_time' ELSE 'done_late' END;
  UPDATE public.engineer_escalations_r2374
  SET postmortem_done_on = v_done, postmortem_status = v_status, updated_at = now()
  WHERE id = p_escalation_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_postmortem_done_r2374', jsonb_build_object('escalation_id', p_escalation_id, 'status', v_status, 'done_on', v_done));
END;
$$;

-- RPC 4: log_insight
CREATE OR REPLACE FUNCTION public.log_insight_r2374(
  p_escalation_id uuid,
  p_insight_text text,
  p_category text,
  p_is_recurring boolean,
  p_recurring_theme text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_postmortem_insights_r2374 (escalation_id, insight_text, category, is_recurring, recurring_theme, logged_by_user_id)
  VALUES (p_escalation_id, p_insight_text, COALESCE(p_category,'process'), COALESCE(p_is_recurring,false), p_recurring_theme, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_insight_r2374', jsonb_build_object('insight_id', v_id, 'escalation_id', p_escalation_id, 'recurring', p_is_recurring));
  RETURN v_id;
END;
$$;

-- RPC 5: overdue_postmortems
CREATE OR REPLACE FUNCTION public.overdue_postmortems_r2374()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  customer_org text,
  escalation_title text,
  severity text,
  occurred_on date,
  postmortem_due_on date,
  days_overdue int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.engineer_user_id, p.email, e.customer_org, e.escalation_title, e.severity,
    e.occurred_on, e.postmortem_due_on,
    GREATEST(0, (CURRENT_DATE - e.postmortem_due_on))::int AS days_overdue
  FROM public.engineer_escalations_r2374 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  WHERE e.postmortem_status = 'pending'
    AND e.postmortem_due_on < CURRENT_DATE
  ORDER BY e.postmortem_due_on ASC;
END;
$$;

-- RPC 6: recurring_themes
CREATE OR REPLACE FUNCTION public.recurring_themes_r2374()
RETURNS TABLE (
  recurring_theme text,
  occurrence_count int,
  engineer_count int,
  last_logged_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.recurring_theme,
    (COUNT(*))::int AS occurrence_count,
    (COUNT(DISTINCT e.engineer_user_id))::int AS engineer_count,
    MAX(i.logged_at) AS last_logged_at
  FROM public.engineer_postmortem_insights_r2374 i
  JOIN public.engineer_escalations_r2374 e ON e.id = i.escalation_id
  WHERE i.is_recurring = true AND i.recurring_theme IS NOT NULL
  GROUP BY i.recurring_theme
  ORDER BY occurrence_count DESC, last_logged_at DESC;
END;
$$;

-- RPC 7: engineer_cadence_summary
CREATE OR REPLACE FUNCTION public.engineer_cadence_summary_r2374()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_escalations int,
  on_time_postmortems int,
  late_postmortems int,
  pending_postmortems int,
  skipped_postmortems int,
  on_time_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_user_id,
    MAX(p.email) AS engineer_email,
    (COUNT(*))::int AS total_escalations,
    (COUNT(*) FILTER (WHERE e.postmortem_status='done_on_time'))::int AS on_time_postmortems,
    (COUNT(*) FILTER (WHERE e.postmortem_status='done_late'))::int AS late_postmortems,
    (COUNT(*) FILTER (WHERE e.postmortem_status='pending'))::int AS pending_postmortems,
    (COUNT(*) FILTER (WHERE e.postmortem_status='skipped'))::int AS skipped_postmortems,
    ROUND(
      (COUNT(*) FILTER (WHERE e.postmortem_status='done_on_time'))::numeric
      / NULLIF(COUNT(*),0)::numeric * 100.0, 1
    ) AS on_time_pct
  FROM public.engineer_escalations_r2374 e
  LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
  GROUP BY e.engineer_user_id
  ORDER BY on_time_pct ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_escalations_r2374() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_escalation_r2374(uuid, text, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_postmortem_done_r2374(uuid, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_insight_r2374(uuid, text, text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_postmortems_r2374() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recurring_themes_r2374() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.engineer_cadence_summary_r2374() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_escalations_r2374() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_escalation_r2374(uuid, text, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_postmortem_done_r2374(uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_insight_r2374(uuid, text, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_postmortems_r2374() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recurring_themes_r2374() TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineer_cadence_summary_r2374() TO authenticated;

COMMIT;