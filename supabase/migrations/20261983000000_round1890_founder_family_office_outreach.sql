BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_family_office_outreach_r1890 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_office_name text NOT NULL,
  family_office_size_aum_rupees bigint,
  intro_path_md text,
  status text NOT NULL DEFAULT 'unconnected' CHECK (status IN ('unconnected','researching','intro_made','in_dialog','closed','passed')),
  first_outreach_at timestamptz,
  last_touch_at timestamptz,
  expected_check_rupees bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_family_office_intro_log_r1890 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.founder_family_office_outreach_r1890(id) ON DELETE CASCADE,
  intro_via text NOT NULL CHECK (intro_via IN ('warm','cold','event','referral')),
  intro_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_family_office_outreach_r1890 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_family_office_intro_log_r1890 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_outreach_r1890 ON public.founder_family_office_outreach_r1890;
CREATE POLICY p_founder_all_outreach_r1890 ON public.founder_family_office_outreach_r1890
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_intro_log_r1890 ON public.founder_family_office_intro_log_r1890;
CREATE POLICY p_founder_all_intro_log_r1890 ON public.founder_family_office_intro_log_r1890
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_family_office_targets_r1890()
RETURNS TABLE (
  id uuid,
  family_office_name text,
  family_office_size_aum_rupees bigint,
  intro_path_md text,
  status text,
  first_outreach_at timestamptz,
  last_touch_at timestamptz,
  expected_check_rupees bigint,
  intro_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.family_office_name,
    t.family_office_size_aum_rupees,
    t.intro_path_md,
    t.status,
    t.first_outreach_at,
    t.last_touch_at,
    t.expected_check_rupees,
    (SELECT COUNT(*) FROM public.founder_family_office_intro_log_r1890 l WHERE l.target_id = t.id)::int AS intro_count,
    t.created_at
  FROM public.founder_family_office_outreach_r1890 t
  ORDER BY COALESCE(t.last_touch_at, t.created_at) DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_family_office_target_r1890(
  p_name text,
  p_aum_rupees bigint,
  p_intro_path_md text,
  p_expected_check_rupees bigint
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
  INSERT INTO public.founder_family_office_outreach_r1890(family_office_name, family_office_size_aum_rupees, intro_path_md, expected_check_rupees)
  VALUES (p_name, p_aum_rupees, p_intro_path_md, p_expected_check_rupees)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_family_office_target_r1890',
    jsonb_build_object('id', v_id, 'name', p_name, 'aum', p_aum_rupees, 'expected_check', p_expected_check_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_family_office_intros_r1890(p_target_id uuid)
RETURNS TABLE (
  id uuid,
  target_id uuid,
  intro_via text,
  intro_at timestamptz,
  by_email text,
  response text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.target_id, l.intro_via, l.intro_at, l.by_email, l.response, l.created_at
  FROM public.founder_family_office_intro_log_r1890 l
  WHERE p_target_id IS NULL OR l.target_id = p_target_id
  ORDER BY l.intro_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_family_office_intro_r1890(
  p_target_id uuid,
  p_intro_via text,
  p_by_email text,
  p_response text
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
  INSERT INTO public.founder_family_office_intro_log_r1890(target_id, intro_via, by_email, response)
  VALUES (p_target_id, p_intro_via, p_by_email, p_response)
  RETURNING id INTO v_id;

  UPDATE public.founder_family_office_outreach_r1890
  SET last_touch_at = now(),
      first_outreach_at = COALESCE(first_outreach_at, now()),
      updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_family_office_intro_r1890',
    jsonb_build_object('id', v_id, 'target_id', p_target_id, 'intro_via', p_intro_via));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_family_office_status_r1890(
  p_target_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_family_office_outreach_r1890
  SET status = p_new_status,
      last_touch_at = now(),
      updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_family_office_status_r1890',
    jsonb_build_object('target_id', p_target_id, 'new_status', p_new_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_priority_family_offices_r1890()
RETURNS TABLE (
  id uuid,
  family_office_name text,
  family_office_size_aum_rupees bigint,
  status text,
  expected_check_rupees bigint,
  last_touch_at timestamptz,
  intro_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.family_office_name,
    t.family_office_size_aum_rupees,
    t.status,
    t.expected_check_rupees,
    t.last_touch_at,
    (SELECT COUNT(*) FROM public.founder_family_office_intro_log_r1890 l WHERE l.target_id = t.id)::int AS intro_count
  FROM public.founder_family_office_outreach_r1890 t
  WHERE t.status IN ('researching','intro_made','in_dialog')
  ORDER BY COALESCE(t.expected_check_rupees,0) DESC, COALESCE(t.last_touch_at, t.created_at) DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_warm_family_office_intros_r1890()
RETURNS TABLE (
  id uuid,
  target_id uuid,
  family_office_name text,
  intro_via text,
  intro_at timestamptz,
  by_email text,
  response text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    l.target_id,
    t.family_office_name,
    l.intro_via,
    l.intro_at,
    l.by_email,
    l.response
  FROM public.founder_family_office_intro_log_r1890 l
  JOIN public.founder_family_office_outreach_r1890 t ON t.id = l.target_id
  WHERE l.intro_via IN ('warm','referral')
    AND l.intro_at >= now() - interval '90 days'
  ORDER BY l.intro_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_family_office_targets_r1890() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_family_office_target_r1890(text, bigint, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_family_office_intros_r1890(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_family_office_intro_r1890(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_family_office_status_r1890(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_priority_family_offices_r1890() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_warm_family_office_intros_r1890() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_family_office_targets_r1890() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_family_office_target_r1890(text, bigint, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_family_office_intros_r1890(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_family_office_intro_r1890(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_family_office_status_r1890(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_priority_family_offices_r1890() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_warm_family_office_intros_r1890() TO authenticated;

COMMIT;