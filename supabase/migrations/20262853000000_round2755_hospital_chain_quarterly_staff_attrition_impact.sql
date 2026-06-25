BEGIN;

-- ============================================================
-- Round 2755: Hospital chain quarterly staff attrition impact
-- chain x attrition rate x cause x our exposure x adapt action x outcome
-- ============================================================

CREATE TABLE IF NOT EXISTS hospital_chain_attrition_quarters_r2755 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  quarter_start_date date NOT NULL,
  biomed_headcount_start int NOT NULL,
  biomed_headcount_end int NOT NULL,
  attrition_count int NOT NULL,
  attrition_rate_pct numeric(5,2) NOT NULL,
  primary_cause text NOT NULL CHECK (primary_cause IN ('pay_freeze','burnout','poaching','relocation','restructure','retirement')),
  exposure_band text NOT NULL CHECK (exposure_band IN ('low','moderate','high','critical')),
  amc_contracts_at_risk int NOT NULL DEFAULT 0,
  arr_at_risk_rupees bigint NOT NULL DEFAULT 0,
  knowledge_loss_score int NOT NULL CHECK (knowledge_loss_score BETWEEN 0 AND 100),
  founder_notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_attrition_quarters_r2755 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_attrition_quarters_r2755;
CREATE POLICY founder_all ON hospital_chain_attrition_quarters_r2755
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_attrition_actions_r2755 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_id uuid NOT NULL REFERENCES hospital_chain_attrition_quarters_r2755(id) ON DELETE CASCADE,
  chain_code text NOT NULL,
  adapt_action text NOT NULL CHECK (adapt_action IN ('engineer_embed','training_handoff','contract_renegotiation','escalation_to_cxo','pricing_concession','knowledge_capture','executive_sponsor')),
  action_owner text NOT NULL,
  initiated_at date NOT NULL,
  closed_at date,
  outcome text NOT NULL CHECK (outcome IN ('retained','partial_retain','churned','open','escalating')),
  retained_arr_rupees bigint NOT NULL DEFAULT 0,
  lost_arr_rupees bigint NOT NULL DEFAULT 0,
  effectiveness_score int NOT NULL CHECK (effectiveness_score BETWEEN 0 AND 100),
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_attrition_actions_r2755 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_attrition_actions_r2755;
CREATE POLICY founder_all ON hospital_chain_attrition_actions_r2755
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO hospital_chain_attrition_quarters_r2755
  (id, chain_code, chain_name, quarter_label, quarter_start_date, biomed_headcount_start, biomed_headcount_end, attrition_count, attrition_rate_pct, primary_cause, exposure_band, amc_contracts_at_risk, arr_at_risk_rupees, knowledge_loss_score, founder_notes)
VALUES
  ('11111111-1111-1111-1111-111111111101'::uuid, 'APOLLO_HYD', 'Apollo Hospitals Hyderabad', 'Q1 2026', '2026-01-01'::date, 48, 42, 6, 12.50, 'burnout', 'high', 14, 28000000, 72, 'two senior biomeds left; AMC continuity at risk on cath lab cluster'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'YASHODA_HYD', 'Yashoda Hospitals', 'Q1 2026', '2026-01-01'::date, 36, 35, 1, 2.78, 'retirement', 'low', 3, 4500000, 18, 'planned retirement; successor onboarded'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'MAX_DEL', 'Max Healthcare Delhi', 'Q1 2026', '2026-01-01'::date, 62, 55, 7, 11.29, 'poaching', 'critical', 22, 41000000, 84, 'rival OEM poached 4 leads; renegotiation underway'),
  ('11111111-1111-1111-1111-111111111104'::uuid, 'FORTIS_BLR', 'Fortis Bengaluru', 'Q1 2026', '2026-01-01'::date, 40, 38, 2, 5.00, 'relocation', 'moderate', 8, 12000000, 41, 'two staff relocated post-merger'),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'NARAYANA_BLR', 'Narayana Health', 'Q1 2026', '2026-01-01'::date, 55, 49, 6, 10.91, 'pay_freeze', 'high', 17, 31500000, 67, 'pay freeze announced; morale dip flagged in NPS'),
  ('11111111-1111-1111-1111-111111111106'::uuid, 'MANIPAL_BLR', 'Manipal Hospitals', 'Q1 2026', '2026-01-01'::date, 44, 41, 3, 6.82, 'restructure', 'moderate', 9, 14500000, 52, 'biomed function restructured under facilities head');

