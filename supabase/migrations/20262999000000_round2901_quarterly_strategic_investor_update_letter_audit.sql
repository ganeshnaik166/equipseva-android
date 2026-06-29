-- Round r2901 — Quarterly Strategic Founder-Investor Update Letter Audit
-- HEAVY founder ops: track quarterly investor letters, claims/promises made, audit accuracy

BEGIN;

-- ============================================================
-- TABLE 1: quarterly_investor_letters_r2901
-- ============================================================
CREATE TABLE IF NOT EXISTS quarterly_investor_letters_r2901 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  quarter_label text NOT NULL,
  fiscal_year text NOT NULL,
  sent_at timestamptz NOT NULL,
  letter_title text NOT NULL,
  headline_metric text NOT NULL,
  headline_value_rupees bigint,
  arr_reported_rupees bigint NOT NULL,
  burn_reported_rupees bigint NOT NULL,
  runway_months_reported numeric(5,1) NOT NULL,
  cash_balance_rupees bigint NOT NULL,
  net_new_logos integer NOT NULL,
  churn_logos integer NOT NULL DEFAULT 0,
  nps_reported integer,
  total_word_count integer NOT NULL,
  num_promises_made integer NOT NULL DEFAULT 0,
  num_promises_kept integer NOT NULL DEFAULT 0,
  tone_score numeric(3,2) NOT NULL DEFAULT 0.50,
  hype_index numeric(3,2) NOT NULL DEFAULT 0.50,
  legal_reviewed boolean NOT NULL DEFAULT false,
  founder_signoff boolean NOT NULL DEFAULT false,
  letter_status text NOT NULL DEFAULT 'sent'
);

ALTER TABLE quarterly_investor_letters_r2901 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: investor_letter_claims_r2901
-- ============================================================
CREATE TABLE IF NOT EXISTS investor_letter_claims_r2901 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  letter_id uuid NOT NULL REFERENCES quarterly_investor_letters_r2901(id) ON DELETE CASCADE,
  claim_category text NOT NULL,
  claim_text text NOT NULL,
  claim_type text NOT NULL,
  numeric_claim_value numeric(14,2),
  audit_status text NOT NULL DEFAULT 'pending',
  ground_truth_value numeric(14,2),
  variance_pct numeric(6,2),
  severity text NOT NULL DEFAULT 'low',
  audited_at timestamptz,
  remediation_note text
);

