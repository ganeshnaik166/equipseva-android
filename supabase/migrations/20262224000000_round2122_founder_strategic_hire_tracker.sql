BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_hire_tracker_r2122 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_label text NOT NULL CHECK (role_label IN ('vp_engineering','vp_operations','vp_sales','cfo','coo','cto','cmo')),
  candidate_name text NOT NULL,
  target_close_date date,
  status text NOT NULL DEFAULT 'sourcing' CHECK (status IN ('sourcing','screening','interview','offer','closed_won','closed_lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_strategic_hire_action_log_r2122 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_id uuid NOT NULL REFERENCES public.founder_strategic_hire_tracker_r2122(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('sourced','interviewed','offered','closed_won','closed_lost','withdrawn')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_hire_tracker_r2122 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_strategic_hire_action_log_r2122 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hire_tracker_r2122 ON public.founder_strategic_hire_tracker_r2122;
CREATE POLICY founder_all_hire_tracker_r2122 ON public.founder_strategic_hire_tracker_r2122
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hire_action_log_r2122 ON public.founder_strategic_hire_action_log_r2122;
CREATE POLICY founder_all_hire_action_log_r2122 ON public.founder_strategic_hire_action_log_r2122
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_hires
DROP FUNCTION IF EXISTS public.founder_strategic_hire_list_hires_r2122();
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_list_hires_r2122()
RETURNS TABLE (
  id uuid,
  role_label text,
  candidate_name text,
  target_close_date date,
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
  SELECT t.id, t.role_label, t.candidate_name, t.target_close_date, t.status, t.captured_at
  FROM public.founder_strategic_hire_tracker_r2122 t
  ORDER BY t.captured_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_hire
DROP FUNCTION IF EXISTS public.founder_strategic_hire_log_hire_r2122(text, text, date, text);
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_log_hire_r2122(
  p_role_label text,
  p_candidate_name text,
  p_target_close_date date,
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
  INSERT INTO public.founder_strategic_hire_tracker_r2122 (role_label, candidate_name, target_close_date, status)
  VALUES (p_role_label, p_candidate_name, p_target_close_date, COALESCE(p_status, 'sourcing'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_strategic_hire_log_hire_r2122',
    jsonb_build_object('hire_id', v_id, 'role_label', p_role_label, 'candidate_name', p_candidate_name));

  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.founder_strategic_hire_list_actions_r2122(uuid);
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_list_actions_r2122(p_hire_id uuid)
RETURNS TABLE (
  id uuid,
  hire_id uuid,
  action_type text,
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
  SELECT a.id, a.hire_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_strategic_hire_action_log_r2122 a
  WHERE p_hire_id IS NULL OR a.hire_id = p_hire_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.founder_strategic_hire_log_action_r2122(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_log_action_r2122(
  p_hire_id uuid,
  p_action_type text,
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
  INSERT INTO public.founder_strategic_hire_action_log_r2122 (hire_id, action_type, by_email, notes_md)
  VALUES (p_hire_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_strategic_hire_log_action_r2122',
    jsonb_build_object('action_id', v_id, 'hire_id', p_hire_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.founder_strategic_hire_mark_status_r2122(uuid, text);
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_mark_status_r2122(
  p_hire_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_strategic_hire_tracker_r2122
  SET status = p_status, updated_at = now()
  WHERE id = p_hire_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_strategic_hire_mark_status_r2122',
    jsonb_build_object('hire_id', p_hire_id, 'status', p_status));
END;
$$;

-- RPC 6: active_pipeline
DROP FUNCTION IF EXISTS public.founder_strategic_hire_active_pipeline_r2122();
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_active_pipeline_r2122()
RETURNS TABLE (
  status text,
  hire_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status, COUNT(*)::bigint AS hire_count
  FROM public.founder_strategic_hire_tracker_r2122 t
  WHERE t.status IN ('sourcing','screening','interview','offer')
  GROUP BY t.status
  ORDER BY hire_count DESC;
END;
$$;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.founder_strategic_hire_recent_actions_r2122();
CREATE OR REPLACE FUNCTION public.founder_strategic_hire_recent_actions_r2122()
RETURNS TABLE (
  action_id uuid,
  hire_id uuid,
  candidate_name text,
  role_label text,
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
  SELECT a.id AS action_id, a.hire_id, t.candidate_name, t.role_label, a.action_type, a.taken_at, a.by_email
  FROM public.founder_strategic_hire_action_log_r2122 a
  JOIN public.founder_strategic_hire_tracker_r2122 t ON t.id = a.hire_id
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_list_hires_r2122() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_log_hire_r2122(text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_list_actions_r2122(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_log_action_r2122(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_mark_status_r2122(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_active_pipeline_r2122() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_strategic_hire_recent_actions_r2122() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_list_hires_r2122() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_log_hire_r2122(text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_list_actions_r2122(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_log_action_r2122(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_mark_status_r2122(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_active_pipeline_r2122() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_strategic_hire_recent_actions_r2122() TO authenticated;

COMMIT;
