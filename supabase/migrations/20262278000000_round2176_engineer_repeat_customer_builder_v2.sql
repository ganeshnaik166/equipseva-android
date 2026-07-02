BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_repeat_customer_builder_v2_r2176 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  repeat_jobs_count int NOT NULL DEFAULT 0,
  total_jobs_count int NOT NULL DEFAULT 0,
  repeat_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('building','established','exceptional','declining','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_repeat_v2_action_log_r2176 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id uuid NOT NULL REFERENCES public.engineer_repeat_customer_builder_v2_r2176(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','coached','intervention','lost','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_repeat_customer_builder_v2_r2176 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_repeat_v2_action_log_r2176 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r2176_records_founder ON public.engineer_repeat_customer_builder_v2_r2176;
CREATE POLICY r2176_records_founder ON public.engineer_repeat_customer_builder_v2_r2176
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r2176_actions_founder ON public.engineer_repeat_v2_action_log_r2176;
CREATE POLICY r2176_actions_founder ON public.engineer_repeat_v2_action_log_r2176
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2176_list_records()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  repeat_jobs_count int,
  total_jobs_count int,
  repeat_rate_pct numeric,
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
  SELECT r.id, r.engineer_user_id, p.email, r.hospital_id, o.name,
         r.repeat_jobs_count, r.total_jobs_count, r.repeat_rate_pct, r.status, r.captured_at
  FROM public.engineer_repeat_customer_builder_v2_r2176 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = r.hospital_id
  ORDER BY r.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_list_records() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_list_records() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_log_record(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_repeat_jobs_count int,
  p_total_jobs_count int,
  p_repeat_rate_pct numeric,
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
  INSERT INTO public.engineer_repeat_customer_builder_v2_r2176
    (engineer_user_id, hospital_id, repeat_jobs_count, total_jobs_count, repeat_rate_pct, status)
  VALUES (p_engineer_user_id, p_hospital_id, p_repeat_jobs_count, p_total_jobs_count, p_repeat_rate_pct, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2176_log_record',
          jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_log_record(uuid, uuid, int, int, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_log_record(uuid, uuid, int, int, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_list_actions(p_record_id uuid)
RETURNS TABLE (
  id uuid,
  record_id uuid,
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
  SELECT a.id, a.record_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_repeat_v2_action_log_r2176 a
  WHERE a.record_id = p_record_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_list_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_list_actions(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_log_action(
  p_record_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.engineer_repeat_v2_action_log_r2176 (record_id, action_type, by_email, notes_md)
  VALUES (p_record_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'r2176_log_action',
          jsonb_build_object('id', v_id, 'record_id', p_record_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_log_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_log_action(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_mark_status(p_record_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_repeat_customer_builder_v2_r2176
  SET status = p_status, updated_at = now()
  WHERE id = p_record_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2176_mark_status',
          jsonb_build_object('id', p_record_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_mark_status(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_exceptional()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  hospital_name text,
  repeat_jobs_count int,
  total_jobs_count int,
  repeat_rate_pct numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, p.email, o.name, r.repeat_jobs_count, r.total_jobs_count, r.repeat_rate_pct, r.captured_at
  FROM public.engineer_repeat_customer_builder_v2_r2176 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = r.hospital_id
  WHERE r.status = 'exceptional'
  ORDER BY r.repeat_rate_pct DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_exceptional() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_exceptional() TO authenticated;

CREATE OR REPLACE FUNCTION public.r2176_recent_actions()
RETURNS TABLE (
  id uuid,
  record_id uuid,
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
  SELECT a.id, a.record_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_repeat_v2_action_log_r2176 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2176_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2176_recent_actions() TO authenticated;

COMMIT;
