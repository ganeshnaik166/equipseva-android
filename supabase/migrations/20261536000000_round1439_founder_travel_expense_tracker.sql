BEGIN;
-- r1439: founder team travel + expense tracker (2 tables + 7 RPCs)


-- ============================================================================
-- TABLE 1: founder_travel_expense_categories
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_travel_expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_label text NOT NULL UNIQUE,
  category_kind text NOT NULL CHECK (category_kind IN (
    'travel_flight','travel_train','travel_road','accommodation','food',
    'client_entertainment','tools_equipment','subscription','marketing',
    'legal','accounting','other'
  )),
  monthly_budget_rupees numeric NOT NULL DEFAULT 0 CHECK (monthly_budget_rupees >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_te_categories_active ON public.founder_travel_expense_categories(is_active) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_te_categories_kind ON public.founder_travel_expense_categories(category_kind);

-- ============================================================================
-- TABLE 2: founder_travel_expense_claims
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_travel_expense_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claimant_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id uuid REFERENCES public.founder_travel_expense_categories(id) ON DELETE SET NULL,
  expense_date date NOT NULL,
  amount_rupees numeric NOT NULL CHECK (amount_rupees >= 0),
  description text,
  receipt_uri text,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted','approved','reimbursed','rejected','disputed'
  )),
  reimbursed_at timestamptz,
  reimbursed_via text,
  gst_invoiced boolean NOT NULL DEFAULT false,
  founder_response text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_te_claims_status ON public.founder_travel_expense_claims(status);