ALTER TABLE investor_letter_claims_r2901 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEEDS — quarterly_investor_letters_r2901 (14 rows)
-- ============================================================
INSERT INTO quarterly_investor_letters_r2901 (quarter_label, fiscal_year, sent_at, letter_title, headline_metric, headline_value_rupees, arr_reported_rupees, burn_reported_rupees, runway_months_reported, cash_balance_rupees, net_new_logos, churn_logos, nps_reported, total_word_count, num_promises_made, num_promises_kept, tone_score, hype_index, legal_reviewed, founder_signoff, letter_status) VALUES
('Q1', 'FY24', '2024-07-12 10:00:00+05:30'::timestamptz, 'Foundation Quarter — Tier-1 Wedge', 'ARR', 1200000, 1200000, 4500000, 14.0, 63000000, 8, 0, 42, 1850, 6, 5, 0.62, 0.55, true, true, 'sent'),
('Q2', 'FY24', '2024-10-10 10:00:00+05:30'::timestamptz, 'First Repeat-Buy Cycle', 'Net New Logos', NULL, 2400000, 4800000, 12.5, 60000000, 11, 1, 48, 2100, 7, 6, 0.68, 0.58, true, true, 'sent'),
('Q3', 'FY24', '2025-01-15 10:00:00+05:30'::timestamptz, 'AMC Engine Live', 'AMC Active Contracts', 18400000, 4800000, 5200000, 11.5, 59800000, 14, 1, 51, 2350, 8, 7, 0.71, 0.62, true, true, 'sent'),
('Q4', 'FY24', '2025-04-12 10:00:00+05:30'::timestamptz, 'FY24 Wrap — 4.2x ARR Growth', 'ARR', 4800000, 4800000, 5500000, 11.0, 60500000, 12, 2, 47, 2700, 9, 6, 0.74, 0.71, true, true, 'sent'),
('Q1', 'FY25', '2025-07-18 10:00:00+05:30'::timestamptz, 'Tier-2 Expansion Wave', 'Tier-2 Logos', NULL, 7200000, 6800000, 10.0, 68000000, 18, 2, 49, 2900, 10, 8, 0.72, 0.68, true, true, 'sent'),
('Q2', 'FY25', '2025-10-14 10:00:00+05:30'::timestamptz, 'Engineer Network 250+', 'Engineers Onboarded', NULL, 10800000, 7400000, 9.5, 70300000, 22, 3, 52, 3100, 11, 9, 0.78, 0.74, true, true, 'sent'),
('Q3', 'FY25', '2026-01-16 10:00:00+05:30'::timestamptz, 'Path to ₹2Cr ARR', 'ARR', 14400000, 14400000, 8100000, 9.0, 72900000, 25, 4, 54, 3450, 12, 9, 0.80, 0.81, true, true, 'sent'),
('Q4', 'FY25', '2026-04-15 10:00:00+05:30'::timestamptz, 'FY25 Close — 3x YoY', 'ARR', 18600000, 18600000, 8800000, 8.5, 74800000, 28, 5, 50, 3800, 13, 10, 0.82, 0.85, true, true, 'sent'),
('Q1', 'FY26', '2026-07-20 10:00:00+05:30'::timestamptz, 'Series A Readiness', 'Cash Runway', NULL, 22800000, 9500000, 16.0, 152000000, 31, 4, 53, 4100, 14, 12, 0.79, 0.78, true, true, 'sent'),
('Q2', 'FY26', '2026-10-18 10:00:00+05:30'::timestamptz, 'Multi-Vertical Launch', 'Verticals Live', NULL, 28400000, 10800000, 14.5, 156600000, 38, 6, 55, 4350, 15, 13, 0.81, 0.83, true, true, 'sent'),
('Q3', 'FY26', '2027-01-22 10:00:00+05:30'::timestamptz, 'Cashflow Positive Sightlines', 'Gross Margin', 6800000, 34800000, 11200000, 14.0, 156800000, 42, 7, 57, 4600, 16, 14, 0.84, 0.86, true, true, 'sent'),
('Q4', 'FY26', '2027-04-20 10:00:00+05:30'::timestamptz, 'FY26 Wrap — Cashflow Positive', 'Gross Margin %', NULL, 42600000, 8400000, 18.5, 155400000, 46, 8, 59, 4900, 17, 15, 0.86, 0.84, true, true, 'sent'),
('Q1', 'FY27', '2027-07-15 10:00:00+05:30'::timestamptz, 'International Pilot — SL/BD', 'International Logos', NULL, 52800000, 12400000, 17.0, 210800000, 52, 9, 58, 5200, 18, 12, 0.83, 0.92, true, true, 'sent'),
('Q2', 'FY27', '2027-10-12 10:00:00+05:30'::timestamptz, 'Pre-IPO Conditioning', 'ARR Multiple', NULL, 68400000, 14800000, 16.5, 244200000, 58, 11, 61, 5500, 19, 0, 0.85, 0.88, false, false, 'draft');

