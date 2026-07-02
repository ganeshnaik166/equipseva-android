BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_lifetime_transitions_r2187 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  from_stage text NOT NULL,
  to_stage text NOT NULL,
  transition_at timestamptz NOT NULL DEFAULT now(),
  days_in_prior_stage int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('normal','concerning','positive','escalation')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_transition_action_log_r2187 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transition_id uuid NOT NULL REFERENCES public.hospital_customer_lifetime_transitions_r2187(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('observed','intervention','celebrated','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_lifetime_transitions_r2187 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_transition_action_log_r2187 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_transitions_r2187 ON public.hospital_customer_lifetime_transitions_r2187;
CREATE POLICY founder_all_transitions_r2187 ON public.hospital_customer_lifetime_transitions_r2187
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2187 ON public.hospital_transition_action_log_r2187;
CREATE POLICY founder_all_action_log_r2187 ON public.hospital_transition_action_log_r2187
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_transitions_r2187();
CREATE OR REPLACE FUNCTION public.list_transitions_r2187()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  from_stage text,
  to_stage text,
  transition_at timestamptz,
  days_in_prior_stage int,
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
  SELECT t.id, t.hospital_id, t.from_stage, t.to_stage, t.transition_at, t.days_in_prior_stage, t.status, t.captured_at
  FROM public.hospital_customer_lifetime_transitions_r2187 t
  ORDER BY t.transition_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_transitions_r2187() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_transitions_r2187() TO authenticated;

DROP FUNCTION IF EXISTS public.log_transition_r2187(uuid, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_transition_r2187(
  p_hospital_id uuid,
  p_from_stage text,
  p_to_stage text,
  p_days_in_prior_stage int,
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
  INSERT INTO public.hospital_customer_lifetime_transitions_r2187(hospital_id, from_stage, to_stage, days_in_prior_stage, status)
  VALUES (p_hospital_id, p_from_stage, p_to_stage, COALESCE(p_days_in_prior_stage,0), COALESCE(p_status,'normal'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_transition_r2187',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'from', p_from_stage, 'to', p_to_stage));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_transition_r2187(uuid, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_transition_r2187(uuid, text, text, int, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_actions_r2187(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2187(p_transition_id uuid)
RETURNS TABLE (
  id uuid,
  transition_id uuid,
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
  SELECT a.id, a.transition_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_transition_action_log_r2187 a
  WHERE a.transition_id = p_transition_id
  ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2187(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2187(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_action_r2187(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2187(
  p_transition_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_transition_action_log_r2187(transition_id, action_type, by_email, notes_md)
  VALUES (p_transition_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2187',
    jsonb_build_object('id', v_id, 'transition_id', p_transition_id, 'type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2187(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2187(uuid, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_status_r2187(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2187(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_lifetime_transitions_r2187
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2187',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2187(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2187(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.concerning_r2187();
CREATE OR REPLACE FUNCTION public.concerning_r2187()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  from_stage text,
  to_stage text,
  transition_at timestamptz,
  days_in_prior_stage int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_id, t.from_stage, t.to_stage, t.transition_at, t.days_in_prior_stage, t.status
  FROM public.hospital_customer_lifetime_transitions_r2187 t
  WHERE t.status IN ('concerning','escalation')
  ORDER BY t.transition_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.concerning_r2187() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concerning_r2187() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_actions_r2187();
CREATE OR REPLACE FUNCTION public.recent_actions_r2187()
RETURNS TABLE (
  id uuid,
  transition_id uuid,
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
  SELECT a.id, a.transition_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_transition_action_log_r2187 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2187() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2187() TO authenticated;

COMMIT;
