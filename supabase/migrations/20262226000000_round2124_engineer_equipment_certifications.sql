BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_equipment_certifications_r2124 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  certification_label text NOT NULL,
  certifying_body text NOT NULL,
  certified_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'valid' CHECK (status IN ('valid','expiring_soon','expired','revoked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_certification_action_log_r2124 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cert_id uuid NOT NULL REFERENCES public.engineer_equipment_certifications_r2124(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('earned','renewed','expired','revoked','upgraded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  cost_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.engineer_equipment_certifications_r2124 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_certification_action_log_r2124 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_certs_r2124 ON public.engineer_equipment_certifications_r2124;
CREATE POLICY founder_all_certs_r2124 ON public.engineer_equipment_certifications_r2124
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2124 ON public.engineer_certification_action_log_r2124;
CREATE POLICY founder_all_actions_r2124 ON public.engineer_certification_action_log_r2124
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_certifications
CREATE OR REPLACE FUNCTION public.list_certifications_r2124()
RETURNS SETOF public.engineer_equipment_certifications_r2124
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_equipment_certifications_r2124 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

-- RPC 2: log_certification
CREATE OR REPLACE FUNCTION public.log_certification_r2124(
  p_engineer_user_id uuid,
  p_equipment_category text,
  p_certification_label text,
  p_certifying_body text,
  p_certified_at timestamptz,
  p_expires_at timestamptz,
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
  INSERT INTO public.engineer_equipment_certifications_r2124(engineer_user_id, equipment_category, certification_label, certifying_body, certified_at, expires_at, status)
  VALUES (p_engineer_user_id, p_equipment_category, p_certification_label, p_certifying_body, p_certified_at, p_expires_at, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_certification_r2124', jsonb_build_object('cert_id', v_id, 'engineer_user_id', p_engineer_user_id));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2124(p_cert_id uuid)
RETURNS SETOF public.engineer_certification_action_log_r2124
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_certification_action_log_r2124 WHERE cert_id = p_cert_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2124(
  p_cert_id uuid,
  p_action_type text,
  p_by_email text,
  p_cost_rupees bigint,
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
  INSERT INTO public.engineer_certification_action_log_r2124(cert_id, action_type, by_email, cost_rupees, notes_md)
  VALUES (p_cert_id, p_action_type, p_by_email, p_cost_rupees, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2124', jsonb_build_object('action_id', v_id, 'cert_id', p_cert_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2124(p_cert_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_equipment_certifications_r2124 SET status = p_status, updated_at = now() WHERE id = p_cert_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2124', jsonb_build_object('cert_id', p_cert_id, 'status', p_status));
END;
$$;

-- RPC 6: expiring_soon
CREATE OR REPLACE FUNCTION public.expiring_soon_r2124()
RETURNS SETOF public.engineer_equipment_certifications_r2124
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_equipment_certifications_r2124
    WHERE expires_at IS NOT NULL
      AND expires_at BETWEEN now() AND now() + interval '60 days'
      AND status IN ('valid','expiring_soon')
    ORDER BY expires_at ASC LIMIT 200;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2124()
RETURNS SETOF public.engineer_certification_action_log_r2124
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_certification_action_log_r2124 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_certifications_r2124() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_certification_r2124(uuid, text, text, text, timestamptz, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2124(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2124(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2124(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2124() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2124() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_certifications_r2124() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_certification_r2124(uuid, text, text, text, timestamptz, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2124(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2124(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2124(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2124() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2124() TO authenticated;

COMMIT;
