BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_nda_vault_r1801 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  nda_signed_at timestamptz NOT NULL DEFAULT now(),
  nda_expires_at timestamptz NOT NULL,
  nda_url text NOT NULL,
  nda_purpose text NOT NULL CHECK (nda_purpose IN ('inbound_diligence','outbound_diligence','data_sharing','partnership_eval','general')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','terminated','superseded')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_nda_access_log_r1801 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nda_id uuid NOT NULL REFERENCES public.investor_nda_vault_r1801(id) ON DELETE CASCADE,
  document_shared text NOT NULL,
  shared_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  response_at timestamptz,
  response_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_nda_vault_r1801 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_nda_access_log_r1801 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_nda_vault_r1801 ON public.investor_nda_vault_r1801;
CREATE POLICY founder_all_nda_vault_r1801 ON public.investor_nda_vault_r1801
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_nda_access_log_r1801 ON public.investor_nda_access_log_r1801;
CREATE POLICY founder_all_nda_access_log_r1801 ON public.investor_nda_access_log_r1801
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_ndas_r1801()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  nda_signed_at timestamptz,
  nda_expires_at timestamptz,
  nda_url text,
  nda_purpose text,
  status text,
  days_to_expiry int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.investor_id, p.email, v.nda_signed_at, v.nda_expires_at,
         v.nda_url, v.nda_purpose, v.status,
         GREATEST(0, EXTRACT(DAY FROM (v.nda_expires_at - now()))::int) AS days_to_expiry
  FROM public.investor_nda_vault_r1801 v
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  ORDER BY v.nda_expires_at ASC;
END $$;

CREATE OR REPLACE FUNCTION public.add_nda_r1801(
  p_investor_id uuid,
  p_signed_at timestamptz,
  p_expires_at timestamptz,
  p_url text,
  p_purpose text,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.investor_nda_vault_r1801(investor_id, nda_signed_at, nda_expires_at, nda_url, nda_purpose, notes)
  VALUES (p_investor_id, p_signed_at, p_expires_at, p_url, p_purpose, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_nda_r1801',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'purpose', p_purpose));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_access_r1801(p_nda_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  nda_id uuid,
  document_shared text,
  shared_at timestamptz,
  by_email text,
  response_at timestamptz,
  response_summary text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.nda_id, a.document_shared, a.shared_at, a.by_email, a.response_at, a.response_summary
  FROM public.investor_nda_access_log_r1801 a
  WHERE p_nda_id IS NULL OR a.nda_id = p_nda_id
  ORDER BY a.shared_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_access_r1801(
  p_nda_id uuid,
  p_doc text,
  p_by_email text,
  p_response_summary text DEFAULT NULL
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
  INSERT INTO public.investor_nda_access_log_r1801(nda_id, document_shared, by_email, response_summary)
  VALUES (p_nda_id, p_doc, p_by_email, p_response_summary)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_access_r1801',
          jsonb_build_object('id', v_id, 'nda_id', p_nda_id, 'doc', p_doc));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.terminate_nda_r1801(p_id uuid, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_nda_vault_r1801
  SET status = 'terminated', updated_at = now(), notes = COALESCE(notes,'') || E'\n[terminated] ' || COALESCE(p_reason,'')
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'terminate_nda_r1801',
          jsonb_build_object('id', p_id, 'reason', p_reason));
END $$;

CREATE OR REPLACE FUNCTION public.expiring_ndas_r1801()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  nda_expires_at timestamptz,
  days_to_expiry int,
  nda_purpose text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.investor_id, p.email, v.nda_expires_at,
         EXTRACT(DAY FROM (v.nda_expires_at - now()))::int AS days_to_expiry,
         v.nda_purpose
  FROM public.investor_nda_vault_r1801 v
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  WHERE v.status = 'active'
    AND v.nda_expires_at <= now() + INTERVAL '60 days'
  ORDER BY v.nda_expires_at ASC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_shares_r1801()
RETURNS TABLE (
  id uuid,
  nda_id uuid,
  investor_email text,
  document_shared text,
  shared_at timestamptz,
  by_email text,
  has_response boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.nda_id, p.email, a.document_shared, a.shared_at, a.by_email,
         (a.response_at IS NOT NULL) AS has_response
  FROM public.investor_nda_access_log_r1801 a
  LEFT JOIN public.investor_nda_vault_r1801 v ON v.id = a.nda_id
  LEFT JOIN public.profiles p ON p.id = v.investor_id
  ORDER BY a.shared_at DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_ndas_r1801() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_nda_r1801(uuid, timestamptz, timestamptz, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_access_r1801(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_access_r1801(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.terminate_nda_r1801(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_ndas_r1801() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_shares_r1801() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_ndas_r1801() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_nda_r1801(uuid, timestamptz, timestamptz, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_access_r1801(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_access_r1801(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_nda_r1801(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_ndas_r1801() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_shares_r1801() TO authenticated;

COMMIT;