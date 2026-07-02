BEGIN;
-- r1403 — Tax & GST Automation Hub
-- 2 tables (founder_tax_filing_runs + founder_tds_payment_ledger) + 8 RPCs
-- Extends r1316 (GST quarterly prep). Founder-only.



-- ============ TABLES ============

CREATE TABLE IF NOT EXISTS public.founder_tax_filing_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  filing_kind text NOT NULL CHECK (filing_kind IN (
    'gstr1','gstr3b','gstr9','gstr9c',
    'tds_24q','tds_26q','tds_27q','tds_27eq',
    'it_return_company','it_return_director',
    'professional_tax','tds_payment'
  )),
  filing_period_label text NOT NULL,
  filing_period_start date NOT NULL,
  filing_period_end date NOT NULL,
  run_status text NOT NULL DEFAULT 'draft' CHECK (run_status IN (
    'draft','submitted','accepted','rejected','revised','overdue'
  )),
  arn text,
  amount_rupees numeric(14,2),
  ca_reviewed boolean NOT NULL DEFAULT false,
  ca_reviewer_name text,
  submitted_at timestamptz,
  accepted_at timestamptz,
  revised_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (filing_kind, filing_period_label)
);

CREATE INDEX IF NOT EXISTS idx_tax_filing_runs_status ON public.founder_tax_filing_runs(run_status);
CREATE INDEX IF NOT EXISTS idx_tax_filing_runs_kind ON public.founder_tax_filing_runs(filing_kind);
CREATE INDEX IF NOT EXISTS idx_tax_filing_runs_period_end ON public.founder_tax_filing_runs(filing_period_end DESC);

ALTER TABLE public.founder_tax_filing_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_tax_filing_runs_founder ON public.founder_tax_filing_runs;
CREATE POLICY p_tax_filing_runs_founder ON public.founder_tax_filing_runs
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_tds_payment_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_kind text NOT NULL CHECK (payment_kind IN (
    '194c','194h','194j','194o','194q','non_resident_194i','professional_tax'
  )),
  payee_name text NOT NULL,
  payee_pan text,
  gross_amount_rupees numeric(14,2) NOT NULL,
  tds_rate_pct numeric(6,2) NOT NULL,
  tds_amount_rupees numeric(14,2) NOT NULL,
  deducted_at date NOT NULL,
  deposited_at date,
  challan_no text,
  challan_url text,
  form_16_url text,
  assessment_year text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tds_ledger_kind ON public.founder_tds_payment_ledger(payment_kind);
CREATE INDEX IF NOT EXISTS idx_tds_ledger_deducted_at ON public.founder_tds_payment_ledger(deducted_at DESC);
CREATE INDEX IF NOT EXISTS idx_tds_ledger_ay ON public.founder_tds_payment_ledger(assessment_year);

