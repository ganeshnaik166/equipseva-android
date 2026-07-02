BEGIN;

-- =============================================================================
-- Round 1812: Engineer Expense Reimbursement
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.engineer_expense_claims_r1812 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  claim_date date NOT NULL DEFAULT CURRENT_DATE,
  expense_type text NOT NULL CHECK (expense_type IN ('travel','equipment','parts','customer_gift','training','other')),
  amount_rupees int NOT NULL CHECK (amount_rupees >= 0),
  receipt_url text,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','in_review','approved','rejected','paid')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eec_r1812_engineer ON public.engineer_expense_claims_r1812(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eec_r1812_status ON public.engineer_expense_claims_r1812(status);
CREATE INDEX IF NOT EXISTS idx_eec_r1812_claim_date ON public.engineer_expense_claims_r1812(claim_date DESC);

CREATE TABLE IF NOT EXISTS public.engineer_expense_review_log_r1812 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.engineer_expense_claims_r1812(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('approve','reject','needs_info')),
  decision_note text,
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eerl_r1812_claim ON public.engineer_expense_review_log_r1812(claim_id);
CREATE INDEX IF NOT EXISTS idx_eerl_r1812_decided ON public.engineer_expense_review_log_r1812(decided_at DESC);

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

ALTER TABLE public.engineer_expense_claims_r1812 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_expense_review_log_r1812 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_eec_r1812_founder ON public.engineer_expense_claims_r1812;
CREATE POLICY p_eec_r1812_founder ON public.engineer_expense_claims_r1812
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_eerl_r1812_founder ON public.engineer_expense_review_log_r1812;
CREATE POLICY p_eerl_r1812_founder ON public.engineer_expense_review_log_r1812
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -----------------------------------------------------------------------------
-- RPCs
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_engineer_expense_claims_r1812()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  claim_date date,
  expense_type text,
  amount_rupees int,
  receipt_url text,
  repair_job_id uuid,
  status text,
  decided_at timestamptz,
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
  SELECT c.id, c.engineer_user_id, p.email, c.claim_date, c.expense_type,
         c.amount_rupees, c.receipt_url, c.repair_job_id, c.status,
         c.decided_at, c.created_at
  FROM public.engineer_expense_claims_r1812 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_engineer_expense_claim_r1812(
  p_engineer_user_id uuid,
  p_expense_type text,
  p_amount_rupees int,
  p_receipt_url text,
  p_repair_job_id uuid,
  p_claim_date date
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
  INSERT INTO public.engineer_expense_claims_r1812(
    engineer_user_id, expense_type, amount_rupees, receipt_url, repair_job_id, claim_date
  ) VALUES (
    p_engineer_user_id, p_expense_type, p_amount_rupees, p_receipt_url, p_repair_job_id, COALESCE(p_claim_date, CURRENT_DATE)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'submit_engineer_expense_claim_r1812',
          jsonb_build_object('claim_id', v_id, 'engineer_user_id', p_engineer_user_id, 'amount_rupees', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_engineer_expense_reviews_r1812(p_claim_id uuid)
RETURNS TABLE(
  id uuid,
  claim_id uuid,
  reviewer_email text,
  decision text,
  decision_note text,
  decided_at timestamptz
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
  SELECT r.id, r.claim_id, r.reviewer_email, r.decision, r.decision_note, r.decided_at
  FROM public.engineer_expense_review_log_r1812 r
  WHERE p_claim_id IS NULL OR r.claim_id = p_claim_id
  ORDER BY r.decided_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_engineer_expense_review_r1812(
  p_claim_id uuid,
  p_decision text,
  p_decision_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := COALESCE(auth.jwt()->>'email','unknown');

  INSERT INTO public.engineer_expense_review_log_r1812(claim_id, reviewer_email, decision, decision_note)
  VALUES (p_claim_id, v_email, p_decision, p_decision_note)
  RETURNING id INTO v_id;

  v_new_status := CASE p_decision
                    WHEN 'approve' THEN 'approved'
                    WHEN 'reject' THEN 'rejected'
                    ELSE 'in_review'
                  END;

  UPDATE public.engineer_expense_claims_r1812
  SET status = v_new_status,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_engineer_expense_review_r1812',
          jsonb_build_object('claim_id', p_claim_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_engineer_expense_paid_r1812(p_claim_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_expense_claims_r1812
  SET status = 'paid', decided_at = now(), updated_at = now()
  WHERE id = p_claim_id AND status = 'approved';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_engineer_expense_paid_r1812',
          jsonb_build_object('claim_id', p_claim_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.pending_engineer_expense_summary_r1812()
RETURNS TABLE(
  status text,
  claim_count int,
  total_amount_rupees bigint
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
  SELECT c.status,
         COUNT(*)::int AS claim_count,
         COALESCE(SUM(c.amount_rupees),0)::bigint AS total_amount_rupees
  FROM public.engineer_expense_claims_r1812 c
  GROUP BY c.status
  ORDER BY c.status;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_engineer_expense_claimers_r1812()
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  claim_count int,
  approved_count int,
  total_rupees bigint
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
  SELECT c.engineer_user_id,
         p.email,
         COUNT(*)::int AS claim_count,
         (COUNT(*) FILTER (WHERE c.status IN ('approved','paid')))::int AS approved_count,
         COALESCE(SUM(c.amount_rupees) FILTER (WHERE c.status IN ('approved','paid')),0)::bigint AS total_rupees
  FROM public.engineer_expense_claims_r1812 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  GROUP BY c.engineer_user_id, p.email
  ORDER BY total_rupees DESC
  LIMIT 20;
END;
$$;

-- -----------------------------------------------------------------------------
-- Grants
-- -----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_engineer_expense_claims_r1812() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_engineer_expense_claims_r1812() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.submit_engineer_expense_claim_r1812(uuid, text, int, text, uuid, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_engineer_expense_claim_r1812(uuid, text, int, text, uuid, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_engineer_expense_reviews_r1812(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_engineer_expense_reviews_r1812(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_expense_review_r1812(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_engineer_expense_review_r1812(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_engineer_expense_paid_r1812(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_engineer_expense_paid_r1812(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.pending_engineer_expense_summary_r1812() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.pending_engineer_expense_summary_r1812() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_engineer_expense_claimers_r1812() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_engineer_expense_claimers_r1812() TO authenticated;

COMMIT;