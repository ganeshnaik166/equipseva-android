BEGIN;

-- ============================================================================
-- Round 2836 — Customer Monthly Engineer Quote vs Invoice Variance
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_quote_invoice_variance_r2836 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key text NOT NULL,
  job_ref text NOT NULL,
  customer_org text NOT NULL,
  engineer_name text NOT NULL,
  quoted_rupees numeric(12,2) NOT NULL,
  invoiced_rupees numeric(12,2) NOT NULL,
  variance_rupees numeric(12,2) NOT NULL,
  variance_pct numeric(6,2) NOT NULL,
  cause text NOT NULL CHECK (cause IN ('scope_creep','parts_added','labor_overrun','undercharge','approved_delta','data_entry_error')),
  approved_by_customer boolean NOT NULL DEFAULT false,
  observed_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS variance_dispute_outcomes_r2836 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variance_id uuid NOT NULL REFERENCES engineer_quote_invoice_variance_r2836(id) ON DELETE CASCADE,
  dispute_opened boolean NOT NULL DEFAULT false,
  dispute_state text NOT NULL CHECK (dispute_state IN ('none','open','engineer_reviewed','customer_responded','resolved','written_off')),
  resolution text NOT NULL CHECK (resolution IN ('pending','refund_issued','credit_note','invoice_corrected','engineer_warned','no_action','split_difference')),
  refund_rupees numeric(12,2) NOT NULL DEFAULT 0,
  resolved_at date,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_quote_invoice_variance_r2836 ENABLE ROW LEVEL SECURITY;
ALTER TABLE variance_dispute_outcomes_r2836 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_quote_invoice_variance_r2836;
CREATE POLICY founder_all ON engineer_quote_invoice_variance_r2836
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON variance_dispute_outcomes_r2836;
CREATE POLICY founder_all ON variance_dispute_outcomes_r2836
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed variance rows
INSERT INTO engineer_quote_invoice_variance_r2836
  (month_key, job_ref, customer_org, engineer_name, quoted_rupees, invoiced_rupees, variance_rupees, variance_pct, cause, approved_by_customer, observed_at)
VALUES
  ('2026-06','JOB-7714','Apollo Spectra','Ramesh K', 8500.00, 11200.00, 2700.00, 31.76, 'scope_creep', false, '2026-06-04'::date),
  ('2026-06','JOB-7728','Yashoda Hospitals','Suresh N', 12500.00, 12500.00, 0.00, 0.00, 'approved_delta', true, '2026-06-07'::date),
  ('2026-06','JOB-7741','KIMS Kondapur','Pradeep V', 6200.00, 9450.00, 3250.00, 52.42, 'parts_added', true, '2026-06-09'::date),
  ('2026-06','JOB-7752','Continental Hospitals','Anil B', 4500.00, 7800.00, 3300.00, 73.33, 'labor_overrun', false, '2026-06-12'::date),
  ('2026-06','JOB-7763','Care Hospitals','Vikram S', 9800.00, 7200.00, -2600.00, -26.53, 'undercharge', true, '2026-06-15'::date),
  ('2026-06','JOB-7771','Rainbow Children','Mahesh T', 15400.00, 18900.00, 3500.00, 22.73, 'scope_creep', false, '2026-06-18'::date),
  ('2026-06','JOB-7780','Sunshine Hospitals','Karthik R', 5600.00, 5650.00, 50.00, 0.89, 'data_entry_error', true, '2026-06-20'::date);

-- Seed dispute outcomes
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, true, 'resolved','refund_issued', 2700.00, '2026-06-08'::date, 'Customer flagged scope creep; refunded delta.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7714';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, false, 'none','no_action', 0.00, NULL, 'Pre-approved scope addition.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7728';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, false, 'none','no_action', 0.00, NULL, 'Customer signed parts addendum on-site.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7741';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, true, 'open','pending', 0.00, NULL, 'Engineer labor overrun under review.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7752';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, false, 'resolved','engineer_warned', 0.00, '2026-06-16'::date, 'Engineer undercharged; coached on quoting.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7763';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, true, 'customer_responded','split_difference', 1750.00, '2026-06-21'::date, 'Split scope-creep delta 50/50.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7771';
INSERT INTO variance_dispute_outcomes_r2836
  (variance_id, dispute_opened, dispute_state, resolution, refund_rupees, resolved_at, notes)
