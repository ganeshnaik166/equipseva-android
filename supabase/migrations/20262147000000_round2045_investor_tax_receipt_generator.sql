BEGIN;

-- ============================================================================
-- Round 2045 - Investor Tax Receipt Generator
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_tax_receipts_r2045 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fiscal_year text NOT NULL,
  distribution_amount_rupees bigint NOT NULL DEFAULT 0,
  tax_withheld_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','disputed','superseded')),
  issued_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itr_r2045_investor ON public.investor_tax_receipts_r2045(investor_id);
CREATE INDEX IF NOT EXISTS idx_itr_r2045_year ON public.investor_tax_receipts_r2045(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_itr_r2045_status ON public.investor_tax_receipts_r2045(status);

CREATE TABLE IF NOT EXISTS public.investor_tax_receipt_action_log_r2045 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL REFERENCES public.investor_tax_receipts_r2045(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('generated','sent','disputed','reissued','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itral_r2045_receipt ON public.investor_tax_receipt_action_log_r2045(receipt_id);
CREATE INDEX IF NOT EXISTS idx_itral_r2045_taken ON public.investor_tax_receipt_action_log_r2045(taken_at DESC);

ALTER TABLE public.investor_tax_receipts_r2045 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_tax_receipt_action_log_r2045 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS itr_r2045_founder ON public.investor_tax_receipts_r2045;
CREATE POLICY itr_r2045_founder ON public.investor_tax_receipts_r2045
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS itral_r2045_founder ON public.investor_tax_receipt_action_log_r2045;
CREATE POLICY itral_r2045_founder ON public.investor_tax_receipt_action_log_r2045
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_receipts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_tax_receipts_r2045(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  fiscal_year text,
  distribution_amount_rupees bigint,
  tax_withheld_rupees bigint,
  status text,
  issued_at timestamptz,
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
    SELECT r.id, r.investor_id, r.fiscal_year, r.distribution_amount_rupees,
           r.tax_withheld_rupees, r.status, r.issued_at, r.captured_at
    FROM public.investor_tax_receipts_r2045 r
    ORDER BY r.captured_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================================
-- RPC 2: log_receipt
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_tax_receipt_r2045(
  p_investor_id uuid,
  p_fiscal_year text,
  p_distribution_amount_rupees bigint,
  p_tax_withheld_rupees bigint,
  p_status text DEFAULT 'draft'
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
  INSERT INTO public.investor_tax_receipts_r2045 (investor_id, fiscal_year, distribution_amount_rupees, tax_withheld_rupees, status)
  VALUES (p_investor_id, p_fiscal_year, p_distribution_amount_rupees, p_tax_withheld_rupees, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_tax_receipt_r2045',
          jsonb_build_object('receipt_id', v_id, 'investor_id', p_investor_id, 'fiscal_year', p_fiscal_year));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_tax_receipt_actions_r2045(p_receipt_id uuid)
RETURNS TABLE (
  id uuid,
  receipt_id uuid,
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
    SELECT a.id, a.receipt_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_tax_receipt_action_log_r2045 a
    WHERE a.receipt_id = p_receipt_id
    ORDER BY a.taken_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_tax_receipt_action_r2045(
  p_receipt_id uuid,
  p_action_type text,
  p_by_email text DEFAULT NULL,
  p_notes_md text DEFAULT NULL
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
  INSERT INTO public.investor_tax_receipt_action_log_r2045 (receipt_id, action_type, by_email, notes_md)
  VALUES (p_receipt_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_tax_receipt_action_r2045',
          jsonb_build_object('action_id', v_id, 'receipt_id', p_receipt_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_investor_tax_receipt_status_r2045(
  p_receipt_id uuid,
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
  UPDATE public.investor_tax_receipts_r2045
     SET status = p_status,
         issued_at = CASE WHEN p_status = 'issued' AND issued_at IS NULL THEN now() ELSE issued_at END,
         updated_at = now()
   WHERE id = p_receipt_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_tax_receipt_status_r2045',
          jsonb_build_object('receipt_id', p_receipt_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: by_year
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_tax_receipts_by_year_r2045(p_fiscal_year text)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  fiscal_year text,
  distribution_amount_rupees bigint,
  tax_withheld_rupees bigint,
  status text,
  issued_at timestamptz,
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
    SELECT r.id, r.investor_id, r.fiscal_year, r.distribution_amount_rupees,
           r.tax_withheld_rupees, r.status, r.issued_at, r.captured_at
    FROM public.investor_tax_receipts_r2045 r
    WHERE r.fiscal_year = p_fiscal_year
    ORDER BY r.captured_at DESC;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_recent_investor_tax_receipt_actions_r2045(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  receipt_id uuid,
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
    SELECT a.id, a.receipt_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_tax_receipt_action_log_r2045 a
    ORDER BY a.taken_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_investor_tax_receipts_r2045(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_tax_receipt_r2045(uuid, text, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_tax_receipt_actions_r2045(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_tax_receipt_action_r2045(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_tax_receipt_status_r2045(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_tax_receipts_by_year_r2045(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_recent_investor_tax_receipt_actions_r2045(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_tax_receipts_r2045(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_tax_receipt_r2045(uuid, text, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_tax_receipt_actions_r2045(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_tax_receipt_action_r2045(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_tax_receipt_status_r2045(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_tax_receipts_by_year_r2045(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_recent_investor_tax_receipt_actions_r2045(int) TO authenticated;

COMMIT;
