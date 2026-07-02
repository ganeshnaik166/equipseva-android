BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_operating_cadences_r1934 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_label text NOT NULL,
  cadence_frequency text NOT NULL CHECK (cadence_frequency IN ('daily','weekly','biweekly','monthly','quarterly','annual')),
  target_dow text,
  target_time text,
  last_executed_at timestamptz,
  next_due_at timestamptz,
  status text NOT NULL DEFAULT 'on_schedule' CHECK (status IN ('on_schedule','due_soon','overdue','paused','abandoned')),
  owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_cadence_execution_log_r1934 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cadence_id uuid NOT NULL REFERENCES public.founder_operating_cadences_r1934(id) ON DELETE CASCADE,
  executed_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL CHECK (outcome IN ('completed','skipped','rescheduled','blocked')),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_operating_cadences_r1934 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_cadence_execution_log_r1934 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cadences_r1934 ON public.founder_operating_cadences_r1934;
CREATE POLICY founder_all_cadences_r1934 ON public.founder_operating_cadences_r1934
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_exec_log_r1934 ON public.founder_cadence_execution_log_r1934;
CREATE POLICY founder_all_exec_log_r1934 ON public.founder_cadence_execution_log_r1934
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_cadences_r1934()
RETURNS SETOF public.founder_operating_cadences_r1934
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_operating_cadences_r1934 ORDER BY next_due_at NULLS LAST, created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_cadence_r1934(
  p_label text,
  p_frequency text,
  p_target_dow text,
  p_target_time text,
  p_next_due_at timestamptz,
  p_owner_email text
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
  INSERT INTO public.founder_operating_cadences_r1934(cadence_label, cadence_frequency, target_dow, target_time, next_due_at, owner_email)
  VALUES (p_label, p_frequency, p_target_dow, p_target_time, p_next_due_at, p_owner_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cadence_r1934', jsonb_build_object('id', v_id, 'label', p_label, 'frequency', p_frequency), now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_executions_r1934(p_cadence_id uuid)
RETURNS SETOF public.founder_cadence_execution_log_r1934
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_cadence_execution_log_r1934 WHERE cadence_id = p_cadence_id ORDER BY executed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_execution_r1934(
  p_cadence_id uuid,
  p_outcome text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_cadence_execution_log_r1934(cadence_id, outcome, by_email, notes_md)
  VALUES (p_cadence_id, p_outcome, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  UPDATE public.founder_operating_cadences_r1934
     SET last_executed_at = now(), updated_at = now()
   WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_execution_r1934', jsonb_build_object('id', v_id, 'cadence_id', p_cadence_id, 'outcome', p_outcome), now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1934(p_cadence_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_operating_cadences_r1934
     SET status = p_status, updated_at = now()
   WHERE id = p_cadence_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1934', jsonb_build_object('id', p_cadence_id, 'status', p_status), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.due_or_overdue_r1934()
RETURNS SETOF public.founder_operating_cadences_r1934
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_operating_cadences_r1934
     WHERE status IN ('due_soon','overdue')
        OR (next_due_at IS NOT NULL AND next_due_at <= now() + interval '3 days')
     ORDER BY next_due_at NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_executions_r1934(p_limit int DEFAULT 50)
RETURNS SETOF public.founder_cadence_execution_log_r1934
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_cadence_execution_log_r1934 ORDER BY executed_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cadences_r1934() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cadence_r1934(text, text, text, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_executions_r1934(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_execution_r1934(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1934(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.due_or_overdue_r1934() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_executions_r1934(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cadences_r1934() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cadence_r1934(text, text, text, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_executions_r1934(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_execution_r1934(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1934(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.due_or_overdue_r1934() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_executions_r1934(int) TO authenticated;

COMMIT;