SELECT id, false, 'resolved','invoice_corrected', 0.00, '2026-06-21'::date, 'Data-entry typo, invoice corrected.'
  FROM engineer_quote_invoice_variance_r2836 WHERE job_ref='JOB-7780';

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_kpis();
CREATE OR REPLACE FUNCTION founder_r2836_kpis()
RETURNS TABLE (
  total_jobs bigint,
  total_quoted numeric,
  total_invoiced numeric,
  total_variance numeric,
  avg_variance_pct numeric,
  disputes_open bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(v.quoted_rupees),0)::numeric,
    COALESCE(SUM(v.invoiced_rupees),0)::numeric,
    COALESCE(SUM(v.variance_rupees),0)::numeric,
    COALESCE(ROUND(AVG(v.variance_pct),2),0)::numeric,
    (SELECT COUNT(*) FROM variance_dispute_outcomes_r2836 d WHERE d.dispute_state='open')::bigint
  FROM engineer_quote_invoice_variance_r2836 v;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: variance rows
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_variances();
CREATE OR REPLACE FUNCTION founder_r2836_variances()
RETURNS TABLE (
  id uuid,
  job_ref text,
  customer_org text,
  engineer_name text,
  quoted_rupees numeric,
  invoiced_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric,
  cause text,
  approved_by_customer boolean,
  observed_at date
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.job_ref, v.customer_org, v.engineer_name,
         v.quoted_rupees, v.invoiced_rupees, v.variance_rupees, v.variance_pct,
         v.cause, v.approved_by_customer, v.observed_at
  FROM engineer_quote_invoice_variance_r2836 v
  ORDER BY ABS(v.variance_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_variances() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_variances() TO authenticated;

-- ============================================================================
-- RPC 3: cause breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_cause_breakdown();
CREATE OR REPLACE FUNCTION founder_r2836_cause_breakdown()
RETURNS TABLE (
  cause text,
  jobs bigint,
  total_variance numeric,
  avg_variance_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.cause, COUNT(*)::bigint,
         COALESCE(SUM(v.variance_rupees),0)::numeric,
         COALESCE(ROUND(AVG(v.variance_pct),2),0)::numeric
  FROM engineer_quote_invoice_variance_r2836 v
  GROUP BY v.cause
  ORDER BY ABS(SUM(v.variance_rupees)) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_cause_breakdown() TO authenticated;

-- ============================================================================
-- RPC 4: dispute outcomes joined
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_disputes();
CREATE OR REPLACE FUNCTION founder_r2836_disputes()
RETURNS TABLE (
  id uuid,
  job_ref text,
  customer_org text,
  variance_rupees numeric,
  dispute_state text,
  resolution text,
  refund_rupees numeric,
  resolved_at date,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, v.job_ref, v.customer_org, v.variance_rupees,
         d.dispute_state, d.resolution, d.refund_rupees, d.resolved_at, d.notes
  FROM variance_dispute_outcomes_r2836 d
  JOIN engineer_quote_invoice_variance_r2836 v ON v.id = d.variance_id
  ORDER BY d.dispute_opened DESC, ABS(v.variance_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_disputes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_disputes() TO authenticated;

-- ============================================================================
-- RPC 5: per-engineer leaderboard
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2836_engineer_leaderboard()
RETURNS TABLE (
  engineer_name text,
  jobs bigint,
  total_quoted numeric,
  total_invoiced numeric,
  total_variance numeric,
  avg_variance_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.engineer_name, COUNT(*)::bigint,
         COALESCE(SUM(v.quoted_rupees),0)::numeric,
         COALESCE(SUM(v.invoiced_rupees),0)::numeric,
         COALESCE(SUM(v.variance_rupees),0)::numeric,
         COALESCE(ROUND(AVG(v.variance_pct),2),0)::numeric
  FROM engineer_quote_invoice_variance_r2836 v
  GROUP BY v.engineer_name
  ORDER BY ABS(SUM(v.variance_rupees)) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_engineer_leaderboard() TO authenticated;

-- ============================================================================
-- RPC 6: per-customer breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_customer_breakdown();
CREATE OR REPLACE FUNCTION founder_r2836_customer_breakdown()
RETURNS TABLE (
  customer_org text,
  jobs bigint,
  total_variance numeric,
  approved_jobs bigint,
  disputed_jobs bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.customer_org,
         COUNT(*)::bigint,
         COALESCE(SUM(v.variance_rupees),0)::numeric,
         COUNT(*) FILTER (WHERE v.approved_by_customer)::bigint,
         COUNT(d.id) FILTER (WHERE d.dispute_opened)::bigint
  FROM engineer_quote_invoice_variance_r2836 v
  LEFT JOIN variance_dispute_outcomes_r2836 d ON d.variance_id = v.id
  GROUP BY v.customer_org
  ORDER BY ABS(SUM(v.variance_rupees)) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_customer_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_customer_breakdown() TO authenticated;

-- ============================================================================
-- RPC 7: resolution mix
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_resolution_mix();
CREATE OR REPLACE FUNCTION founder_r2836_resolution_mix()
RETURNS TABLE (
  resolution text,
  jobs bigint,
  total_refund numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.resolution, COUNT(*)::bigint, COALESCE(SUM(d.refund_rupees),0)::numeric
  FROM variance_dispute_outcomes_r2836 d
  GROUP BY d.resolution
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_resolution_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_resolution_mix() TO authenticated;

-- ============================================================================
-- RPC 8: top outliers
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2836_top_outliers();
CREATE OR REPLACE FUNCTION founder_r2836_top_outliers()
RETURNS TABLE (
  job_ref text,
  customer_org text,
  engineer_name text,
  variance_rupees numeric,
  variance_pct numeric,
  cause text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.job_ref, v.customer_org, v.engineer_name,
         v.variance_rupees, v.variance_pct, v.cause
  FROM engineer_quote_invoice_variance_r2836 v
  ORDER BY ABS(v.variance_pct) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2836_top_outliers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2836_top_outliers() TO authenticated;

COMMIT;
