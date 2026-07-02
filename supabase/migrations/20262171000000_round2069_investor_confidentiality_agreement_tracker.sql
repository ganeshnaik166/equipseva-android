BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_confidentiality_agreements_r2069 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid,
  agreement_label text NOT NULL,
  agreement_type text NOT NULL CHECK (agreement_type IN ('nda','cda','non_compete','non_solicit')),
  signed_at timestamptz,
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','superseded','terminated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_confidentiality_action_log_r2069 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id uuid NOT NULL REFERENCES public.investor_confidentiality_agreements_r2069(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('signed','extended','superseded','terminated','violated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_confidentiality_agreements_r2069 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_confidentiality_action_log_r2069 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_agreements_r2069 ON public.investor_confidentiality_agreements_r2069;
CREATE POLICY founder_all_agreements_r2069 ON public.investor_confidentiality_agreements_r2069
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2069 ON public.investor_confidentiality_action_log_r2069;
CREATE POLICY founder_all_actions_r2069 ON public.investor_confidentiality_action_log_r2069
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_agreements_r2069_status ON public.investor_confidentiality_agreements_r2069(status);
CREATE INDEX IF NOT EXISTS idx_agreements_r2069_expires ON public.investor_confidentiality_agreements_r2069(expires_at);
CREATE INDEX IF NOT EXISTS idx_actions_r2069_agreement ON public.investor_confidentiality_action_log_r2069(agreement_id);
CREATE INDEX IF NOT EXISTS idx_actions_r2069_taken ON public.investor_confidentiality_action_log_r2069(taken_at DESC);

-- RPC 1: list_agreements
CREATE OR REPLACE FUNCTION public.list_agreements_r2069()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  agreement_label text,
  agreement_type text,
  signed_at timestamptz,
  expires_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, a.investor_id, a.agreement_label, a.agreement_type, a.signed_at, a.expires_at, a.status, a.captured_at
    FROM public.investor_confidentiality_agreements_r2069 a
    ORDER BY a.captured_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_agreement
CREATE OR REPLACE FUNCTION public.log_agreement_r2069(
  p_investor_id uuid,
  p_label text,
  p_type text,
  p_signed_at timestamptz,
  p_expires_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_confidentiality_agreements_r2069(investor_id, agreement_label, agreement_type, signed_at, expires_at, status)
    VALUES (p_investor_id, p_label, p_type, p_signed_at, p_expires_at, 'active')
    RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_agreement_r2069',
      jsonb_build_object('agreement_id', v_id, 'label', p_label, 'type', p_type));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2069(p_agreement_id uuid)
RETURNS TABLE (
  id uuid,
  agreement_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT l.id, l.agreement_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_confidentiality_action_log_r2069 l
    WHERE l.agreement_id = p_agreement_id
    ORDER BY l.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2069(
  p_agreement_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_confidentiality_action_log_r2069(agreement_id, action_type, by_email, notes_md)
    VALUES (p_agreement_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2069',
      jsonb_build_object('action_id', v_id, 'agreement_id', p_agreement_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2069(p_agreement_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_confidentiality_agreements_r2069
    SET status = p_status, updated_at = now()
    WHERE id = p_agreement_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2069',
      jsonb_build_object('agreement_id', p_agreement_id, 'status', p_status));
END;
$$;

-- RPC 6: expiring_soon
CREATE OR REPLACE FUNCTION public.expiring_soon_r2069(p_days int)
RETURNS TABLE (
  id uuid,
  agreement_label text,
  agreement_type text,
  expires_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT a.id, a.agreement_label, a.agreement_type, a.expires_at, a.status
    FROM public.investor_confidentiality_agreements_r2069 a
    WHERE a.status = 'active'
      AND a.expires_at IS NOT NULL
      AND a.expires_at <= now() + (p_days || ' days')::interval
    ORDER BY a.expires_at ASC
    LIMIT 200;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2069(p_limit int)
RETURNS TABLE (
  id uuid,
  agreement_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT l.id, l.agreement_id, l.action_type, l.taken_at, l.by_email
    FROM public.investor_confidentiality_action_log_r2069 l
    ORDER BY l.taken_at DESC
    LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_agreements_r2069() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_agreement_r2069(uuid, text, text, timestamptz, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2069(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2069(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2069(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2069(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2069(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_agreements_r2069() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_agreement_r2069(uuid, text, text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2069(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2069(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2069(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2069(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2069(int) TO authenticated;

COMMIT;
