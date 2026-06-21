BEGIN;

-- ============================================================================
-- Round r1869 — Investor Capital Recall Log
-- ============================================================================

-- Table 1: investor_capital_recalls_r1869
CREATE TABLE IF NOT EXISTS public.investor_capital_recalls_r1869 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recall_amount_rupees bigint NOT NULL CHECK (recall_amount_rupees >= 0),
  recall_reason text NOT NULL CHECK (recall_reason IN ('change_of_mind','fund_crisis','regulatory','personal','strategic')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','negotiating','refunded','declined','closed')),
  decided_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icr_r1869_investor ON public.investor_capital_recalls_r1869(investor_id);
CREATE INDEX IF NOT EXISTS idx_icr_r1869_status ON public.investor_capital_recalls_r1869(status);
CREATE INDEX IF NOT EXISTS idx_icr_r1869_requested ON public.investor_capital_recalls_r1869(requested_at DESC);

ALTER TABLE public.investor_capital_recalls_r1869 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_icr_r1869_founder ON public.investor_capital_recalls_r1869;
CREATE POLICY p_icr_r1869_founder ON public.investor_capital_recalls_r1869
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: investor_capital_recall_documents_r1869
CREATE TABLE IF NOT EXISTS public.investor_capital_recall_documents_r1869 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recall_id uuid NOT NULL REFERENCES public.investor_capital_recalls_r1869(id) ON DELETE CASCADE,
  document_type text NOT NULL CHECK (document_type IN ('legal_notice','correspondence','board_minute','settlement')),
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  document_url text NOT NULL,
  uploaded_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icrd_r1869_recall ON public.investor_capital_recall_documents_r1869(recall_id);
CREATE INDEX IF NOT EXISTS idx_icrd_r1869_type ON public.investor_capital_recall_documents_r1869(document_type);

ALTER TABLE public.investor_capital_recall_documents_r1869 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_icrd_r1869_founder ON public.investor_capital_recall_documents_r1869;
CREATE POLICY p_icrd_r1869_founder ON public.investor_capital_recall_documents_r1869
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7) — all SECDEF, plpgsql, founder-gated
-- ============================================================================

-- 1. list_recalls
DROP FUNCTION IF EXISTS public.list_recalls_r1869();
CREATE OR REPLACE FUNCTION public.list_recalls_r1869()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  recall_amount_rupees bigint,
  recall_reason text,
  requested_at timestamptz,
  status text,
  decided_at timestamptz,
  notes text,
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
    r.id,
    r.investor_id,
    p.email::text AS investor_email,
    r.recall_amount_rupees,
    r.recall_reason,
    r.requested_at,
    r.status,
    r.decided_at,
    r.notes,
    (SELECT COUNT(*) FROM public.investor_capital_recall_documents_r1869 d WHERE d.recall_id = r.id)::int AS document_count
  FROM public.investor_capital_recalls_r1869 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY r.requested_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_recall
