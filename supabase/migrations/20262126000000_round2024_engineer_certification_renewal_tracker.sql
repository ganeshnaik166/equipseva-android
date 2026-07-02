BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_certification_renewal_r2024 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cert_label text NOT NULL,
  cert_authority text NOT NULL,
  expiry_date date NOT NULL,
  renewal_required_by date NOT NULL,
  status text NOT NULL CHECK (status IN ('valid','renewal_due','expiring_soon','expired','revoked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_cert_renewal_action_log_r2024 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  renewal_id uuid NOT NULL REFERENCES public.engineer_certification_renewal_r2024(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reminder_sent','renewed','exam_passed','expired','lost_engineer')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  cost_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_certification_renewal_r2024 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_cert_renewal_action_log_r2024 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_renewal_r2024 ON public.engineer_certification_renewal_r2024;
CREATE POLICY founder_all_renewal_r2024 ON public.engineer_certification_renewal_r2024
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2024 ON public.engineer_cert_renewal_action_log_r2024;
CREATE POLICY founder_all_action_log_r2024 ON public.engineer_cert_renewal_action_log_r2024
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_renewals_r2024()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  cert_label text,
  cert_authority text,
  expiry_date date,
  renewal_required_by date,
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
    SELECT r.id, r.engineer_user_id, r.cert_label, r.cert_authority, r.expiry_date,
           r.renewal_required_by, r.status, r.captured_at
    FROM public.engineer_certification_renewal_r2024 r
    ORDER BY r.renewal_required_by ASC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_renewal_r2024(
  p_engineer_user_id uuid,
  p_cert_label text,
  p_cert_authority text,
  p_expiry_date date,
  p_renewal_required_by date,
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
  INSERT INTO public.engineer_certification_renewal_r2024(
    engineer_user_id, cert_label, cert_authority, expiry_date, renewal_required_by, status
  ) VALUES (
    p_engineer_user_id, p_cert_label, p_cert_authority, p_expiry_date, p_renewal_required_by, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_renewal_r2024',
    jsonb_build_object('renewal_id', v_id, 'engineer_user_id', p_engineer_user_id, 'cert_label', p_cert_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2024(p_renewal_id uuid)
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.renewal_id, a.action_type, a.taken_at, a.by_email, a.cost_rupees, a.notes_md
    FROM public.engineer_cert_renewal_action_log_r2024 a
    WHERE a.renewal_id = p_renewal_id
    ORDER BY a.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2024(
  p_renewal_id uuid,
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
  INSERT INTO public.engineer_cert_renewal_action_log_r2024(
    renewal_id, action_type, by_email, cost_rupees, notes_md
  ) VALUES (
    p_renewal_id, p_action_type, p_by_email, p_cost_rupees, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2024',
    jsonb_build_object('action_id', v_id, 'renewal_id', p_renewal_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2024(
  p_renewal_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_certification_renewal_r2024
    SET status = p_status, updated_at = now()
    WHERE id = p_renewal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2024',
    jsonb_build_object('renewal_id', p_renewal_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.expiring_certs_r2024()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  cert_label text,
  cert_authority text,
  expiry_date date,
  renewal_required_by date,
  status text,
  days_to_expiry integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.engineer_user_id, r.cert_label, r.cert_authority, r.expiry_date,
           r.renewal_required_by, r.status,
           (r.expiry_date - CURRENT_DATE)::integer AS days_to_expiry
    FROM public.engineer_certification_renewal_r2024 r
    WHERE r.expiry_date <= (CURRENT_DATE + INTERVAL '60 days')
      AND r.status IN ('valid','renewal_due','expiring_soon')
    ORDER BY r.expiry_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2024(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  renewal_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.renewal_id, a.action_type, a.taken_at, a.by_email, a.cost_rupees, a.notes_md
    FROM public.engineer_cert_renewal_action_log_r2024 a
    ORDER BY a.taken_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_renewals_r2024() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_renewal_r2024(uuid, text, text, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2024(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2024(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2024(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_certs_r2024() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2024(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_renewals_r2024() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_r2024(uuid, text, text, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2024(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2024(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2024(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_certs_r2024() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2024(integer) TO authenticated;

COMMIT;
