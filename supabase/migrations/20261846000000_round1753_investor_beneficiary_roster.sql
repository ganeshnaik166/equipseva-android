BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.investor_beneficiaries_r1753 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  beneficiary_name text NOT NULL,
  beneficiary_relationship text NOT NULL CHECK (beneficiary_relationship IN ('spouse','child','parent','sibling','trust','other')),
  beneficiary_email text,
  beneficiary_phone text,
  allocation_pct numeric NOT NULL DEFAULT 0,
  is_primary boolean NOT NULL DEFAULT false,
  is_contingent boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','expired')),
  set_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_beneficiary_documents_r1753 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_id uuid NOT NULL REFERENCES public.investor_beneficiaries_r1753(id) ON DELETE CASCADE,
  document_type text NOT NULL CHECK (document_type IN ('will','trust_deed','nomination_form','id_proof')),
  document_name text NOT NULL,
  document_url text,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_benef_r1753_investor ON public.investor_beneficiaries_r1753(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_benef_doc_r1753_benef ON public.investor_beneficiary_documents_r1753(beneficiary_id);
CREATE INDEX IF NOT EXISTS idx_inv_benef_doc_r1753_expires ON public.investor_beneficiary_documents_r1753(expires_at);

-- RLS
ALTER TABLE public.investor_beneficiaries_r1753 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_beneficiary_documents_r1753 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inv_benef_r1753 ON public.investor_beneficiaries_r1753;
CREATE POLICY founder_all_inv_benef_r1753 ON public.investor_beneficiaries_r1753
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_inv_benef_doc_r1753 ON public.investor_beneficiary_documents_r1753;
CREATE POLICY founder_all_inv_benef_doc_r1753 ON public.investor_beneficiary_documents_r1753
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_beneficiaries
CREATE OR REPLACE FUNCTION public.list_beneficiaries_r1753(p_investor_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  beneficiary_name text,
  beneficiary_relationship text,
  beneficiary_email text,
  beneficiary_phone text,
  allocation_pct numeric,
  is_primary boolean,
  is_contingent boolean,
  status text,
  set_at timestamptz
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
  SELECT b.id, b.investor_id, b.beneficiary_name, b.beneficiary_relationship,
         b.beneficiary_email, b.beneficiary_phone, b.allocation_pct,
         b.is_primary, b.is_contingent, b.status, b.set_at
  FROM public.investor_beneficiaries_r1753 b
  WHERE (p_investor_id IS NULL OR b.investor_id = p_investor_id)
  ORDER BY b.set_at DESC;
END;
$$;

-- RPC 2: set_beneficiary
CREATE OR REPLACE FUNCTION public.set_beneficiary_r1753(
  p_investor_id uuid,
  p_beneficiary_name text,
  p_beneficiary_relationship text,
  p_beneficiary_email text,
  p_beneficiary_phone text,
  p_allocation_pct numeric,
  p_is_primary boolean,
  p_is_contingent boolean
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
  INSERT INTO public.investor_beneficiaries_r1753 (
    investor_id, beneficiary_name, beneficiary_relationship,
    beneficiary_email, beneficiary_phone, allocation_pct,
    is_primary, is_contingent
  ) VALUES (
    p_investor_id, p_beneficiary_name, p_beneficiary_relationship,
    p_beneficiary_email, p_beneficiary_phone, COALESCE(p_allocation_pct, 0),
    COALESCE(p_is_primary, false), COALESCE(p_is_contingent, false)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_beneficiary_r1753',
    jsonb_build_object('beneficiary_id', v_id, 'investor_id', p_investor_id, 'name', p_beneficiary_name));

  RETURN v_id;
END;
$$;

-- RPC 3: list_documents
CREATE OR REPLACE FUNCTION public.list_documents_r1753(p_beneficiary_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  beneficiary_id uuid,
  beneficiary_name text,
  document_type text,
  document_name text,
  document_url text,
  uploaded_at timestamptz,
  expires_at timestamptz
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
  SELECT d.id, d.beneficiary_id, b.beneficiary_name,
         d.document_type, d.document_name, d.document_url,
         d.uploaded_at, d.expires_at
  FROM public.investor_beneficiary_documents_r1753 d
  JOIN public.investor_beneficiaries_r1753 b ON b.id = d.beneficiary_id
  WHERE (p_beneficiary_id IS NULL OR d.beneficiary_id = p_beneficiary_id)
  ORDER BY d.uploaded_at DESC;
END;
$$;

-- RPC 4: attach_document
CREATE OR REPLACE FUNCTION public.attach_document_r1753(
  p_beneficiary_id uuid,
  p_document_type text,
  p_document_name text,
  p_document_url text,
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
  INSERT INTO public.investor_beneficiary_documents_r1753 (
    beneficiary_id, document_type, document_name, document_url, expires_at
  ) VALUES (
    p_beneficiary_id, p_document_type, p_document_name, p_document_url, p_expires_at
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'attach_document_r1753',
    jsonb_build_object('document_id', v_id, 'beneficiary_id', p_beneficiary_id, 'type', p_document_type));

  RETURN v_id;
END;
$$;

-- RPC 5: update_beneficiary_status
CREATE OR REPLACE FUNCTION public.update_beneficiary_status_r1753(
  p_beneficiary_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('active','revoked','expired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_beneficiaries_r1753
  SET status = p_status, updated_at = now()
  WHERE id = p_beneficiary_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_beneficiary_status_r1753',
    jsonb_build_object('beneficiary_id', p_beneficiary_id, 'status', p_status));
END;
$$;

-- RPC 6: beneficiary_summary_per_investor
CREATE OR REPLACE FUNCTION public.beneficiary_summary_per_investor_r1753()
RETURNS TABLE (
  investor_id uuid,
  total_beneficiaries int,
  primary_count int,
  contingent_count int,
  active_count int,
  total_allocation_pct numeric,
  document_count int
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
  SELECT
    b.investor_id,
    COUNT(*)::int AS total_beneficiaries,
    (COUNT(*) FILTER (WHERE b.is_primary))::int AS primary_count,
    (COUNT(*) FILTER (WHERE b.is_contingent))::int AS contingent_count,
    (COUNT(*) FILTER (WHERE b.status = 'active'))::int AS active_count,
    COALESCE(SUM(b.allocation_pct), 0)::numeric AS total_allocation_pct,
    (SELECT COUNT(*)::int FROM public.investor_beneficiary_documents_r1753 d
       JOIN public.investor_beneficiaries_r1753 b2 ON b2.id = d.beneficiary_id
       WHERE b2.investor_id = b.investor_id) AS document_count
  FROM public.investor_beneficiaries_r1753 b
  GROUP BY b.investor_id
  ORDER BY total_beneficiaries DESC;
END;
$$;

-- RPC 7: expiring_documents
CREATE OR REPLACE FUNCTION public.expiring_documents_r1753(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  beneficiary_id uuid,
  beneficiary_name text,
  investor_id uuid,
  document_type text,
  document_name text,
  expires_at timestamptz,
  days_until_expiry int
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
  SELECT d.id, d.beneficiary_id, b.beneficiary_name, b.investor_id,
         d.document_type, d.document_name, d.expires_at,
         EXTRACT(DAY FROM (d.expires_at - now()))::int AS days_until_expiry
  FROM public.investor_beneficiary_documents_r1753 d
  JOIN public.investor_beneficiaries_r1753 b ON b.id = d.beneficiary_id
  WHERE d.expires_at IS NOT NULL
    AND d.expires_at <= (now() + (p_days || ' days')::interval)
  ORDER BY d.expires_at ASC;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_beneficiaries_r1753(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_beneficiaries_r1753(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.set_beneficiary_r1753(uuid, text, text, text, text, numeric, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_beneficiary_r1753(uuid, text, text, text, text, numeric, boolean, boolean) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_documents_r1753(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_documents_r1753(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.attach_document_r1753(uuid, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attach_document_r1753(uuid, text, text, text, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.update_beneficiary_status_r1753(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_beneficiary_status_r1753(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.beneficiary_summary_per_investor_r1753() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.beneficiary_summary_per_investor_r1753() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.expiring_documents_r1753(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_documents_r1753(int) TO authenticated;

COMMIT;