BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_burndown_velocity_r2034 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  ships_target int NOT NULL DEFAULT 0,
  ships_actual int NOT NULL DEFAULT 0,
  batches_target int NOT NULL DEFAULT 0,
  batches_actual int NOT NULL DEFAULT 0,
  velocity_score numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','ahead','behind','concerning')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_velocity_action_log_r2034 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.founder_burndown_velocity_r2034(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('momentum_celebrated','blocker_identified','acceleration_added','recalibrated','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_burndown_velocity_r2034 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_velocity_action_log_r2034 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_velocity_r2034 ON public.founder_burndown_velocity_r2034;
CREATE POLICY founder_all_velocity_r2034 ON public.founder_burndown_velocity_r2034
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_velocity_actions_r2034 ON public.founder_velocity_action_log_r2034;
CREATE POLICY founder_all_velocity_actions_r2034 ON public.founder_velocity_action_log_r2034
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_velocities_r2034()
RETURNS SETOF public.founder_burndown_velocity_r2034
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_burndown_velocity_r2034 ORDER BY captured_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_velocity_r2034(
  p_quarter_label text,
  p_ships_target int,
  p_ships_actual int,
  p_batches_target int,
  p_batches_actual int,
  p_velocity_score numeric,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_burndown_velocity_r2034(quarter_label, ships_target, ships_actual, batches_target, batches_actual, velocity_score, status)
    VALUES (p_quarter_label, p_ships_target, p_ships_actual, p_batches_target, p_batches_actual, p_velocity_score, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_velocity_r2034', jsonb_build_object('id', v_id, 'quarter', p_quarter_label, 'status', p_status));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2034(p_velocity_id uuid)
RETURNS SETOF public.founder_velocity_action_log_r2034
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_velocity_action_log_r2034 WHERE velocity_id = p_velocity_id ORDER BY taken_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2034(
  p_velocity_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_velocity_action_log_r2034(velocity_id, action_type, by_email, notes_md)
    VALUES (p_velocity_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2034', jsonb_build_object('id', v_id, 'velocity_id', p_velocity_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2034(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_burndown_velocity_r2034 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2034', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.current_velocity_r2034()
RETURNS SETOF public.founder_burndown_velocity_r2034
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_burndown_velocity_r2034 ORDER BY captured_at DESC LIMIT 1;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2034(p_limit int DEFAULT 25)
RETURNS SETOF public.founder_velocity_action_log_r2034
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_velocity_action_log_r2034 ORDER BY taken_at DESC LIMIT GREATEST(p_limit, 1);
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_velocities_r2034() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_velocity_r2034(text,int,int,int,int,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2034(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2034(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2034(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_velocity_r2034() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2034(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_velocities_r2034() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_velocity_r2034(text,int,int,int,int,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2034(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2034(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2034(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_velocity_r2034() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2034(int) TO authenticated;

COMMIT;
