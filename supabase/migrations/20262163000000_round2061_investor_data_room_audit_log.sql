BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_data_room_audit_log_r2061 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  document_label text NOT NULL,
  access_type text NOT NULL CHECK (access_type IN ('viewed','downloaded','shared_externally','printed')),
  accessed_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  status text NOT NULL DEFAULT 'valid_access' CHECK (status IN ('valid_access','suspicious','blocked','reviewed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_data_room_action_log_r2061 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.investor_data_room_audit_log_r2061(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reviewed','flagged','blocked','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_data_room_audit_log_r2061 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_data_room_action_log_r2061 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_audit_r2061 ON public.investor_data_room_audit_log_r2061;
CREATE POLICY founder_all_audit_r2061 ON public.investor_data_room_audit_log_r2061
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2061 ON public.investor_data_room_action_log_r2061;
CREATE POLICY founder_all_action_r2061 ON public.investor_data_room_action_log_r2061
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_accesses_r2061()
RETURNS SETOF public.investor_data_room_audit_log_r2061
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_data_room_audit_log_r2061 ORDER BY accessed_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_access_r2061(
  p_investor_id uuid,
  p_document_label text,
  p_access_type text,
  p_ip_address text
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
  INSERT INTO public.investor_data_room_audit_log_r2061(investor_id, document_label, access_type, ip_address)
  VALUES (p_investor_id, p_document_label, p_access_type, p_ip_address)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_access_r2061',
    jsonb_build_object('id', v_id, 'document_label', p_document_label, 'access_type', p_access_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2061(p_audit_id uuid)
RETURNS SETOF public.investor_data_room_action_log_r2061
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_data_room_action_log_r2061 WHERE audit_id = p_audit_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2061(
  p_audit_id uuid,
  p_action_type text,
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
  INSERT INTO public.investor_data_room_action_log_r2061(audit_id, action_type, by_email, notes_md)
  VALUES (p_audit_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2061',
    jsonb_build_object('id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2061(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_data_room_audit_log_r2061 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2061',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.suspicious_accesses_r2061()
RETURNS SETOF public.investor_data_room_audit_log_r2061
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_data_room_audit_log_r2061
    WHERE status IN ('suspicious','blocked') ORDER BY accessed_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2061()
RETURNS SETOF public.investor_data_room_action_log_r2061
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_data_room_action_log_r2061 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_accesses_r2061() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_access_r2061(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2061(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2061(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2061(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.suspicious_accesses_r2061() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2061() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_accesses_r2061() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_access_r2061(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2061(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2061(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2061(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.suspicious_accesses_r2061() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2061() TO authenticated;

COMMIT;
