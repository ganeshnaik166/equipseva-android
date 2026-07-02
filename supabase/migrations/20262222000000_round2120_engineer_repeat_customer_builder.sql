BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_repeat_customer_builder_r2120 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  repeat_count int NOT NULL DEFAULT 0,
  last_repeat_at timestamptz,
  target_repeat_count int NOT NULL DEFAULT 5,
  status text NOT NULL CHECK (status IN ('building','established','at_risk','lost','exceptional')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_repeat_action_log_r2120 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id uuid NOT NULL REFERENCES public.engineer_repeat_customer_builder_r2120(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement','incentive','coached','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_repeat_customer_builder_r2120 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_repeat_action_log_r2120 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_repeat_builder_r2120 ON public.engineer_repeat_customer_builder_r2120;
CREATE POLICY founder_all_repeat_builder_r2120 ON public.engineer_repeat_customer_builder_r2120
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_repeat_action_r2120 ON public.engineer_repeat_action_log_r2120;
CREATE POLICY founder_all_repeat_action_r2120 ON public.engineer_repeat_action_log_r2120
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_repeat_customer_records_r2120(p_limit int DEFAULT 100)
RETURNS SETOF public.engineer_repeat_customer_builder_r2120
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_repeat_customer_builder_r2120 ORDER BY captured_at DESC LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.log_repeat_customer_record_r2120(
  p_engineer_user_id uuid, p_hospital_id uuid, p_repeat_count int,
  p_last_repeat_at timestamptz, p_target_repeat_count int, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_repeat_customer_builder_r2120(engineer_user_id, hospital_id, repeat_count, last_repeat_at, target_repeat_count, status)
    VALUES (p_engineer_user_id, p_hospital_id, p_repeat_count, p_last_repeat_at, p_target_repeat_count, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_repeat_customer_record_r2120',
            jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_repeat_customer_actions_r2120(p_record_id uuid)
RETURNS SETOF public.engineer_repeat_action_log_r2120
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_repeat_action_log_r2120 WHERE record_id = p_record_id ORDER BY taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_repeat_customer_action_r2120(
  p_record_id uuid, p_action_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_repeat_action_log_r2120(record_id, action_type, by_email, notes_md)
    VALUES (p_record_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_repeat_customer_action_r2120',
            jsonb_build_object('id', v_id, 'record_id', p_record_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_repeat_customer_status_r2120(p_record_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_repeat_customer_builder_r2120 SET status = p_status, updated_at = now() WHERE id = p_record_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_repeat_customer_status_r2120',
            jsonb_build_object('id', p_record_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.list_repeat_customer_at_risk_r2120()
RETURNS SETOF public.engineer_repeat_customer_builder_r2120
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_repeat_customer_builder_r2120 WHERE status = 'at_risk' ORDER BY captured_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.list_repeat_customer_recent_actions_r2120(p_limit int DEFAULT 50)
RETURNS SETOF public.engineer_repeat_action_log_r2120
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_repeat_action_log_r2120 ORDER BY taken_at DESC LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_repeat_customer_records_r2120(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_repeat_customer_record_r2120(uuid, uuid, int, timestamptz, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_repeat_customer_actions_r2120(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_repeat_customer_action_r2120(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_repeat_customer_status_r2120(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_repeat_customer_at_risk_r2120() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_repeat_customer_recent_actions_r2120(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_repeat_customer_records_r2120(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_repeat_customer_record_r2120(uuid, uuid, int, timestamptz, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_repeat_customer_actions_r2120(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_repeat_customer_action_r2120(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_repeat_customer_status_r2120(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_repeat_customer_at_risk_r2120() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_repeat_customer_recent_actions_r2120(int) TO authenticated;

COMMIT;
