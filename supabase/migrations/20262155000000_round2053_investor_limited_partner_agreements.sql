BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_limited_partner_agreements_r2053 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  agreement_label text NOT NULL,
  agreement_version text NOT NULL,
  signed_at timestamptz,
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','terminated','under_review')),
  key_terms_md text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_lpa_action_log_r2053 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id uuid NOT NULL REFERENCES public.investor_limited_partner_agreements_r2053(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signed','superseded','amended','terminated','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_limited_partner_agreements_r2053 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_lpa_action_log_r2053 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_lpa_r2053 ON public.investor_limited_partner_agreements_r2053;
CREATE POLICY founder_all_lpa_r2053 ON public.investor_limited_partner_agreements_r2053
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_lpa_action_r2053 ON public.investor_lpa_action_log_r2053;
CREATE POLICY founder_all_lpa_action_r2053 ON public.investor_lpa_action_log_r2053
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_lpa_agreements_r2053()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  agreement_label text,
  agreement_version text,
  signed_at timestamptz,
  expires_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.investor_id, p.email::text, a.agreement_label, a.agreement_version,
         a.signed_at, a.expires_at, a.status, a.captured_at
  FROM public.investor_limited_partner_agreements_r2053 a
  LEFT JOIN public.profiles p ON p.id = a.investor_id
  ORDER BY a.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lpa_agreement_r2053(
  p_investor_id uuid,
  p_agreement_label text,
  p_agreement_version text,
  p_signed_at timestamptz,
  p_expires_at timestamptz,
  p_status text,
  p_key_terms_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_limited_partner_agreements_r2053(
    investor_id, agreement_label, agreement_version, signed_at, expires_at, status, key_terms_md
  ) VALUES (
    p_investor_id, p_agreement_label, p_agreement_version, p_signed_at, p_expires_at,
    COALESCE(p_status,'active'), p_key_terms_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lpa_agreement_r2053',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_agreement_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_lpa_actions_r2053(p_agreement_id uuid)
RETURNS TABLE(
  id uuid,
  agreement_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.agreement_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.investor_lpa_action_log_r2053 l
  WHERE l.agreement_id = p_agreement_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_lpa_action_r2053(
  p_agreement_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_lpa_action_log_r2053(agreement_id, action_type, by_email, notes_md)
  VALUES (p_agreement_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_lpa_action_r2053',
    jsonb_build_object('id', v_id, 'agreement_id', p_agreement_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_lpa_status_r2053(
  p_agreement_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_limited_partner_agreements_r2053
  SET status = p_status, updated_at = now()
  WHERE id = p_agreement_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_lpa_status_r2053',
    jsonb_build_object('id', p_agreement_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_lpa_agreements_r2053()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_email text,
  agreement_label text,
  agreement_version text,
  signed_at timestamptz,
  expires_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.investor_id, p.email::text, a.agreement_label, a.agreement_version,
         a.signed_at, a.expires_at
  FROM public.investor_limited_partner_agreements_r2053 a
  LEFT JOIN public.profiles p ON p.id = a.investor_id
  WHERE a.status = 'active'
  ORDER BY a.signed_at DESC NULLS LAST
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_lpa_actions_r2053()
RETURNS TABLE(
  id uuid,
  agreement_id uuid,
  agreement_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.agreement_id, a.agreement_label, l.action_type, l.taken_at, l.by_email
  FROM public.investor_lpa_action_log_r2053 l
  LEFT JOIN public.investor_limited_partner_agreements_r2053 a ON a.id = l.agreement_id
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_lpa_agreements_r2053() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lpa_agreement_r2053(uuid, text, text, timestamptz, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_lpa_actions_r2053(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lpa_action_r2053(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_lpa_status_r2053(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_lpa_agreements_r2053() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_lpa_actions_r2053() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_lpa_agreements_r2053() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lpa_agreement_r2053(uuid, text, text, timestamptz, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_lpa_actions_r2053(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lpa_action_r2053(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_lpa_status_r2053(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_lpa_agreements_r2053() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_lpa_actions_r2053() TO authenticated;

COMMIT;
