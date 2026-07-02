BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_onboarding_drop_off_r2159 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  drop_off_stage text NOT NULL CHECK (drop_off_stage IN ('signup','onboarding_call','first_repair','billing_setup','regular_use')),
  drop_off_reason_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','recovered','lost','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_drop_off_action_log_r2159 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drop_id uuid NOT NULL REFERENCES public.hospital_customer_onboarding_drop_off_r2159(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('identified','intervention','recovered','lost','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_onboarding_drop_off_r2159 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_drop_off_action_log_r2159 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drops_r2159 ON public.hospital_customer_onboarding_drop_off_r2159;
CREATE POLICY founder_all_drops_r2159 ON public.hospital_customer_onboarding_drop_off_r2159
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_drop_actions_r2159 ON public.hospital_drop_off_action_log_r2159;
CREATE POLICY founder_all_drop_actions_r2159 ON public.hospital_drop_off_action_log_r2159
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_drops_r2159()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, drop_off_stage text, drop_off_reason_md text, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_id, o.name, d.drop_off_stage, d.drop_off_reason_md, d.status, d.captured_at
  FROM public.hospital_customer_onboarding_drop_off_r2159 d
  LEFT JOIN public.organizations o ON o.id = d.hospital_id
  ORDER BY d.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_drops_r2159() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_drops_r2159() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_drop_r2159(p_hospital_id uuid, p_stage text, p_reason_md text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_onboarding_drop_off_r2159(hospital_id, drop_off_stage, drop_off_reason_md)
  VALUES (p_hospital_id, p_stage, p_reason_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_drop_r2159', jsonb_build_object('drop_id', v_id, 'hospital_id', p_hospital_id, 'stage', p_stage));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_drop_r2159(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_drop_r2159(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2159(p_drop_id uuid)
RETURNS TABLE(id uuid, drop_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.drop_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_drop_off_action_log_r2159 a
  WHERE a.drop_id = p_drop_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2159(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2159(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2159(p_drop_id uuid, p_action_type text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_drop_off_action_log_r2159(drop_id, action_type, by_email, notes_md)
  VALUES (p_drop_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2159', jsonb_build_object('drop_id', p_drop_id, 'action_type', p_action_type, 'action_id', v_id));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2159(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2159(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2159(p_drop_id uuid, p_status text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_onboarding_drop_off_r2159
  SET status = p_status, updated_at = now()
  WHERE id = p_drop_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2159', jsonb_build_object('drop_id', p_drop_id, 'status', p_status));
  RETURN true;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2159(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2159(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.by_stage_r2159()
RETURNS TABLE(drop_off_stage text, total_count bigint, active_count bigint, recovered_count bigint, lost_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.drop_off_stage,
         count(*)::bigint,
         count(*) FILTER (WHERE d.status = 'active')::bigint,
         count(*) FILTER (WHERE d.status = 'recovered')::bigint,
         count(*) FILTER (WHERE d.status = 'lost')::bigint
  FROM public.hospital_customer_onboarding_drop_off_r2159 d
  GROUP BY d.drop_off_stage
  ORDER BY d.drop_off_stage;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.by_stage_r2159() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.by_stage_r2159() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2159()
RETURNS TABLE(id uuid, drop_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.drop_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_drop_off_action_log_r2159 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2159() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2159() TO authenticated;

COMMIT;