-- ============================================================
-- SEEDS — investor_letter_claims_r2901 (24 rows)
-- ============================================================
INSERT INTO investor_letter_claims_r2901 (letter_id, claim_category, claim_text, claim_type, numeric_claim_value, audit_status, ground_truth_value, variance_pct, severity, audited_at, remediation_note)
SELECT id, 'revenue', 'Q1 FY24 ARR closed at ₹12L flat', 'metric', 1200000, 'verified', 1198400, -0.13, 'low', '2024-08-01 10:00:00+05:30'::timestamptz, 'within rounding tolerance' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY24'
UNION ALL SELECT id, 'logos', 'Onboarded 8 Tier-1 hospitals in Q1', 'metric', 8, 'verified', 8, 0.00, 'low', '2024-08-01 10:00:00+05:30'::timestamptz, 'exact match' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY24'
UNION ALL SELECT id, 'roadmap', 'Will launch AMC engine by Q3', 'promise', NULL, 'kept', NULL, NULL, 'low', '2025-01-15 10:00:00+05:30'::timestamptz, 'shipped on time' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY24'
UNION ALL SELECT id, 'metric', 'NPS hit 48 from 42 prior quarter', 'metric', 48, 'verified', 46, -4.17, 'low', '2024-11-01 10:00:00+05:30'::timestamptz, 'small overstatement, within margin' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY24'
UNION ALL SELECT id, 'revenue', 'AMC pool crossed ₹1.84Cr in active contracts', 'metric', 18400000, 'verified', 18412000, 0.07, 'low', '2025-02-01 10:00:00+05:30'::timestamptz, 'tight match' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q3' AND fiscal_year='FY24'
UNION ALL SELECT id, 'roadmap', 'Engineer network will reach 100 by Q4', 'promise', 100, 'kept', 108, 8.00, 'low', '2025-04-12 10:00:00+05:30'::timestamptz, 'overshot target' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q3' AND fiscal_year='FY24'
UNION ALL SELECT id, 'revenue', 'FY24 closed at ₹48L ARR — 4.2x growth', 'metric', 4800000, 'verified', 4756000, -0.92, 'low', '2025-05-01 10:00:00+05:30'::timestamptz, 'within tolerance' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q4' AND fiscal_year='FY24'
UNION ALL SELECT id, 'roadmap', 'Tier-2 expansion to 5 cities in Q1 FY25', 'promise', 5, 'partial', 3, -40.00, 'medium', '2025-07-18 10:00:00+05:30'::timestamptz, 'shipped 3 of 5 cities; Pune+Indore delayed' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q4' AND fiscal_year='FY24'
UNION ALL SELECT id, 'logos', '18 net-new Tier-2 logos in Q1 FY25', 'metric', 18, 'verified', 18, 0.00, 'low', '2025-08-01 10:00:00+05:30'::timestamptz, 'exact' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY25'
UNION ALL SELECT id, 'burn', 'Burn held at ₹68L/mo despite 2x team', 'metric', 6800000, 'flagged', 7320000, 7.65, 'medium', '2025-08-01 10:00:00+05:30'::timestamptz, 'understated burn by ~5L; reconciled in Q2 letter' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY25'
UNION ALL SELECT id, 'metric', 'Engineer network crossed 250', 'metric', 250, 'verified', 258, 3.20, 'low', '2025-11-01 10:00:00+05:30'::timestamptz, 'rounded down conservatively' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY25'
UNION ALL SELECT id, 'roadmap', 'Engineer-led AMC renewals automated by Q3', 'promise', NULL, 'kept', NULL, NULL, 'low', '2026-01-16 10:00:00+05:30'::timestamptz, 'shipped r1480' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY25'
UNION ALL SELECT id, 'revenue', 'Q3 FY25 ARR at ₹1.44Cr', 'metric', 14400000, 'verified', 14380000, -0.14, 'low', '2026-02-01 10:00:00+05:30'::timestamptz, 'exact match' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q3' AND fiscal_year='FY25'
UNION ALL SELECT id, 'roadmap', 'Cashflow positive by Q4 FY26 (forward-looking)', 'promise', NULL, 'pending', NULL, NULL, 'medium', NULL, 'tracking on plan; final audit Q4 FY26' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q3' AND fiscal_year='FY25'
UNION ALL SELECT id, 'revenue', 'FY25 closed at ₹1.86Cr ARR — 3x YoY', 'metric', 18600000, 'verified', 18584000, -0.09, 'low', '2026-05-01 10:00:00+05:30'::timestamptz, 'tight match' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q4' AND fiscal_year='FY25'
UNION ALL SELECT id, 'capital', 'Series A closed at ₹15.2Cr valuation', 'metric', 152000000, 'verified', 152000000, 0.00, 'low', '2026-07-20 10:00:00+05:30'::timestamptz, 'wire confirmed' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY26'
UNION ALL SELECT id, 'roadmap', 'Launch 3 verticals (dental, ortho, eye) by Q2 FY26', 'promise', 3, 'kept', 3, 0.00, 'low', '2026-10-18 10:00:00+05:30'::timestamptz, 'all 3 live' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY26'
UNION ALL SELECT id, 'metric', 'Gross margin reached 68%', 'metric', 68, 'flagged', 64, -5.88, 'high', '2027-02-01 10:00:00+05:30'::timestamptz, 'overstated GM by 4pp — engineer comp not fully loaded' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q3' AND fiscal_year='FY26'
UNION ALL SELECT id, 'roadmap', 'Cashflow positive achieved in Q4 FY26', 'promise', NULL, 'kept', NULL, NULL, 'low', '2027-04-20 10:00:00+05:30'::timestamptz, 'audited by Big-4; verified' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q4' AND fiscal_year='FY26'
UNION ALL SELECT id, 'revenue', 'FY26 closed at ₹4.26Cr ARR', 'metric', 42600000, 'verified', 42612000, 0.03, 'low', '2027-05-01 10:00:00+05:30'::timestamptz, 'exact' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q4' AND fiscal_year='FY26'
UNION ALL SELECT id, 'roadmap', 'International pilot in Sri Lanka + Bangladesh', 'promise', 2, 'partial', 1, -50.00, 'high', '2027-07-15 10:00:00+05:30'::timestamptz, 'only SL launched; BD delayed 1 quarter' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q1' AND fiscal_year='FY27'
UNION ALL SELECT id, 'metric', 'NPS climbed to 61 — highest in healthtech', 'metric', 61, 'flagged', 58, -4.92, 'medium', '2027-10-12 10:00:00+05:30'::timestamptz, 'best-claim language — peer benchmark unverified' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY27'
UNION ALL SELECT id, 'capital', 'Pre-IPO target valuation ₹450Cr', 'forward', 4500000000, 'pending', NULL, NULL, 'high', NULL, 'forward-looking; banker conditioning in progress' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY27'
UNION ALL SELECT id, 'revenue', 'Q2 FY27 ARR at ₹6.84Cr', 'metric', 68400000, 'pending', NULL, NULL, 'medium', NULL, 'awaiting Q-close audit' FROM quarterly_investor_letters_r2901 WHERE quarter_label='Q2' AND fiscal_year='FY27';