ALTER TABLE public.founder_tds_payment_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_tds_payment_ledger_founder ON public.founder_tds_payment_ledger;
CREATE POLICY p_tds_payment_ledger_founder ON public.founder_tds_payment_ledger
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============ RPC 1: SUMMARY (18 KPIs) ============
DROP FUNCTION IF EXISTS public.founder_tax_gst_hub_summary();
CREATE OR REPLACE FUNCTION public.founder_tax_gst_hub_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT jsonb_build_object(
    'filings_total', (SELECT COUNT(*) FROM public.founder_tax_filing_runs),
    'gst_filings_filed_ytd', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs
      WHERE filing_kind IN ('gstr1','gstr3b','gstr9','gstr9c')
        AND run_status IN ('submitted','accepted','revised')
        AND filing_period_start >= date_trunc('year', CURRENT_DATE)
    ),
    'gst_pending_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs
      WHERE filing_kind IN ('gstr1','gstr3b','gstr9','gstr9c')
        AND run_status IN ('draft','overdue')
    ),
    'tds_filings_filed_ytd', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs
      WHERE filing_kind IN ('tds_24q','tds_26q','tds_27q','tds_27eq')
        AND run_status IN ('submitted','accepted','revised')
        AND filing_period_start >= date_trunc('year', CURRENT_DATE)
    ),
    'tds_payments_total', (SELECT COUNT(*) FROM public.founder_tds_payment_ledger),
    'tds_amount_deducted_lifetime', (
      SELECT COALESCE(SUM(tds_amount_rupees),0)::numeric(14,2)
      FROM public.founder_tds_payment_ledger
    ),
    'tds_amount_deducted_ytd', (
      SELECT COALESCE(SUM(tds_amount_rupees),0)::numeric(14,2)
      FROM public.founder_tds_payment_ledger
      WHERE deducted_at >= date_trunc('year', CURRENT_DATE)
    ),
    'tds_amount_deposited_ytd', (
      SELECT COALESCE(SUM(tds_amount_rupees),0)::numeric(14,2)
      FROM public.founder_tds_payment_ledger
      WHERE deposited_at IS NOT NULL
        AND deposited_at >= date_trunc('year', CURRENT_DATE)
    ),
    'tds_deposit_pending_count', (
      SELECT COUNT(*) FROM public.founder_tds_payment_ledger
      WHERE deposited_at IS NULL
    ),
    'ca_review_pending_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs
      WHERE ca_reviewed = false AND run_status = 'draft'
    ),
    'ca_reviewed_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs WHERE ca_reviewed = true
    ),
    'overdue_filings_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs
      WHERE run_status = 'overdue'
         OR (run_status = 'draft' AND filing_period_end < CURRENT_DATE - INTERVAL '20 days')
    ),
    'rejected_filings_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs WHERE run_status = 'rejected'
    ),
    'revised_filings_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs WHERE run_status = 'revised'
    ),
    'accepted_filings_count', (
      SELECT COUNT(*) FROM public.founder_tax_filing_runs WHERE run_status = 'accepted'
    ),
    'average_filing_lag_days', (
      SELECT COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (submitted_at - (filing_period_end + INTERVAL '1 day')))/86400)::numeric, 1), 0)
      FROM public.founder_tax_filing_runs
      WHERE submitted_at IS NOT NULL
    ),
    'tds_unique_payees', (
      SELECT COUNT(DISTINCT payee_name) FROM public.founder_tds_payment_ledger
    ),
    'tds_average_rate_pct', (
      SELECT COALESCE(ROUND(AVG(tds_rate_pct)::numeric, 2), 0)
      FROM public.founder_tds_payment_ledger
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tax_gst_hub_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tax_gst_hub_summary() TO authenticated;

-- ============ RPC 2: RECENT FILING RUNS ============
DROP FUNCTION IF EXISTS public.founder_tax_filing_runs_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_tax_filing_runs_recent(
  p_kind text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS TABLE (
  id uuid, filing_kind text, filing_period_label text,
  filing_period_start date, filing_period_end date,
  run_status text, arn text, amount_rupees numeric,
  ca_reviewed boolean, ca_reviewer_name text,
  submitted_at timestamptz, accepted_at timestamptz,
  notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT f.id, f.filing_kind, f.filing_period_label,
         f.filing_period_start, f.filing_period_end,
         f.run_status, f.arn, f.amount_rupees,
         f.ca_reviewed, f.ca_reviewer_name,
         f.submitted_at, f.accepted_at, f.notes, f.created_at
  FROM public.founder_tax_filing_runs f
  WHERE (p_kind IS NULL OR f.filing_kind = p_kind)
    AND (p_status IS NULL OR f.run_status = p_status)
  ORDER BY f.filing_period_end DESC, f.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tax_filing_runs_recent(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tax_filing_runs_recent(text, text, int) TO authenticated;

-- ============ RPC 3: RECENT TDS LEDGER ============
DROP FUNCTION IF EXISTS public.founder_tds_payment_ledger_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_tds_payment_ledger_recent(
  p_kind text DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS TABLE (
  id uuid, payment_kind text, payee_name text, payee_pan text,
  gross_amount_rupees numeric, tds_rate_pct numeric, tds_amount_rupees numeric,
  deducted_at date, deposited_at date,
  challan_no text, challan_url text, form_16_url text,
  assessment_year text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT t.id, t.payment_kind, t.payee_name, t.payee_pan,
         t.gross_amount_rupees, t.tds_rate_pct, t.tds_amount_rupees,
         t.deducted_at, t.deposited_at,
         t.challan_no, t.challan_url, t.form_16_url,
         t.assessment_year, t.created_at
  FROM public.founder_tds_payment_ledger t
  WHERE (p_kind IS NULL OR t.payment_kind = p_kind)
  ORDER BY t.deducted_at DESC, t.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tds_payment_ledger_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tds_payment_ledger_recent(text, int) TO authenticated;

-- ============ RPC 4: OVERDUE FILINGS ============
DROP FUNCTION IF EXISTS public.founder_tax_filing_runs_overdue();
CREATE OR REPLACE FUNCTION public.founder_tax_filing_runs_overdue()
RETURNS TABLE (
  id uuid, filing_kind text, filing_period_label text,
  filing_period_end date, days_overdue int,
  run_status text, amount_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT f.id, f.filing_kind, f.filing_period_label,
         f.filing_period_end,
         GREATEST(0, (CURRENT_DATE - f.filing_period_end)::int - 20) AS days_overdue,
         f.run_status, f.amount_rupees
  FROM public.founder_tax_filing_runs f
  WHERE f.run_status = 'overdue'
     OR (f.run_status = 'draft' AND f.filing_period_end < CURRENT_DATE - INTERVAL '20 days')
  ORDER BY f.filing_period_end ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tax_filing_runs_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tax_filing_runs_overdue() TO authenticated;

-- ============ RPC 5: REGISTER FILING ============
DROP FUNCTION IF EXISTS public.log_founder_tax_register_filing(text, text, date, date, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_tax_register_filing(
  p_kind text,
  p_period_label text,
  p_period_start date,
  p_period_end date,
  p_amount numeric DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_tax_filing_runs (
    filing_kind, filing_period_label, filing_period_start, filing_period_end,
    amount_rupees, notes
  ) VALUES (p_kind, p_period_label, p_period_start, p_period_end, p_amount, p_notes)
  ON CONFLICT (filing_kind, filing_period_label) DO UPDATE
    SET amount_rupees = COALESCE(EXCLUDED.amount_rupees, founder_tax_filing_runs.amount_rupees),
        notes = COALESCE(EXCLUDED.notes, founder_tax_filing_runs.notes),
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_tax_register_filing(text, text, date, date, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tax_register_filing(text, text, date, date, numeric, text) TO authenticated;

-- ============ RPC 6: SUBMIT FILING ============
DROP FUNCTION IF EXISTS public.log_founder_tax_submit_filing(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_tax_submit_filing(
  p_id uuid,
  p_arn text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  UPDATE public.founder_tax_filing_runs
     SET run_status = 'submitted',
         arn = p_arn,
         submitted_at = COALESCE(submitted_at, now()),
         updated_at = now()
   WHERE id = p_id AND run_status IN ('draft','overdue','rejected');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_tax_submit_filing(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tax_submit_filing(uuid, text) TO authenticated;

-- ============ RPC 7: RECORD ACCEPTANCE ============
DROP FUNCTION IF EXISTS public.log_founder_tax_record_acceptance(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_tax_record_acceptance(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  UPDATE public.founder_tax_filing_runs
     SET run_status = 'accepted',
         accepted_at = COALESCE(accepted_at, now()),
         updated_at = now()
   WHERE id = p_id AND run_status = 'submitted';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_tax_record_acceptance(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tax_record_acceptance(uuid) TO authenticated;

-- ============ RPC 8: RECORD TDS PAYMENT ============
DROP FUNCTION IF EXISTS public.log_founder_tds_record_payment(text, text, numeric, numeric, date, text);
CREATE OR REPLACE FUNCTION public.log_founder_tds_record_payment(
  p_kind text,
  p_payee text,
  p_amount numeric,
  p_rate numeric,
  p_deducted_at date,
  p_ay text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_tds numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  v_tds := ROUND(p_amount * p_rate / 100, 2);
  INSERT INTO public.founder_tds_payment_ledger (
    payment_kind, payee_name, gross_amount_rupees,
    tds_rate_pct, tds_amount_rupees, deducted_at, assessment_year
  ) VALUES (p_kind, p_payee, p_amount, p_rate, v_tds, p_deducted_at, p_ay)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_tds_record_payment(text, text, numeric, numeric, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_tds_record_payment(text, text, numeric, numeric, date, text) TO authenticated;

COMMIT;