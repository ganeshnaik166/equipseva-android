BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_mode_switch_tracker_r2082 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mode_label text NOT NULL CHECK (mode_label IN ('founder_mode','manager_mode','strategic_mode','execution_mode','recovery')),
  started_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 0,
  triggered_by text NOT NULL CHECK (triggered_by IN ('planned','crisis','customer_call','board_call','team_check')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_mode_outcome_log_r2082 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  switch_id uuid NOT NULL REFERENCES public.founder_mode_switch_tracker_r2082(id) ON DELETE CASCADE,
  outcome_type text NOT NULL CHECK (outcome_type IN ('breakthrough','decision_made','blocker_identified','relationship_built','energy_drained')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_mode_switch_tracker_r2082 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_mode_outcome_log_r2082 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_switches_r2082 ON public.founder_mode_switch_tracker_r2082;
CREATE POLICY founder_all_switches_r2082 ON public.founder_mode_switch_tracker_r2082
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_outcomes_r2082 ON public.founder_mode_outcome_log_r2082;
CREATE POLICY founder_all_outcomes_r2082 ON public.founder_mode_outcome_log_r2082
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_switches_r2082()
RETURNS TABLE (
  id uuid,
  mode_label text,
  started_at timestamptz,
  duration_minutes int,
  triggered_by text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.mode_label, s.started_at, s.duration_minutes, s.triggered_by, s.status, s.captured_at
    FROM public.founder_mode_switch_tracker_r2082 s
    ORDER BY s.started_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_switch_r2082(
  p_mode_label text,
  p_duration_minutes int,
  p_triggered_by text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_mode_switch_tracker_r2082(mode_label, duration_minutes, triggered_by)
  VALUES (p_mode_label, p_duration_minutes, p_triggered_by)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_switch_r2082',
    jsonb_build_object('switch_id', v_id, 'mode_label', p_mode_label, 'duration_minutes', p_duration_minutes, 'triggered_by', p_triggered_by));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2082(p_switch_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  switch_id uuid,
  outcome_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.switch_id, o.outcome_type, o.taken_at, o.by_email, o.notes_md
    FROM public.founder_mode_outcome_log_r2082 o
    WHERE p_switch_id IS NULL OR o.switch_id = p_switch_id
    ORDER BY o.taken_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_outcome_r2082(
  p_switch_id uuid,
  p_outcome_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_mode_outcome_log_r2082(switch_id, outcome_type, by_email, notes_md)
  VALUES (p_switch_id, p_outcome_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outcome_r2082',
    jsonb_build_object('outcome_id', v_id, 'switch_id', p_switch_id, 'outcome_type', p_outcome_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2082(
  p_switch_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_mode_switch_tracker_r2082
  SET status = p_status, updated_at = now()
  WHERE id = p_switch_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2082',
    jsonb_build_object('switch_id', p_switch_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.mode_distribution_r2082()
RETURNS TABLE (
  mode_label text,
  switch_count bigint,
  total_minutes bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.mode_label, COUNT(*)::bigint AS switch_count, COALESCE(SUM(s.duration_minutes),0)::bigint AS total_minutes
    FROM public.founder_mode_switch_tracker_r2082 s
    GROUP BY s.mode_label
    ORDER BY total_minutes DESC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_outcomes_r2082()
RETURNS TABLE (
  id uuid,
  switch_id uuid,
  outcome_type text,
  taken_at timestamptz,
  by_email text,
  mode_label text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.switch_id, o.outcome_type, o.taken_at, o.by_email, s.mode_label
    FROM public.founder_mode_outcome_log_r2082 o
    JOIN public.founder_mode_switch_tracker_r2082 s ON s.id = o.switch_id
    ORDER BY o.taken_at DESC
    LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_switches_r2082() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_switch_r2082(text,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2082(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outcome_r2082(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2082(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mode_distribution_r2082() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_outcomes_r2082() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_switches_r2082() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_switch_r2082(text,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2082(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outcome_r2082(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2082(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mode_distribution_r2082() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_outcomes_r2082() TO authenticated;

COMMIT;