INSERT INTO hospital_chain_attrition_actions_r2755
  (quarter_id, chain_code, adapt_action, action_owner, initiated_at, closed_at, outcome, retained_arr_rupees, lost_arr_rupees, effectiveness_score, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101'::uuid, 'APOLLO_HYD', 'engineer_embed', 'Ganesh', '2026-01-15'::date, '2026-03-20'::date, 'retained', 26000000, 2000000, 88, 'embedded senior engineer 3 days/week for handoff window'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'YASHODA_HYD', 'knowledge_capture', 'Ops Lead', '2026-01-10'::date, '2026-02-28'::date, 'retained', 4500000, 0, 92, 'recorded SOPs before retirement; clean transition'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'MAX_DEL', 'escalation_to_cxo', 'Ganesh', '2026-01-08'::date, NULL, 'escalating', 28000000, 13000000, 64, 'CXO meeting set; partial recovery in progress'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'MAX_DEL', 'pricing_concession', 'Sales', '2026-02-01'::date, '2026-03-15'::date, 'partial_retain', 22000000, 19000000, 58, '6 percent concession on renewed cluster; 3 sites still at risk'),
  ('11111111-1111-1111-1111-111111111104'::uuid, 'FORTIS_BLR', 'training_handoff', 'Training', '2026-01-20'::date, '2026-03-05'::date, 'retained', 12000000, 0, 81, 'cross-trained replacement biomeds on imaging stack'),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'NARAYANA_BLR', 'contract_renegotiation', 'Ganesh', '2026-02-05'::date, NULL, 'open', 18000000, 7500000, 55, 'renegotiation tied to pay-freeze unwind in Q2'),
  ('11111111-1111-1111-1111-111111111106'::uuid, 'MANIPAL_BLR', 'executive_sponsor', 'Founder', '2026-01-25'::date, '2026-03-10'::date, 'retained', 14500000, 0, 78, 'founder sponsored new facilities head; AMC intact');

-- ============================================================
-- RPCs (all SECDEF, founder-gated)
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2755_attrition_overview();
CREATE OR REPLACE FUNCTION founder_r2755_attrition_overview()
RETURNS TABLE (
  chains_tracked int,
  total_attrition int,
  weighted_attrition_rate_pct numeric,
  total_arr_at_risk_rupees bigint,
  contracts_at_risk int,
  critical_chain_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_code)::int,
    COALESCE(SUM(attrition_count),0)::int,
    ROUND(COALESCE(SUM(attrition_count)::numeric * 100.0 / NULLIF(SUM(biomed_headcount_start),0), 0), 2),
    COALESCE(SUM(arr_at_risk_rupees),0)::bigint,
    COALESCE(SUM(amc_contracts_at_risk),0)::int,
    COUNT(*) FILTER (WHERE exposure_band = 'critical')::int
  FROM hospital_chain_attrition_quarters_r2755;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_attrition_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_attrition_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_chain_breakdown();
