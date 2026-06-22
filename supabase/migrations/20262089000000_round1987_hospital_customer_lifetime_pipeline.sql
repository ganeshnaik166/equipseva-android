BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_lifetime_pipeline_r1987 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lifetime_stage text NOT NULL CHECK (lifetime_stage IN ('awareness','trial','active_customer','expanding','at_risk','churned','recovered')),
  stage_entered_at timestamptz NOT NULL DEFAULT now(),
  stage_duration_days int NOT NULL DEFAULT 0,
  total_lifetime_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','churned','recovered')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_lifetime_action_log_r1987 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id uuid NOT NULL REFERENCES public.hospital_customer_lifetime_pipeline_r1987(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('upgrade_offered','expansion_call','at_risk_intervention','win_back','exit_interview')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_lifetime_pipeline_r1987 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_lifetime_action_log_r1987 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pipeline_r1987 ON public.hospital_customer_lifetime_pipeline_r1987;
CREATE POLICY founder_all_pipeline_r1987 ON public.hospital_customer_lifetime_pipeline_r1987
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1987 ON public.hospital_lifetime_action_log_r1987;
CREATE POLICY founder_all_actions_r1987 ON public.hospital_lifetime_action_log_r1987
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_lifetimes_r1987()
RETURNS TABLE(id uuid, hospital_id uuid, lifetime_stage text, stage_entered_at timestamptz, stage_duration_days int, total_lifetime_value_rupees bigint, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.hospital_id, p.lifetime_stage, p.stage_entered_at, p.stage_duration_days, p.total_lifetime_value_rupees, p.status, p.captured_at
    FROM public.hospital_customer_lifetime_pipeline_r1987 p
    ORDER BY p.captured_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_lifetime_r1987(p_hospital_id uuid, p_stage text, p_duration int, p_ltv bigint)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_lifetime_pipeline_r1987(hospital_id, lifetime_stage, stage_duration_days, total_lifetime_value_rupees)
    VALUES (p_hospital_id, p_stage, COALESCE(p_duration,0), COALESCE(p_ltv,0)) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lifetime_r1987', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'stage', p_stage));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1987()
RETURNS TABLE(id uuid, stage_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.stage_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_lifetime_action_log_r1987 a
    ORDER BY a.taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r1987(p_stage_id uuid, p_action_type text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_lifetime_action_log_r1987(stage_id, action_type, by_email, notes_md)
    VALUES (p_stage_id, p_action_type, (auth.jwt()->>'email'), p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1987', jsonb_build_object('id', v_id, 'stage_id', p_stage_id, 'action', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1987(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_lifetime_pipeline_r1987 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1987', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.at_risk_customers_r1987()
RETURNS TABLE(id uuid, hospital_id uuid, lifetime_stage text, stage_duration_days int, total_lifetime_value_rupees bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.hospital_id, p.lifetime_stage, p.stage_duration_days, p.total_lifetime_value_rupees, p.status
    FROM public.hospital_customer_lifetime_pipeline_r1987 p
    WHERE p.lifetime_stage = 'at_risk' OR p.status IN ('dormant','churned')
    ORDER BY p.total_lifetime_value_rupees DESC LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1987()
RETURNS TABLE(id uuid, stage_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.stage_id, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_lifetime_action_log_r1987 a
    WHERE a.taken_at > now() - interval '30 days'
    ORDER BY a.taken_at DESC LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_lifetimes_r1987() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lifetime_r1987(uuid, text, int, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1987() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1987(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1987(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_customers_r1987() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1987() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_lifetimes_r1987() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lifetime_r1987(uuid, text, int, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1987() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1987(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1987(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_customers_r1987() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1987() TO authenticated;

COMMIT;
