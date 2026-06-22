BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_lifecycle_stage_audit_r2143 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_stage text NOT NULL CHECK (current_stage IN ('trial','active','scaling','at_risk','churning','recovered')),
  days_in_current_stage int NOT NULL DEFAULT 0,
  ideal_next_stage text,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('normal','concerning','critical','excellent')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_lifecycle_action_log_r2143 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.hospital_customer_lifecycle_stage_audit_r2143(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('upgraded','maintained','downgraded','intervention','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_lifecycle_stage_audit_r2143 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_lifecycle_action_log_r2143 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_audit_r2143 ON public.hospital_customer_lifecycle_stage_audit_r2143;
CREATE POLICY founder_all_audit_r2143 ON public.hospital_customer_lifecycle_stage_audit_r2143
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2143 ON public.hospital_lifecycle_action_log_r2143;
CREATE POLICY founder_all_actions_r2143 ON public.hospital_lifecycle_action_log_r2143
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_lifecycle_audits_r2143()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  current_stage text,
  days_in_current_stage int,
  ideal_next_stage text,
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
  SELECT a.id, a.hospital_id, a.current_stage, a.days_in_current_stage, a.ideal_next_stage, a.status, a.captured_at
  FROM public.hospital_customer_lifecycle_stage_audit_r2143 a
  ORDER BY a.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lifecycle_audit_r2143(
  p_hospital_id uuid,
  p_current_stage text,
  p_days_in_current_stage int,
  p_ideal_next_stage text,
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
  INSERT INTO public.hospital_customer_lifecycle_stage_audit_r2143(
    hospital_id, current_stage, days_in_current_stage, ideal_next_stage, status
  ) VALUES (
    p_hospital_id, p_current_stage, COALESCE(p_days_in_current_stage,0), p_ideal_next_stage, COALESCE(p_status,'normal')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lifecycle_audit_r2143',
    jsonb_build_object('audit_id', v_id, 'hospital_id', p_hospital_id, 'stage', p_current_stage));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_lifecycle_actions_r2143(p_audit_id uuid)
RETURNS TABLE (
  id uuid,
  audit_id uuid,
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
  SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_lifecycle_action_log_r2143 l
  WHERE l.audit_id = p_audit_id
  ORDER BY l.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lifecycle_action_r2143(
  p_audit_id uuid,
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
  INSERT INTO public.hospital_lifecycle_action_log_r2143(audit_id, action_type, by_email, notes_md)
  VALUES (p_audit_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lifecycle_action_r2143',
    jsonb_build_object('action_id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_lifecycle_status_r2143(
  p_audit_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_lifecycle_stage_audit_r2143
    SET status = p_status, updated_at = now()
    WHERE id = p_audit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_lifecycle_status_r2143',
    jsonb_build_object('audit_id', p_audit_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.critical_lifecycle_stages_r2143()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  current_stage text,
  days_in_current_stage int,
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
  SELECT a.id, a.hospital_id, a.current_stage, a.days_in_current_stage, a.status, a.captured_at
  FROM public.hospital_customer_lifecycle_stage_audit_r2143 a
  WHERE a.status IN ('critical','concerning')
     OR a.current_stage IN ('at_risk','churning')
  ORDER BY a.captured_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_lifecycle_actions_r2143()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
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
  SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_lifecycle_action_log_r2143 l
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_lifecycle_audits_r2143() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lifecycle_audit_r2143(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_lifecycle_actions_r2143(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lifecycle_action_r2143(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_lifecycle_status_r2143(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_lifecycle_stages_r2143() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_lifecycle_actions_r2143() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_lifecycle_audits_r2143() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lifecycle_audit_r2143(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_lifecycle_actions_r2143(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lifecycle_action_r2143(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_lifecycle_status_r2143(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_lifecycle_stages_r2143() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_lifecycle_actions_r2143() TO authenticated;

COMMIT;
