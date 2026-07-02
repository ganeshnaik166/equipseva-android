BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_bench_hire_velocity_r2132 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  period_label text NOT NULL,
  hires_planned int NOT NULL DEFAULT 0,
  hires_actual int NOT NULL DEFAULT 0,
  hire_pace_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('on_track','ahead','behind','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_hire_velocity_action_log_r2132 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.engineer_bench_hire_velocity_r2132(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('accelerated','slowed','escalated','closed','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_bench_hire_velocity_r2132 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_hire_velocity_action_log_r2132 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_velocity_founder_r2132 ON public.engineer_bench_hire_velocity_r2132;
CREATE POLICY p_velocity_founder_r2132 ON public.engineer_bench_hire_velocity_r2132
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_action_log_founder_r2132 ON public.engineer_hire_velocity_action_log_r2132;
CREATE POLICY p_action_log_founder_r2132 ON public.engineer_hire_velocity_action_log_r2132
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_velocities_r2132()
RETURNS SETOF public.engineer_bench_hire_velocity_r2132
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_hire_velocity_r2132 ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_velocity_r2132(
  p_region text,
  p_period text,
  p_planned int,
  p_actual int,
  p_pace numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_bench_hire_velocity_r2132 (region_label, period_label, hires_planned, hires_actual, hire_pace_pct, status)
  VALUES (p_region, p_period, p_planned, p_actual, p_pace, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_velocity_r2132',
    jsonb_build_object('id', v_id, 'region', p_region, 'period', p_period, 'status', p_status), now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2132(p_velocity_id uuid)
RETURNS SETOF public.engineer_hire_velocity_action_log_r2132
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_hire_velocity_action_log_r2132
    WHERE velocity_id = p_velocity_id
    ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2132(
  p_velocity_id uuid,
  p_action_type text,
  p_by_email text,
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
  INSERT INTO public.engineer_hire_velocity_action_log_r2132 (velocity_id, action_type, by_email, notes_md)
  VALUES (p_velocity_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2132',
    jsonb_build_object('id', v_id, 'velocity_id', p_velocity_id, 'action_type', p_action_type), now());

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2132(p_velocity_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_bench_hire_velocity_r2132
  SET status = p_status, updated_at = now()
  WHERE id = p_velocity_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2132',
    jsonb_build_object('id', p_velocity_id, 'status', p_status), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.behind_regions_r2132()
RETURNS SETOF public.engineer_bench_hire_velocity_r2132
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_hire_velocity_r2132
    WHERE status IN ('behind','critical')
    ORDER BY captured_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2132()
RETURNS SETOF public.engineer_hire_velocity_action_log_r2132
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_hire_velocity_action_log_r2132
    ORDER BY taken_at DESC
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_velocities_r2132() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_velocity_r2132(text,text,int,int,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2132(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2132(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2132(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.behind_regions_r2132() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2132() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_velocities_r2132() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_velocity_r2132(text,text,int,int,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2132(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2132(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2132(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.behind_regions_r2132() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2132() TO authenticated;

COMMIT;
