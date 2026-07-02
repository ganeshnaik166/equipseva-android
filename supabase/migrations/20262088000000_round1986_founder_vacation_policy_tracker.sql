BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_vacation_policy_r1986 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year int NOT NULL,
  allocated_days int NOT NULL DEFAULT 0,
  taken_days int NOT NULL DEFAULT 0,
  planned_days int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','behind','exceeded','zeroed')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_vacation_log_r1986 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL REFERENCES public.founder_vacation_policy_r1986(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('planned','taken','cancelled','rescheduled','declined')),
  taken_at date,
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_vacation_policy_r1986 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vacation_log_r1986 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_policy_r1986 ON public.founder_vacation_policy_r1986;
CREATE POLICY founder_only_policy_r1986 ON public.founder_vacation_policy_r1986
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_log_r1986 ON public.founder_vacation_log_r1986;
CREATE POLICY founder_only_log_r1986 ON public.founder_vacation_log_r1986
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_policies_r1986()
RETURNS SETOF public.founder_vacation_policy_r1986
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vacation_policy_r1986 ORDER BY year DESC, recorded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_policy_r1986(
  p_year int,
  p_allocated int,
  p_taken int,
  p_planned int,
  p_status text
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
  INSERT INTO public.founder_vacation_policy_r1986(year, allocated_days, taken_days, planned_days, status)
  VALUES (p_year, p_allocated, p_taken, p_planned, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_policy_r1986',
    jsonb_build_object('policy_id', v_id, 'year', p_year, 'allocated', p_allocated));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1986(p_policy_id uuid)
RETURNS SETOF public.founder_vacation_log_r1986
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vacation_log_r1986
    WHERE policy_id = p_policy_id
    ORDER BY created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1986(
  p_policy_id uuid,
  p_action_type text,
  p_taken_at date,
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
  INSERT INTO public.founder_vacation_log_r1986(policy_id, action_type, taken_at, by_email, notes_md)
  VALUES (p_policy_id, p_action_type, p_taken_at, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1986',
    jsonb_build_object('log_id', v_id, 'policy_id', p_policy_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1986(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_vacation_policy_r1986
  SET status = p_status, last_reviewed_at = now(), updated_at = now()
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1986',
    jsonb_build_object('policy_id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.current_year_status_r1986()
RETURNS SETOF public.founder_vacation_policy_r1986
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vacation_policy_r1986
    WHERE year = EXTRACT(YEAR FROM now())::int
    ORDER BY recorded_at DESC
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1986(p_limit int DEFAULT 25)
RETURNS SETOF public.founder_vacation_log_r1986
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_vacation_log_r1986
    ORDER BY created_at DESC
    LIMIT COALESCE(p_limit, 25);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_policies_r1986() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_policy_r1986(int,int,int,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1986(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1986(uuid,text,date,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1986(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_year_status_r1986() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1986(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_policies_r1986() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_policy_r1986(int,int,int,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1986(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1986(uuid,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1986(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_year_status_r1986() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1986(int) TO authenticated;

COMMIT;
