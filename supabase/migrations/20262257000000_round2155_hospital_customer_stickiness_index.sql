BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_stickiness_index_r2155 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  stickiness_score int NOT NULL CHECK (stickiness_score BETWEEN 0 AND 100),
  retention_factors_md text,
  status text NOT NULL DEFAULT 'sticky' CHECK (status IN ('very_sticky','sticky','loose','at_risk','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_stickiness_action_log_r2155 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stickiness_id uuid NOT NULL REFERENCES public.hospital_customer_stickiness_index_r2155(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement_increased','at_risk_intervention','retention_locked','lost','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_stickiness_index_r2155 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_stickiness_action_log_r2155 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stickiness_r2155 ON public.hospital_customer_stickiness_index_r2155;
CREATE POLICY founder_all_stickiness_r2155 ON public.hospital_customer_stickiness_index_r2155
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_stickiness_actions_r2155 ON public.hospital_stickiness_action_log_r2155;
CREATE POLICY founder_all_stickiness_actions_r2155 ON public.hospital_stickiness_action_log_r2155
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_stickiness_indices_r2155()
RETURNS SETOF public.hospital_customer_stickiness_index_r2155
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_stickiness_index_r2155 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_stickiness_index_r2155(
  p_hospital_id uuid,
  p_period_label text,
  p_stickiness_score int,
  p_retention_factors_md text,
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
  INSERT INTO public.hospital_customer_stickiness_index_r2155(hospital_id, period_label, stickiness_score, retention_factors_md, status)
  VALUES (p_hospital_id, p_period_label, p_stickiness_score, p_retention_factors_md, COALESCE(p_status,'sticky'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stickiness_index_r2155', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'score', p_stickiness_score, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_stickiness_actions_r2155(p_stickiness_id uuid)
RETURNS SETOF public.hospital_stickiness_action_log_r2155
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_stickiness_action_log_r2155 WHERE stickiness_id = p_stickiness_id ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_stickiness_action_r2155(
  p_stickiness_id uuid,
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
  INSERT INTO public.hospital_stickiness_action_log_r2155(stickiness_id, action_type, by_email, notes_md)
  VALUES (p_stickiness_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stickiness_action_r2155', jsonb_build_object('id', v_id, 'stickiness_id', p_stickiness_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_stickiness_status_r2155(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_stickiness_index_r2155
    SET status = p_status, updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_stickiness_status_r2155', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.very_sticky_stickiness_r2155()
RETURNS SETOF public.hospital_customer_stickiness_index_r2155
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_stickiness_index_r2155 WHERE status = 'very_sticky' ORDER BY stickiness_score DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_stickiness_actions_r2155()
RETURNS SETOF public.hospital_stickiness_action_log_r2155
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_stickiness_action_log_r2155 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_stickiness_indices_r2155() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_stickiness_index_r2155(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_stickiness_actions_r2155(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_stickiness_action_r2155(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_stickiness_status_r2155(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.very_sticky_stickiness_r2155() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_stickiness_actions_r2155() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_stickiness_indices_r2155() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_stickiness_index_r2155(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_stickiness_actions_r2155(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_stickiness_action_r2155(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_stickiness_status_r2155(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.very_sticky_stickiness_r2155() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_stickiness_actions_r2155() TO authenticated;

COMMIT;