CREATE OR REPLACE FUNCTION founder_r2755_chain_breakdown()
RETURNS TABLE (
  id uuid,
  chain_code text,
  chain_name text,
  quarter_label text,
  attrition_count int,
  attrition_rate_pct numeric,
  primary_cause text,
  exposure_band text,
  amc_contracts_at_risk int,
  arr_at_risk_rupees bigint,
  knowledge_loss_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.chain_code, q.chain_name, q.quarter_label, q.attrition_count, q.attrition_rate_pct,
         q.primary_cause, q.exposure_band, q.amc_contracts_at_risk, q.arr_at_risk_rupees, q.knowledge_loss_score
  FROM hospital_chain_attrition_quarters_r2755 q
  ORDER BY q.arr_at_risk_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_chain_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_chain_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_cause_distribution();
CREATE OR REPLACE FUNCTION founder_r2755_cause_distribution()
RETURNS TABLE (
  primary_cause text,
  chain_count int,
  total_attrition int,
  arr_at_risk_rupees bigint,
  avg_knowledge_loss numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.primary_cause,
         COUNT(*)::int,
         COALESCE(SUM(q.attrition_count),0)::int,
         COALESCE(SUM(q.arr_at_risk_rupees),0)::bigint,
         ROUND(AVG(q.knowledge_loss_score)::numeric, 1)
  FROM hospital_chain_attrition_quarters_r2755 q
  GROUP BY q.primary_cause
  ORDER BY COALESCE(SUM(q.arr_at_risk_rupees),0) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_cause_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_cause_distribution() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_exposure_summary();
CREATE OR REPLACE FUNCTION founder_r2755_exposure_summary()
RETURNS TABLE (
  exposure_band text,
  chain_count int,
  contracts_at_risk int,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.exposure_band,
         COUNT(*)::int,
         COALESCE(SUM(q.amc_contracts_at_risk),0)::int,
         COALESCE(SUM(q.arr_at_risk_rupees),0)::bigint
  FROM hospital_chain_attrition_quarters_r2755 q
  GROUP BY q.exposure_band
  ORDER BY CASE q.exposure_band
    WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'moderate' THEN 3 WHEN 'low' THEN 4 END;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_exposure_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_exposure_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_action_outcomes();
CREATE OR REPLACE FUNCTION founder_r2755_action_outcomes()
RETURNS TABLE (
  outcome text,
  action_count int,
  retained_arr_rupees bigint,
  lost_arr_rupees bigint,
  avg_effectiveness numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.outcome,
         COUNT(*)::int,
         COALESCE(SUM(a.retained_arr_rupees),0)::bigint,
         COALESCE(SUM(a.lost_arr_rupees),0)::bigint,
         ROUND(AVG(a.effectiveness_score)::numeric, 1)
  FROM hospital_chain_attrition_actions_r2755 a
  GROUP BY a.outcome
  ORDER BY COALESCE(SUM(a.retained_arr_rupees),0) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_action_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_action_outcomes() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_action_log();
CREATE OR REPLACE FUNCTION founder_r2755_action_log()
RETURNS TABLE (
  id uuid,
  chain_code text,
  adapt_action text,
  action_owner text,
  initiated_at date,
  closed_at date,
  outcome text,
  retained_arr_rupees bigint,
  lost_arr_rupees bigint,
  effectiveness_score int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_code, a.adapt_action, a.action_owner, a.initiated_at, a.closed_at,
         a.outcome, a.retained_arr_rupees, a.lost_arr_rupees, a.effectiveness_score, a.notes
  FROM hospital_chain_attrition_actions_r2755 a
  ORDER BY a.initiated_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_action_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_action_log() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_top_at_risk(int);
CREATE OR REPLACE FUNCTION founder_r2755_top_at_risk(p_limit int DEFAULT 5)
RETURNS TABLE (
  chain_code text,
  chain_name text,
  arr_at_risk_rupees bigint,
  exposure_band text,
  primary_cause text,
  knowledge_loss_score int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.chain_code, q.chain_name, q.arr_at_risk_rupees, q.exposure_band, q.primary_cause, q.knowledge_loss_score
  FROM hospital_chain_attrition_quarters_r2755 q
  ORDER BY q.arr_at_risk_rupees DESC
  LIMIT GREATEST(p_limit, 1);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_top_at_risk(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_top_at_risk(int) TO authenticated;

DROP FUNCTION IF EXISTS founder_r2755_action_effectiveness_by_type();
CREATE OR REPLACE FUNCTION founder_r2755_action_effectiveness_by_type()
RETURNS TABLE (
  adapt_action text,
  action_count int,
  avg_effectiveness numeric,
  total_retained_arr bigint,
  total_lost_arr bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.adapt_action,
         COUNT(*)::int,
         ROUND(AVG(a.effectiveness_score)::numeric, 1),
         COALESCE(SUM(a.retained_arr_rupees),0)::bigint,
         COALESCE(SUM(a.lost_arr_rupees),0)::bigint
  FROM hospital_chain_attrition_actions_r2755 a
  GROUP BY a.adapt_action
  ORDER BY AVG(a.effectiveness_score) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2755_action_effectiveness_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2755_action_effectiveness_by_type() TO authenticated;

COMMIT;