CREATE INDEX IF NOT EXISTS idx_te_claims_claimant ON public.founder_travel_expense_claims(claimant_user_id);
CREATE INDEX IF NOT EXISTS idx_te_claims_expense_date ON public.founder_travel_expense_claims(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_te_claims_category ON public.founder_travel_expense_claims(category_id);

-- ============================================================================
-- RLS
-- ============================================================================
ALTER TABLE public.founder_travel_expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_travel_expense_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS te_cat_founder_all ON public.founder_travel_expense_categories;
CREATE POLICY te_cat_founder_all ON public.founder_travel_expense_categories
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS te_claims_founder_all ON public.founder_travel_expense_claims;
CREATE POLICY te_claims_founder_all ON public.founder_travel_expense_claims
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS te_claims_own_select ON public.founder_travel_expense_claims;
CREATE POLICY te_claims_own_select ON public.founder_travel_expense_claims
  FOR SELECT TO authenticated USING (claimant_user_id = auth.uid());

DROP POLICY IF EXISTS te_claims_own_insert ON public.founder_travel_expense_claims;
CREATE POLICY te_claims_own_insert ON public.founder_travel_expense_claims
  FOR INSERT TO authenticated WITH CHECK (claimant_user_id = auth.uid());

-- ============================================================================
-- RPC 1: founder_travel_expense_summary (16 KPIs)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_travel_expense_summary()
RETURNS TABLE (
  total_categories integer,
  active_categories integer,
  total_monthly_budget_rupees numeric,
  total_claims_lifetime integer,
  total_claims_30d integer,
  total_claims_pending integer,
  total_claims_approved integer,
  total_claims_reimbursed integer,
  total_claims_rejected integer,
  total_claims_disputed integer,
  total_spent_lifetime_rupees numeric,
  total_spent_30d_rupees numeric,
  total_reimbursed_rupees numeric,
  total_outstanding_rupees numeric,
  distinct_claimants integer,
  top_category_label text,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cats AS (
    SELECT COUNT(*)::int AS total_c, COUNT(*) FILTER (WHERE is_active)::int AS active_c,
           COALESCE(SUM(monthly_budget_rupees) FILTER (WHERE is_active),0)::numeric AS budget
    FROM public.founder_travel_expense_categories
  ),
  cl AS (
    SELECT
      COUNT(*)::int AS lifetime,
      COUNT(*) FILTER (WHERE submitted_at >= now() - interval '30 days')::int AS d30,
      COUNT(*) FILTER (WHERE status = 'submitted')::int AS pending_c,
      COUNT(*) FILTER (WHERE status = 'approved')::int AS approved_c,
      COUNT(*) FILTER (WHERE status = 'reimbursed')::int AS reimb_c,
      COUNT(*) FILTER (WHERE status = 'rejected')::int AS rej_c,
      COUNT(*) FILTER (WHERE status = 'disputed')::int AS disp_c,
      COALESCE(SUM(amount_rupees),0)::numeric AS spent_lifetime,
      COALESCE(SUM(amount_rupees) FILTER (WHERE submitted_at >= now() - interval '30 days'),0)::numeric AS spent_30,
      COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'reimbursed'),0)::numeric AS reimb_amt,
      COALESCE(SUM(amount_rupees) FILTER (WHERE status IN ('submitted','approved')),0)::numeric AS outstanding_amt,
      COUNT(DISTINCT claimant_user_id)::int AS claimants_c
    FROM public.founder_travel_expense_claims
  ),
  top_cat AS (
    SELECT c.category_label
    FROM public.founder_travel_expense_claims cl
    JOIN public.founder_travel_expense_categories c ON c.id = cl.category_id
    GROUP BY c.category_label
    ORDER BY SUM(cl.amount_rupees) DESC NULLS LAST
    LIMIT 1
  )
  SELECT cats.total_c, cats.active_c, cats.budget,
         cl.lifetime, cl.d30, cl.pending_c, cl.approved_c, cl.reimb_c, cl.rej_c, cl.disp_c,
         cl.spent_lifetime, cl.spent_30, cl.reimb_amt, cl.outstanding_amt, cl.claimants_c,
         (SELECT category_label FROM top_cat), now()
  FROM cats, cl;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_travel_expense_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_travel_expense_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_travel_expense_categories_recent
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_travel_expense_categories_recent()
RETURNS TABLE (
  id uuid, category_label text, category_kind text,
  monthly_budget_rupees numeric, is_active boolean,
  spent_30d_rupees numeric, claims_30d integer, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.category_label, c.category_kind, c.monthly_budget_rupees, c.is_active,
         COALESCE(SUM(cl.amount_rupees) FILTER (WHERE cl.submitted_at >= now() - interval '30 days'),0)::numeric,
         COUNT(cl.id) FILTER (WHERE cl.submitted_at >= now() - interval '30 days')::int,
         c.updated_at
  FROM public.founder_travel_expense_categories c
  LEFT JOIN public.founder_travel_expense_claims cl ON cl.category_id = c.id
  GROUP BY c.id
  ORDER BY c.is_active DESC, c.category_label ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_travel_expense_categories_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_travel_expense_categories_recent() TO authenticated;

-- ============================================================================
-- RPC 3: founder_travel_expense_claims_recent
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_travel_expense_claims_recent()
RETURNS TABLE (
  id uuid, category_label text, claimant_email text,
  expense_date date, amount_rupees numeric, description text,
  status text, gst_invoiced boolean, submitted_at timestamptz,
  reimbursed_at timestamptz, founder_response text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT cl.id, c.category_label, u.email::text,
         cl.expense_date, cl.amount_rupees, cl.description,
         cl.status, cl.gst_invoiced, cl.submitted_at, cl.reimbursed_at, cl.founder_response
  FROM public.founder_travel_expense_claims cl
  LEFT JOIN public.founder_travel_expense_categories c ON c.id = cl.category_id
  LEFT JOIN auth.users u ON u.id = cl.claimant_user_id
  ORDER BY cl.submitted_at DESC
  LIMIT 60;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_travel_expense_claims_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_travel_expense_claims_recent() TO authenticated;

-- ============================================================================
-- RPC 4: founder_travel_expense_claims_pending
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_travel_expense_claims_pending()
RETURNS TABLE (
  id uuid, category_label text, claimant_email text,
  expense_date date, amount_rupees numeric, description text,
  submitted_at timestamptz, days_waiting integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT cl.id, c.category_label, u.email::text,
         cl.expense_date, cl.amount_rupees, cl.description, cl.submitted_at,
         GREATEST(0, EXTRACT(day FROM now() - cl.submitted_at))::int
  FROM public.founder_travel_expense_claims cl
  LEFT JOIN public.founder_travel_expense_categories c ON c.id = cl.category_id
  LEFT JOIN auth.users u ON u.id = cl.claimant_user_id
  WHERE cl.status = 'submitted'
  ORDER BY cl.submitted_at ASC
  LIMIT 40;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_travel_expense_claims_pending() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_travel_expense_claims_pending() TO authenticated;

-- ============================================================================
-- RPC 5: claimant_travel_expense_my_claims (auth user own claims)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.claimant_travel_expense_my_claims()
RETURNS TABLE (
  id uuid, category_label text, expense_date date,
  amount_rupees numeric, description text, status text,
  submitted_at timestamptz, reimbursed_at timestamptz, founder_response text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  RETURN QUERY
  SELECT cl.id, c.category_label, cl.expense_date, cl.amount_rupees,
         cl.description, cl.status, cl.submitted_at, cl.reimbursed_at, cl.founder_response
  FROM public.founder_travel_expense_claims cl
  LEFT JOIN public.founder_travel_expense_categories c ON c.id = cl.category_id
  WHERE cl.claimant_user_id = auth.uid()
  ORDER BY cl.submitted_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.claimant_travel_expense_my_claims() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claimant_travel_expense_my_claims() TO authenticated;

-- ============================================================================
-- RPC 6: claimant_travel_expense_submit_claim (auth user submits claim)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.claimant_travel_expense_submit_claim(
  p_category_id uuid,
  p_expense_date date,
  p_amount_rupees numeric,
  p_description text,
  p_receipt_uri text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF p_amount_rupees IS NULL OR p_amount_rupees < 0 THEN RAISE EXCEPTION 'invalid amount'; END IF;
  IF p_expense_date IS NULL THEN RAISE EXCEPTION 'expense_date required'; END IF;

  INSERT INTO public.founder_travel_expense_claims(
    claimant_user_id, category_id, expense_date, amount_rupees, description, receipt_uri, status
  ) VALUES (
    auth.uid(), p_category_id, p_expense_date, p_amount_rupees, p_description, p_receipt_uri, 'submitted'
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.claimant_travel_expense_submit_claim(uuid, date, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claimant_travel_expense_submit_claim(uuid, date, numeric, text, text) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_te_review_claim (founder approves/rejects/reimburses)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_te_review_claim(
  p_claim_id uuid,
  p_status text,
  p_founder_response text,
  p_reimbursed_via text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('submitted','approved','reimbursed','rejected','disputed') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE public.founder_travel_expense_claims SET
    status = p_status,
    founder_response = COALESCE(p_founder_response, founder_response),
    reimbursed_via = COALESCE(p_reimbursed_via, reimbursed_via),
    reimbursed_at = CASE WHEN p_status = 'reimbursed' AND reimbursed_at IS NULL THEN now() ELSE reimbursed_at END,
    reviewed_by = auth.uid()
  WHERE id = p_claim_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'claim not found %', p_claim_id; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_te_review_claim(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_te_review_claim(uuid, text, text, text) TO authenticated;

COMMIT;