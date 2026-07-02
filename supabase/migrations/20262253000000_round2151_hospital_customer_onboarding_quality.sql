BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_onboarding_quality_r2151 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  onboarding_score int NOT NULL CHECK (onboarding_score BETWEEN 0 AND 100),
  total_blockers int NOT NULL DEFAULT 0,
  days_to_full_activation int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('excellent','good','needs_work','poor','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_onboarding_quality_action_log_r2151 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quality_id uuid NOT NULL REFERENCES public.hospital_customer_onboarding_quality_r2151(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('escalated','improved','closed','recovered','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_onboarding_quality_r2151 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_onboarding_quality_action_log_r2151 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_quality_r2151 ON public.hospital_customer_onboarding_quality_r2151;
CREATE POLICY founder_all_quality_r2151 ON public.hospital_customer_onboarding_quality_r2151
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2151 ON public.hospital_onboarding_quality_action_log_r2151;
CREATE POLICY founder_all_action_r2151 ON public.hospital_onboarding_quality_action_log_r2151
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_qualities_r2151()
RETURNS SETOF public.hospital_customer_onboarding_quality_r2151
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_onboarding_quality_r2151 ORDER BY captured_at DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_quality_r2151(
  p_hospital_id uuid, p_score int, p_blockers int, p_days int, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_onboarding_quality_r2151(hospital_id, onboarding_score, total_blockers, days_to_full_activation, status)
    VALUES (p_hospital_id, p_score, p_blockers, p_days, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_quality_r2151', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'score', p_score));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2151(p_quality_id uuid)
RETURNS SETOF public.hospital_onboarding_quality_action_log_r2151
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_onboarding_quality_action_log_r2151 WHERE quality_id = p_quality_id ORDER BY taken_at DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2151(
  p_quality_id uuid, p_action_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_onboarding_quality_action_log_r2151(quality_id, action_type, by_email, notes_md)
    VALUES (p_quality_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2151', jsonb_build_object('id', v_id, 'quality_id', p_quality_id, 'action', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2151(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_onboarding_quality_r2151 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2151', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.poor_quality_r2151()
RETURNS SETOF public.hospital_customer_onboarding_quality_r2151
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_onboarding_quality_r2151
    WHERE status IN ('poor','escalated') ORDER BY captured_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2151()
RETURNS SETOF public.hospital_onboarding_quality_action_log_r2151
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_onboarding_quality_action_log_r2151 ORDER BY taken_at DESC LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_qualities_r2151() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_quality_r2151(uuid, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2151(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2151(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2151(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.poor_quality_r2151() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2151() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_qualities_r2151() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_quality_r2151(uuid, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2151(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2151(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2151(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poor_quality_r2151() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2151() TO authenticated;

COMMIT;