DROP FUNCTION IF EXISTS public.log_recall_r1869(uuid, bigint, text, text);
CREATE OR REPLACE FUNCTION public.log_recall_r1869(
  p_investor_id uuid,
  p_recall_amount_rupees bigint,
  p_recall_reason text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_capital_recalls_r1869(
    investor_id, recall_amount_rupees, recall_reason, notes
  ) VALUES (
    p_investor_id, p_recall_amount_rupees, p_recall_reason, p_notes
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_recall_r1869',
    jsonb_build_object(
      'recall_id', v_id,
      'investor_id', p_investor_id,
      'recall_amount_rupees', p_recall_amount_rupees,
      'recall_reason', p_recall_reason
    )
  );

  RETURN v_id;
END;
$$;

-- 3. list_documents
DROP FUNCTION IF EXISTS public.list_documents_r1869(uuid);
CREATE OR REPLACE FUNCTION public.list_documents_r1869(p_recall_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  recall_id uuid,
  document_type text,
  uploaded_at timestamptz,
  document_url text,
  uploaded_by_email text
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
    d.id,
    d.recall_id,
    d.document_type,
    d.uploaded_at,
    d.document_url,
    d.uploaded_by_email
  FROM public.investor_capital_recall_documents_r1869 d
  WHERE (p_recall_id IS NULL OR d.recall_id = p_recall_id)
  ORDER BY d.uploaded_at DESC
  LIMIT 200;
END;
$$;

-- 4. attach_document
DROP FUNCTION IF EXISTS public.attach_document_r1869(uuid, text, text);
CREATE OR REPLACE FUNCTION public.attach_document_r1869(
  p_recall_id uuid,
  p_document_type text,
  p_document_url text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.investor_capital_recall_documents_r1869(
    recall_id, document_type, document_url, uploaded_by_email
  ) VALUES (
    p_recall_id, p_document_type, p_document_url, v_email
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'attach_document_r1869',
    jsonb_build_object(
      'document_id', v_id,
      'recall_id', p_recall_id,
      'document_type', p_document_type
    )
  );

  RETURN v_id;
END;
$$;

-- 5. close_recall
DROP FUNCTION IF EXISTS public.close_recall_r1869(uuid, text);
CREATE OR REPLACE FUNCTION public.close_recall_r1869(
  p_recall_id uuid,
  p_final_status text
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

  IF p_final_status NOT IN ('refunded','declined','closed') THEN
    RAISE EXCEPTION 'invalid final status: %', p_final_status;
  END IF;

  UPDATE public.investor_capital_recalls_r1869
  SET status = p_final_status,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_recall_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'close_recall_r1869',
    jsonb_build_object(
      'recall_id', p_recall_id,
      'final_status', p_final_status
    )
  );
END;
$$;

-- 6. total_recall_value
DROP FUNCTION IF EXISTS public.total_recall_value_r1869();
CREATE OR REPLACE FUNCTION public.total_recall_value_r1869()
RETURNS TABLE (
  total_open_rupees bigint,
  total_negotiating_rupees bigint,
  total_refunded_rupees bigint,
  total_declined_rupees bigint,
  open_count int,
  negotiating_count int,
  refunded_count int,
  declined_count int,
  closed_count int
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
    COALESCE(SUM(recall_amount_rupees) FILTER (WHERE status = 'open'), 0)::bigint,
    COALESCE(SUM(recall_amount_rupees) FILTER (WHERE status = 'negotiating'), 0)::bigint,
    COALESCE(SUM(recall_amount_rupees) FILTER (WHERE status = 'refunded'), 0)::bigint,
    COALESCE(SUM(recall_amount_rupees) FILTER (WHERE status = 'declined'), 0)::bigint,
    (COUNT(*) FILTER (WHERE status = 'open'))::int,
    (COUNT(*) FILTER (WHERE status = 'negotiating'))::int,
    (COUNT(*) FILTER (WHERE status = 'refunded'))::int,
    (COUNT(*) FILTER (WHERE status = 'declined'))::int,
    (COUNT(*) FILTER (WHERE status = 'closed'))::int
  FROM public.investor_capital_recalls_r1869;
END;
$$;

-- 7. recent_recalls
DROP FUNCTION IF EXISTS public.recent_recalls_r1869();
CREATE OR REPLACE FUNCTION public.recent_recalls_r1869()
RETURNS TABLE (
  id uuid,
  investor_email text,
  recall_amount_rupees bigint,
  recall_reason text,
  status text,
  requested_at timestamptz
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
    r.id,
    p.email::text AS investor_email,
    r.recall_amount_rupees,
    r.recall_reason,
    r.status,
    r.requested_at
  FROM public.investor_capital_recalls_r1869 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  WHERE r.requested_at >= now() - interval '60 days'
  ORDER BY r.requested_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_recalls_r1869() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_recall_r1869(uuid, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_documents_r1869(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.attach_document_r1869(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_recall_r1869(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_recall_value_r1869() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_recalls_r1869() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_recalls_r1869() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_recall_r1869(uuid, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_documents_r1869(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attach_document_r1869(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_recall_r1869(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_recall_value_r1869() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_recalls_r1869() TO authenticated;

COMMIT;