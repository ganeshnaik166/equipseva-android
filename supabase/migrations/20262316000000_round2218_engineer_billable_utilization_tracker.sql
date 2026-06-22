BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_billable_utilization_r2218 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  week_start date NOT NULL,
  available_hours numeric(6,2) NOT NULL DEFAULT 40,
  billable_hours numeric(6,2) NOT NULL DEFAULT 0,
  utilization_pct numeric(5,2) GENERATED ALWAYS AS (CASE WHEN available_hours > 0 THEN (billable_hours / available_hours) * 100 ELSE 0 END) STORED,
  target_pct numeric(5,2) NOT NULL DEFAULT 70,
  meets_target boolean GENERATED ALWAYS AS (CASE WHEN available_hours > 0 AND (billable_hours / available_hours) * 100 >= 70 THEN true ELSE false END) STORED,
  jobs_completed int NOT NULL DEFAULT 0,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(engineer_user_id, week_start)
);

CREATE TABLE IF NOT EXISTS public.engineer_utilization_actions_r2218 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  utilization_id uuid NOT NULL REFERENCES public.engineer_billable_utilization_r2218(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coaching','reassign','warning','recognition','review')),
  action_note text NOT NULL,
  taken_by uuid REFERENCES public.profiles(id),
  taken_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_billable_utilization_r2218 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_utilization_actions_r2218 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_billable_utilization_r2218;
CREATE POLICY founder_all ON public.engineer_billable_utilization_r2218 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_utilization_actions_r2218;
CREATE POLICY founder_all ON public.engineer_utilization_actions_r2218 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_engineer_utilization_r2218()
RETURNS SETOF public.engineer_billable_utilization_r2218
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_billable_utilization_r2218 ORDER BY week_start DESC, utilization_pct DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_engineer_utilization_r2218()
RETURNS SETOF public.engineer_utilization_actions_r2218
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_utilization_actions_r2218 ORDER BY taken_at DESC LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.top_engineer_utilization_r2218()
RETURNS TABLE(engineer_name text, week_start date, utilization_pct numeric, billable_hours numeric, available_hours numeric, jobs_completed int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.engineer_name, u.week_start, u.utilization_pct, u.billable_hours, u.available_hours, u.jobs_completed
    FROM public.engineer_billable_utilization_r2218 u
    WHERE u.week_start = (SELECT MAX(week_start) FROM public.engineer_billable_utilization_r2218)
    ORDER BY u.utilization_pct DESC LIMIT 10;
END; $$;

CREATE OR REPLACE FUNCTION public.bottom_engineer_utilization_r2218()
RETURNS TABLE(engineer_name text, week_start date, utilization_pct numeric, billable_hours numeric, available_hours numeric, jobs_completed int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.engineer_name, u.week_start, u.utilization_pct, u.billable_hours, u.available_hours, u.jobs_completed
    FROM public.engineer_billable_utilization_r2218 u
    WHERE u.week_start = (SELECT MAX(week_start) FROM public.engineer_billable_utilization_r2218)
    ORDER BY u.utilization_pct ASC LIMIT 10;
END; $$;

CREATE OR REPLACE FUNCTION public.log_engineer_utilization_r2218(p_engineer_user_id uuid, p_engineer_name text, p_week_start date, p_available_hours numeric, p_billable_hours numeric, p_jobs_completed int, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_billable_utilization_r2218(engineer_user_id, engineer_name, week_start, available_hours, billable_hours, jobs_completed, notes)
  VALUES (p_engineer_user_id, p_engineer_name, p_week_start, p_available_hours, p_billable_hours, p_jobs_completed, p_notes)
  ON CONFLICT (engineer_user_id, week_start) DO UPDATE SET billable_hours = EXCLUDED.billable_hours, available_hours = EXCLUDED.available_hours, jobs_completed = EXCLUDED.jobs_completed, notes = EXCLUDED.notes
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2218_log', jsonb_build_object('engineer', p_engineer_name, 'week', p_week_start, 'billable', p_billable_hours));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_engineer_utilization_r2218(p_utilization_id uuid, p_action_type text, p_action_note text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_utilization_actions_r2218(utilization_id, action_type, action_note, taken_by)
  VALUES (p_utilization_id, p_action_type, p_action_note, auth.uid()) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2218_log_action', jsonb_build_object('utilization_id', p_utilization_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_engineer_utilization_r2218(p_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_billable_utilization_r2218 SET notes = p_notes WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2218_mark_status', jsonb_build_object('id', p_id));
END; $$;

CREATE OR REPLACE FUNCTION public.aggregate_engineer_utilization_r2218()
RETURNS TABLE(total_engineers int, meeting_target int, below_target int, avg_utilization numeric, total_billable_hours numeric, total_available_hours numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (COUNT(*))::int,
      (COUNT(*) FILTER (WHERE meets_target = true))::int,
      (COUNT(*) FILTER (WHERE meets_target = false))::int,
      COALESCE(AVG(utilization_pct), 0)::numeric,
      COALESCE(SUM(billable_hours), 0)::numeric,
      COALESCE(SUM(available_hours), 0)::numeric
    FROM public.engineer_billable_utilization_r2218
    WHERE week_start = (SELECT MAX(week_start) FROM public.engineer_billable_utilization_r2218);
END; $$;

REVOKE ALL ON FUNCTION public.list_engineer_utilization_r2218() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_engineer_utilization_r2218() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_engineer_utilization_r2218() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.bottom_engineer_utilization_r2218() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_engineer_utilization_r2218(uuid, text, date, numeric, numeric, int, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_engineer_utilization_r2218(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_engineer_utilization_r2218(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_engineer_utilization_r2218() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_engineer_utilization_r2218() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_engineer_utilization_r2218() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engineer_utilization_r2218() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bottom_engineer_utilization_r2218() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engineer_utilization_r2218(uuid, text, date, numeric, numeric, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_engineer_utilization_r2218(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_engineer_utilization_r2218(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_engineer_utilization_r2218() TO authenticated;

COMMIT;