-- ============================================================
-- RLS POLICIES
-- ============================================================
DROP POLICY IF EXISTS letters_founder_only_r2901 ON quarterly_investor_letters_r2901;
CREATE POLICY letters_founder_only_r2901 ON quarterly_investor_letters_r2901 FOR SELECT TO authenticated USING (is_founder());

DROP POLICY IF EXISTS claims_founder_only_r2901 ON investor_letter_claims_r2901;
CREATE POLICY claims_founder_only_r2901 ON investor_letter_claims_r2901 FOR SELECT TO authenticated USING (is_founder());

-- ============================================================
-- RPC 1: letter portfolio overview
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_letter_portfolio()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  sent_at timestamptz,
  letter_title text,
  arr_reported_rupees bigint,
  burn_reported_rupees bigint,
  runway_months_reported numeric,
  net_new_logos integer,
  tone_score numeric,
  hype_index numeric,
  letter_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, l.sent_at, l.letter_title,
         l.arr_reported_rupees, l.burn_reported_rupees, l.runway_months_reported,
         l.net_new_logos, l.tone_score, l.hype_index, l.letter_status
  FROM quarterly_investor_letters_r2901 l
  ORDER BY l.sent_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_letter_portfolio() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_letter_portfolio() TO authenticated;

-- ============================================================
-- RPC 2: claim audit ledger
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_claim_audit_ledger()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  claim_category text,
  claim_text text,
  claim_type text,
  audit_status text,
  variance_pct numeric,
  severity text,
  remediation_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, c.claim_category, c.claim_text,
         c.claim_type, c.audit_status, c.variance_pct, c.severity, c.remediation_note
  FROM investor_letter_claims_r2901 c
  JOIN quarterly_investor_letters_r2901 l ON l.id = c.letter_id
  ORDER BY l.sent_at DESC, c.severity DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_claim_audit_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_claim_audit_ledger() TO authenticated;

-- ============================================================
-- RPC 3: promise-kept rate by quarter
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_promise_keep_rate()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  num_promises_made integer,
  num_promises_kept integer,
  keep_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, l.num_promises_made, l.num_promises_kept,
         CASE WHEN l.num_promises_made > 0
              THEN ROUND((l.num_promises_kept::numeric / l.num_promises_made::numeric) * 100, 1)
              ELSE 0 END AS keep_rate_pct
  FROM quarterly_investor_letters_r2901 l
  ORDER BY l.sent_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_promise_keep_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_promise_keep_rate() TO authenticated;

-- ============================================================
-- RPC 4: high-severity flagged claims
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_flagged_claims()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  claim_text text,
  audit_status text,
  variance_pct numeric,
  severity text,
  remediation_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, c.claim_text, c.audit_status,
         c.variance_pct, c.severity, c.remediation_note
  FROM investor_letter_claims_r2901 c
  JOIN quarterly_investor_letters_r2901 l ON l.id = c.letter_id
  WHERE c.severity IN ('medium','high') OR c.audit_status = 'flagged'
  ORDER BY l.sent_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_flagged_claims() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_flagged_claims() TO authenticated;

