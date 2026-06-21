BEGIN;

-- ============================================================================
-- Round 1857: Investor 422 Substantial Test Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_422_substantial_tests_r1857 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  fiscal_year int NOT NULL,
  holding_period_years numeric(6,2) NOT NULL DEFAULT 0,
  founded_at_invest date,
  holding_test_passed boolean NOT NULL DEFAULT false,
  c_corp_test_passed boolean NOT NULL DEFAULT false,
  gross_assets_test_passed boolean NOT NULL DEFAULT false,
  qsbs_eligible boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'under_review' CHECK (status IN ('verified','under_review','non_qualifying')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv422_tests_r1857_investor ON public.investor_422_substantial_tests_r1857(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv422_tests_r1857_year ON public.investor_422_substantial_tests_r1857(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_inv422_tests_r1857_status ON public.investor_422_substantial_tests_r1857(status);

CREATE TABLE IF NOT EXISTS public.investor_422_test_documents_r1857 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id uuid NOT NULL REFERENCES public.investor_422_substantial_tests_r1857(id) ON DELETE CASCADE,
  doc_type text NOT NULL CHECK (doc_type IN ('share_purchase_agreement','articles_of_inc','c_corp_election','holding_period_proof')),
  doc_url text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv422_docs_r1857_test ON public.investor_422_test_documents_r1857(test_id);
CREATE INDEX IF NOT EXISTS idx_inv422_docs_r1857_type ON public.investor_422_test_documents_r1857(doc_type);

ALTER TABLE public.investor_422_substantial_tests_r1857 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_422_test_documents_r1857 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_inv422_tests_r1857 ON public.investor_422_substantial_tests_r1857;
CREATE POLICY founder_all_inv422_tests_r1857 ON public.investor_422_substantial_tests_r1857
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_inv422_docs_r1857 ON public.investor_422_test_documents_r1857;
CREATE POLICY founder_all_inv422_docs_r1857 ON public.investor_422_test_documents_r1857
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_tests
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_list_tests_r1857();
CREATE OR REPLACE FUNCTION public.inv422_list_tests_r1857()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  fiscal_year int,
  holding_period_years numeric,
  founded_at_invest date,
  holding_test_passed boolean,
  c_corp_test_passed boolean,
  gross_assets_test_passed boolean,
  qsbs_eligible boolean,
  status text,
  created_at timestamptz
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
  SELECT t.id, t.investor_id, t.fiscal_year, t.holding_period_years, t.founded_at_invest,
         t.holding_test_passed, t.c_corp_test_passed, t.gross_assets_test_passed,
         t.qsbs_eligible, t.status, t.created_at
  FROM public.investor_422_substantial_tests_r1857 t
  ORDER BY t.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_list_tests_r1857() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_list_tests_r1857() TO authenticated;

-- ============================================================================
-- RPC 2: run_test (recomputes & writes)
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_run_test_r1857(uuid);
CREATE OR REPLACE FUNCTION public.inv422_run_test_r1857(p_test_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_holding numeric;
  v_holding_pass boolean;
  v_founded date;
  v_qsbs boolean;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT holding_period_years, founded_at_invest
  INTO v_holding, v_founded
  FROM public.investor_422_substantial_tests_r1857
  WHERE id = p_test_id;

  v_holding_pass := COALESCE(v_holding, 0) >= 5;

  UPDATE public.investor_422_substantial_tests_r1857
  SET holding_test_passed = v_holding_pass,
      qsbs_eligible = v_holding_pass AND c_corp_test_passed AND gross_assets_test_passed,
      status = CASE
        WHEN v_holding_pass AND c_corp_test_passed AND gross_assets_test_passed THEN 'verified'
        WHEN NOT (c_corp_test_passed AND gross_assets_test_passed) THEN 'non_qualifying'
        ELSE 'under_review'
      END,
      updated_at = now()
  WHERE id = p_test_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv422_run_test_r1857',
          jsonb_build_object('test_id', p_test_id, 'holding_pass', v_holding_pass));

  RETURN p_test_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_run_test_r1857(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_run_test_r1857(uuid) TO authenticated;

-- ============================================================================
-- RPC 3: list_documents
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_list_documents_r1857(uuid);
CREATE OR REPLACE FUNCTION public.inv422_list_documents_r1857(p_test_id uuid)
RETURNS TABLE (
  id uuid,
  test_id uuid,
  doc_type text,
  doc_url text,
  uploaded_at timestamptz
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
  SELECT d.id, d.test_id, d.doc_type, d.doc_url, d.uploaded_at
  FROM public.investor_422_test_documents_r1857 d
  WHERE (p_test_id IS NULL OR d.test_id = p_test_id)
  ORDER BY d.uploaded_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_list_documents_r1857(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_list_documents_r1857(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: attach_document
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_attach_document_r1857(uuid, text, text);
CREATE OR REPLACE FUNCTION public.inv422_attach_document_r1857(p_test_id uuid, p_doc_type text, p_doc_url text)
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

  INSERT INTO public.investor_422_test_documents_r1857 (test_id, doc_type, doc_url)
  VALUES (p_test_id, p_doc_type, p_doc_url)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv422_attach_document_r1857',
          jsonb_build_object('doc_id', v_id, 'test_id', p_test_id, 'doc_type', p_doc_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_attach_document_r1857(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_attach_document_r1857(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_verified
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_mark_verified_r1857(uuid);
CREATE OR REPLACE FUNCTION public.inv422_mark_verified_r1857(p_test_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.investor_422_substantial_tests_r1857
  SET status = 'verified',
      qsbs_eligible = true,
      updated_at = now()
  WHERE id = p_test_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv422_mark_verified_r1857',
          jsonb_build_object('test_id', p_test_id));

  RETURN p_test_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_mark_verified_r1857(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_mark_verified_r1857(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: qsbs_eligible_investors
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_qsbs_eligible_investors_r1857();
CREATE OR REPLACE FUNCTION public.inv422_qsbs_eligible_investors_r1857()
RETURNS TABLE (
  investor_id uuid,
  fiscal_year int,
  holding_period_years numeric,
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
  SELECT t.investor_id, t.fiscal_year, t.holding_period_years, t.status
  FROM public.investor_422_substantial_tests_r1857 t
  WHERE t.qsbs_eligible = true
  ORDER BY t.holding_period_years DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_qsbs_eligible_investors_r1857() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_qsbs_eligible_investors_r1857() TO authenticated;

-- ============================================================================
-- RPC 7: expiring_holdings (holding period approaching 5 years from below)
-- ============================================================================
DROP FUNCTION IF EXISTS public.inv422_expiring_holdings_r1857();
CREATE OR REPLACE FUNCTION public.inv422_expiring_holdings_r1857()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  holding_period_years numeric,
  founded_at_invest date,
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
  SELECT t.id, t.investor_id, t.holding_period_years, t.founded_at_invest, t.status
  FROM public.investor_422_substantial_tests_r1857 t
  WHERE t.holding_period_years BETWEEN 4 AND 5
    AND t.qsbs_eligible = false
  ORDER BY t.holding_period_years DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.inv422_expiring_holdings_r1857() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv422_expiring_holdings_r1857() TO authenticated;

COMMIT;