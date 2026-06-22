BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_pr_activity_log_r2110 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_label text NOT NULL,
  activity_type text NOT NULL CHECK (activity_type IN ('press_release','interview','podcast','article','social_post','event_appearance')),
  publication text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','published','declined','cancelled')),
  activity_date date,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_pr_action_log_r2110 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL REFERENCES public.founder_pr_activity_log_r2110(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('planned','published','declined','follow_up','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL DEFAULT '',
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_pr_activity_log_r2110 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_pr_action_log_r2110 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pr_act_r2110 ON public.founder_pr_activity_log_r2110;
CREATE POLICY founder_all_pr_act_r2110 ON public.founder_pr_activity_log_r2110
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pr_action_r2110 ON public.founder_pr_action_log_r2110;
CREATE POLICY founder_all_pr_action_r2110 ON public.founder_pr_action_log_r2110
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_activities
CREATE OR REPLACE FUNCTION public.list_pr_activities_r2110()
RETURNS TABLE (
  id uuid,
  activity_label text,
  activity_type text,
  publication text,
  status text,
  activity_date date,
  captured_at timestamptz,
  action_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.activity_label, a.activity_type, a.publication, a.status, a.activity_date, a.captured_at,
    (SELECT (COUNT(*))::int FROM public.founder_pr_action_log_r2110 x WHERE x.activity_id = a.id) AS action_count
  FROM public.founder_pr_activity_log_r2110 a
  ORDER BY COALESCE(a.activity_date, a.captured_at::date) DESC, a.captured_at DESC;
END;
$$;

-- RPC 2: log_activity
CREATE OR REPLACE FUNCTION public.log_pr_activity_r2110(
  p_activity_label text,
  p_activity_type text,
  p_publication text,
  p_status text,
  p_activity_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_pr_activity_log_r2110 (activity_label, activity_type, publication, status, activity_date)
  VALUES (p_activity_label, p_activity_type, COALESCE(p_publication,''), COALESCE(p_status,'planned'), p_activity_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pr_activity_r2110',
    jsonb_build_object('activity_id', v_id, 'activity_label', p_activity_label, 'activity_type', p_activity_type, 'status', p_status));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_pr_actions_r2110(p_activity_id uuid)
RETURNS TABLE (
  id uuid,
  activity_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.activity_id, x.action_type, x.taken_at, x.by_email, x.notes_md
  FROM public.founder_pr_action_log_r2110 x
  WHERE x.activity_id = p_activity_id
  ORDER BY x.taken_at DESC;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_pr_action_r2110(
  p_activity_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_pr_action_log_r2110 (activity_id, action_type, by_email, notes_md)
  VALUES (p_activity_id, p_action_type, COALESCE(p_by_email, COALESCE(auth.jwt()->>'email','')), COALESCE(p_notes_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pr_action_r2110',
    jsonb_build_object('action_id', v_id, 'activity_id', p_activity_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_pr_status_r2110(
  p_activity_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('planned','active','published','declined','cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.founder_pr_activity_log_r2110
  SET status = p_status, updated_at = now()
  WHERE id = p_activity_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_pr_status_r2110',
    jsonb_build_object('activity_id', p_activity_id, 'status', p_status));
END;
$$;

-- RPC 6: recent_published
CREATE OR REPLACE FUNCTION public.recent_published_pr_r2110()
RETURNS TABLE (
  id uuid,
  activity_label text,
  activity_type text,
  publication text,
  activity_date date,
  days_ago int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.activity_label, a.activity_type, a.publication, a.activity_date,
    GREATEST(0, (CURRENT_DATE - COALESCE(a.activity_date, a.captured_at::date)))::int AS days_ago
  FROM public.founder_pr_activity_log_r2110 a
  WHERE a.status = 'published'
  ORDER BY COALESCE(a.activity_date, a.captured_at::date) DESC
  LIMIT 50;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_pr_actions_r2110()
RETURNS TABLE (
  id uuid,
  activity_id uuid,
  activity_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.activity_id, a.activity_label, x.action_type, x.taken_at, x.by_email
  FROM public.founder_pr_action_log_r2110 x
  JOIN public.founder_pr_activity_log_r2110 a ON a.id = x.activity_id
  ORDER BY x.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pr_activities_r2110() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pr_activity_r2110(text, text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pr_actions_r2110(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pr_action_r2110(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_pr_status_r2110(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_published_pr_r2110() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_pr_actions_r2110() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pr_activities_r2110() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pr_activity_r2110(text, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pr_actions_r2110(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pr_action_r2110(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_pr_status_r2110(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_published_pr_r2110() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_pr_actions_r2110() TO authenticated;

COMMIT;
