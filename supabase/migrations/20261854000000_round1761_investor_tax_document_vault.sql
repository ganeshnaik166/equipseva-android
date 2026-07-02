BEGIN;

-- =====================================================================
-- Round 1761 — Investor Tax Document Vault
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_tax_documents_r1761 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fiscal_year int NOT NULL,
  document_type text NOT NULL CHECK (document_type IN ('tds_certificate','form_16a','capital_gains','dividend_voucher','buyback_certificate')),
  document_url text,
  generated_at timestamptz,
  sent_at timestamptz,
  status text NOT NULL DEFAULT 'generated' CHECK (status IN ('generated','sent','acknowledged')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_tax_docs_r1761_investor ON public.investor_tax_documents_r1761(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_tax_docs_r1761_fy ON public.investor_tax_documents_r1761(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_inv_tax_docs_r1761_status ON public.investor_tax_documents_r1761(status);

CREATE TABLE IF NOT EXISTS public.investor_tax_doc_requests_r1761 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.investor_tax_documents_r1761(id) ON DELETE CASCADE,
  request_type text NOT NULL CHECK (request_type IN ('copy_request','clarification','dispute')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response_summary text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_tax_req_r1761_doc ON public.investor_tax_doc_requests_r1761(document_id);
CREATE INDEX IF NOT EXISTS idx_inv_tax_req_r1761_resolved ON public.investor_tax_doc_requests_r1761(resolved_at);

-- RLS
ALTER TABLE public.investor_tax_documents_r1761 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tax_doc_requests_r1761 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inv_tax_docs_r1761 ON public.investor_tax_documents_r1761;
CREATE POLICY founder_all_inv_tax_docs_r1761 ON public.investor_tax_documents_r1761
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_inv_tax_req_r1761 ON public.investor_tax_doc_requests_r1761;
CREATE POLICY founder_all_inv_tax_req_r1761 ON public.investor_tax_doc_requests_r1761
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPCs
-- =====================================================================

CREATE OR REPLACE FUNCTION public.list_documents_r1761()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  fiscal_year int,
  document_type text,
  document_url text,
  generated_at timestamptz,
  sent_at timestamptz,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.investor_id, p.email, d.fiscal_year, d.document_type,
         d.document_url, d.generated_at, d.sent_at, d.status, d.created_at
  FROM public.investor_tax_documents_r1761 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY d.fiscal_year DESC, d.created_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_document_r1761(
  p_investor_id uuid,
  p_fiscal_year int,
  p_document_type text,
  p_document_url text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_tax_documents_r1761(
    investor_id, fiscal_year, document_type, document_url, generated_at, status
  )
  VALUES (p_investor_id, p_fiscal_year, p_document_type, p_document_url, now(), 'generated')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'generate_document_r1761',
          jsonb_build_object('doc_id', v_id, 'investor_id', p_investor_id, 'fy', p_fiscal_year, 'type', p_document_type), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_requests_r1761()
RETURNS TABLE (
  id uuid,
  document_id uuid,
  document_type text,
  investor_email text,
  request_type text,
  requested_at timestamptz,
  by_email text,
  response_summary text,
  resolved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.document_id, d.document_type, p.email,
         r.request_type, r.requested_at, r.by_email, r.response_summary, r.resolved_at
  FROM public.investor_tax_doc_requests_r1761 r
  LEFT JOIN public.investor_tax_documents_r1761 d ON d.id = r.document_id
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  ORDER BY r.requested_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_request_r1761(
  p_document_id uuid,
  p_request_type text,
  p_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_tax_doc_requests_r1761(document_id, request_type, by_email, requested_at)
  VALUES (p_document_id, p_request_type, p_by_email, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_request_r1761',
          jsonb_build_object('req_id', v_id, 'doc_id', p_document_id, 'type', p_request_type), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_request_r1761(
  p_request_id uuid,
  p_response_summary text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_tax_doc_requests_r1761
  SET response_summary = p_response_summary,
      resolved_at = now(),
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'resolve_request_r1761',
          jsonb_build_object('req_id', p_request_id), now());
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.docs_summary_per_investor_r1761()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  total_docs int,
  generated_count int,
  sent_count int,
  acknowledged_count int,
  latest_fy int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.investor_id,
         p.email,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE d.status = 'generated'))::int,
         (COUNT(*) FILTER (WHERE d.status = 'sent'))::int,
         (COUNT(*) FILTER (WHERE d.status = 'acknowledged'))::int,
         MAX(d.fiscal_year)::int
  FROM public.investor_tax_documents_r1761 d
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  GROUP BY d.investor_id, p.email
  ORDER BY COUNT(*) DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.pending_requests_r1761()
RETURNS TABLE (
  id uuid,
  document_id uuid,
  document_type text,
  investor_email text,
  request_type text,
  requested_at timestamptz,
  by_email text,
  age_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.document_id, d.document_type, p.email,
         r.request_type, r.requested_at, r.by_email,
         ROUND(EXTRACT(EPOCH FROM (now() - r.requested_at))/3600.0, 2)
  FROM public.investor_tax_doc_requests_r1761 r
  LEFT JOIN public.investor_tax_documents_r1761 d ON d.id = r.document_id
  LEFT JOIN public.profiles p ON p.id = d.investor_id
  WHERE r.resolved_at IS NULL
  ORDER BY r.requested_at ASC
  LIMIT 200;
END;
$$;

-- GRANTs
REVOKE EXECUTE ON FUNCTION public.list_documents_r1761() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.generate_document_r1761(uuid, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_requests_r1761() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_request_r1761(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_request_r1761(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.docs_summary_per_investor_r1761() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pending_requests_r1761() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_documents_r1761() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_document_r1761(uuid, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_requests_r1761() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_request_r1761(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_request_r1761(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.docs_summary_per_investor_r1761() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_requests_r1761() TO authenticated;

COMMIT;