-- ============================================================
-- RPC 5: hype index drift trend
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_hype_drift()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  tone_score numeric,
  hype_index numeric,
  hype_minus_tone numeric,
  total_word_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, l.tone_score, l.hype_index,
         ROUND(l.hype_index - l.tone_score, 2) AS hype_minus_tone,
         l.total_word_count
  FROM quarterly_investor_letters_r2901 l
  ORDER BY l.sent_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_hype_drift() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_hype_drift() TO authenticated;

-- ============================================================
-- RPC 6: capital + runway trajectory
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_capital_trajectory()
RETURNS TABLE (
  quarter_label text,
  fiscal_year text,
  cash_balance_rupees bigint,
  burn_reported_rupees bigint,
  runway_months_reported numeric,
  arr_reported_rupees bigint,
  burn_multiple numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT l.quarter_label, l.fiscal_year, l.cash_balance_rupees,
         l.burn_reported_rupees, l.runway_months_reported, l.arr_reported_rupees,
         CASE WHEN l.arr_reported_rupees > 0
              THEN ROUND((l.burn_reported_rupees::numeric * 12) / NULLIF(l.arr_reported_rupees,0), 2)
              ELSE NULL END AS burn_multiple
  FROM quarterly_investor_letters_r2901 l
  ORDER BY l.sent_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_capital_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_capital_trajectory() TO authenticated;

-- ============================================================
-- RPC 7: category-wise audit summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_category_audit_summary()
RETURNS TABLE (
  claim_category text,
  total_claims bigint,
  verified_count bigint,
  flagged_count bigint,
  pending_count bigint,
  high_severity_count bigint,
  avg_variance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT c.claim_category,
         COUNT(*)::bigint AS total_claims,
         COUNT(*) FILTER (WHERE c.audit_status = 'verified')::bigint AS verified_count,
         COUNT(*) FILTER (WHERE c.audit_status = 'flagged')::bigint AS flagged_count,
         COUNT(*) FILTER (WHERE c.audit_status = 'pending')::bigint AS pending_count,
         COUNT(*) FILTER (WHERE c.severity = 'high')::bigint AS high_severity_count,
         ROUND(AVG(ABS(COALESCE(c.variance_pct, 0))), 2) AS avg_variance_pct
  FROM investor_letter_claims_r2901 c
  GROUP BY c.claim_category
  ORDER BY high_severity_count DESC, total_claims DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_category_audit_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_category_audit_summary() TO authenticated;

-- ============================================================
-- RPC 8: portfolio KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2901_portfolio_kpis()
RETURNS TABLE (
  total_letters bigint,
  total_claims bigint,
  flagged_claims bigint,
  high_severity_claims bigint,
  total_promises_made bigint,
  total_promises_kept bigint,
  overall_keep_rate_pct numeric,
  avg_hype_index numeric,
  latest_arr_rupees bigint,
  latest_cash_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM quarterly_investor_letters_r2901),
    (SELECT COUNT(*)::bigint FROM investor_letter_claims_r2901),
    (SELECT COUNT(*)::bigint FROM investor_letter_claims_r2901 WHERE audit_status = 'flagged'),
    (SELECT COUNT(*)::bigint FROM investor_letter_claims_r2901 WHERE severity = 'high'),
    (SELECT COALESCE(SUM(num_promises_made),0)::bigint FROM quarterly_investor_letters_r2901),
    (SELECT COALESCE(SUM(num_promises_kept),0)::bigint FROM quarterly_investor_letters_r2901),
    (SELECT CASE WHEN SUM(num_promises_made) > 0
                 THEN ROUND((SUM(num_promises_kept)::numeric / SUM(num_promises_made)::numeric) * 100, 1)
                 ELSE 0 END
     FROM quarterly_investor_letters_r2901),
    (SELECT ROUND(AVG(hype_index), 2) FROM quarterly_investor_letters_r2901),
    (SELECT arr_reported_rupees FROM quarterly_investor_letters_r2901 ORDER BY sent_at DESC LIMIT 1),
    (SELECT cash_balance_rupees FROM quarterly_investor_letters_r2901 ORDER BY sent_at DESC LIMIT 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2901_portfolio_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2901_portfolio_kpis() TO authenticated;

COMMIT;
