BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_multi_hospital_deployment_r2116 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_ids_array uuid[] NOT NULL DEFAULT '{}',
  deployment_start_date date NOT NULL DEFAULT CURRENT_DATE,
  deployment_end_date date,
  deployment_role text NOT NULL CHECK (deployment_role IN ('primary','secondary','floater','backup','training')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','escalated','recalled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_deployment_action_log_r2116 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deployment_id uuid NOT NULL REFERENCES public.engineer_multi_hospital_deployment_r2116(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('deployed','transferred','escalated','recalled','extended','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_multi_hospital_deployment_r2116 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_deployment_action_log_r2116 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_deployment_r2116 ON public.engineer_multi_hospital_deployment_r2116;
CREATE POLICY founder_all_deployment_r2116 ON public.engineer_multi_hospital_deployment_r2116
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2116 ON public.engineer_deployment_action_log_r2116;
CREATE POLICY founder_all_action_log_r2116 ON public.engineer_deployment_action_log_r2116
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_deployments_r2116()
RETURNS SETOF public.engineer_multi_hospital_deployment_r2116
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_multi_hospital_deployment_r2116 ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_deployment_r2116(
  p_engineer_user_id uuid,
  p_hospital_ids uuid[],
  p_start date,
  p_end date,
  p_role text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_multi_hospital_deployment_r2116(engineer_user_id, hospital_ids_array, deployment_start_date, deployment_end_date, deployment_role)
  VALUES (p_engineer_user_id, COALESCE(p_hospital_ids,'{}'), COALESCE(p_start, CURRENT_DATE), p_end, p_role)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_deployment_r2116', jsonb_build_object('id', v_id, 'engineer', p_engineer_user_id, 'role', p_role));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2116(p_deployment_id uuid DEFAULT NULL)
RETURNS SETOF public.engineer_deployment_action_log_r2116
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_deployment_action_log_r2116
    WHERE p_deployment_id IS NULL OR deployment_id = p_deployment_id
    ORDER BY taken_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2116(
  p_deployment_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_deployment_action_log_r2116(deployment_id, action_type, by_email, notes_md)
  VALUES (p_deployment_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2116', jsonb_build_object('id', v_id, 'deployment', p_deployment_id, 'action', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2116(p_deployment_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_multi_hospital_deployment_r2116 SET status = p_status, updated_at = now()
  WHERE id = p_deployment_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2116', jsonb_build_object('id', p_deployment_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.active_deployments_r2116()
RETURNS SETOF public.engineer_multi_hospital_deployment_r2116
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_multi_hospital_deployment_r2116
    WHERE status = 'active' ORDER BY deployment_start_date DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2116()
RETURNS SETOF public.engineer_deployment_action_log_r2116
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_deployment_action_log_r2116
    ORDER BY taken_at DESC LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_deployments_r2116() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_deployment_r2116(uuid, uuid[], date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2116(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2116(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2116(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_deployments_r2116() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2116() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_deployments_r2116() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_deployment_r2116(uuid, uuid[], date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2116(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2116(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2116(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_deployments_r2116() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2116() TO authenticated;

COMMIT;
