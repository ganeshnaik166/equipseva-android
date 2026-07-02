BEGIN;

-- Round 2829 — Founder Quarterly Product Thesis Update
-- thesis × signal × validation × pivot/persist × stake × outcome × verdict

CREATE TABLE IF NOT EXISTS product_thesis_statements_r2829 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  thesis_title text NOT NULL,
  thesis_statement text NOT NULL,
  pillar text NOT NULL CHECK (pillar IN ('marketplace','vertical_depth','financial_layer','operating_system','distribution')),
  hypothesis text NOT NULL,
  primary_signal text NOT NULL,
  validation_metric text NOT NULL,
  target_value numeric NOT NULL,
  current_value numeric NOT NULL,
  confidence_pct numeric NOT NULL CHECK (confidence_pct BETWEEN 0 AND 100),
  capital_stake_lakh numeric NOT NULL,
  decision text NOT NULL CHECK (decision IN ('persist','double_down','pivot','kill','park')),
  verdict text NOT NULL CHECK (verdict IN ('validated','partially_validated','inconclusive','invalidated')),
  outcome_note text NOT NULL,
  asserted_on date NOT NULL,
  reviewed_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE product_thesis_statements_r2829 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON product_thesis_statements_r2829;
CREATE POLICY founder_all ON product_thesis_statements_r2829 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS product_thesis_signals_r2829 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thesis_id uuid NOT NULL REFERENCES product_thesis_statements_r2829(id) ON DELETE CASCADE,
  signal_label text NOT NULL,
  signal_kind text NOT NULL CHECK (signal_kind IN ('leading','lagging','qualitative','financial','operational')),
  measured_value numeric NOT NULL,
  expected_value numeric NOT NULL,
  delta_pct numeric NOT NULL,
  strength text NOT NULL CHECK (strength IN ('weak','moderate','strong','definitive')),
  direction text NOT NULL CHECK (direction IN ('confirming','contradicting','neutral')),
  observed_on date NOT NULL,
  source text NOT NULL,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE product_thesis_signals_r2829 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON product_thesis_signals_r2829;
CREATE POLICY founder_all ON product_thesis_signals_r2829 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds
WITH seeded AS (
  INSERT INTO product_thesis_statements_r2829
    (quarter, thesis_title, thesis_statement, pillar, hypothesis, primary_signal, validation_metric, target_value, current_value, confidence_pct, capital_stake_lakh, decision, verdict, outcome_note, asserted_on, reviewed_on)
  VALUES
    ('Q2-FY27','Hospital chains are the wedge','Multi-site chains adopt 4x faster than single hospitals once SLA proven','vertical_depth','Chain procurement signs after 2 sites prove 99 pct uptime','signed_chain_msa_count','chain_msas_signed',6,4,72,180,'double_down','partially_validated','4 of 6 target signed; 2 in legal; persist with chain-first GTM','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','AMC float funds engineer payouts','30 pct AMC float covers T plus 1 engineer payout at scale','financial_layer','Pool ledger sustains 30 pct buffer with 80 pct collection','amc_pool_buffer_pct','pool_buffer_pct',30,34,88,90,'persist','validated','Buffer holding at 34 pct over 11 weeks; persist','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','Engineer tier ladder drives retention','Bronze to Gold ladder lifts 90-day retention to 85 pct','operating_system','Visible tier progression reduces churn vs flat pay','engineer_90d_retention','engineer_90d_retention_pct',85,71,55,60,'persist','inconclusive','Retention up from 58 to 71 but below target; iterate ladder slopes','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','Dental vertical first super-specialty','Dental clinics convert at 2.5x general rate due to OEM concentration','vertical_depth','Concentrated OEM list (8 brands) shortens onboarding','dental_conversion_multiple','dental_to_general_conv_ratio',2.5,1.8,48,40,'pivot','partially_validated','1.8x not 2.5x; pivot to dental plus ortho combo','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','Investor data room is GTM','Public investor share link converts inbound LPs in 14 days','distribution','Transparency shortens diligence cycle','public_share_to_term_sheet_days','median_days_share_to_term',14,21,40,15,'park','inconclusive','21 days median; park until 5 more touches measured','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','Cashfree payouts at scale','99.5 pct payout success with auto-retry by Q3 close','financial_layer','Webhook reconciliation closes 99.5 pct within 24h','payout_success_rate','payout_success_pct',99.5,98.2,80,70,'persist','partially_validated','98.2 pct holding; persist with bank-rail diversification','2026-04-01'::date,'2026-06-25'::date),
    ('Q2-FY27','Founder console replaces ops headcount','3 founder + 2 ops scale to 500 sites without new hire','operating_system','Console actions cover 90 pct of ops decisions','founder_console_action_coverage','console_action_coverage_pct',90,82,68,25,'double_down','partially_validated','82 pct coverage; ship 8 more action surfaces','2026-04-01'::date,'2026-06-25'::date)
  RETURNING id, thesis_title
)
INSERT INTO product_thesis_signals_r2829 (thesis_id, signal_label, signal_kind, measured_value, expected_value, delta_pct, strength, direction, observed_on, source, note)
SELECT id, 'Chain MSA pipeline', 'leading', 4, 6, -33.3, 'moderate', 'confirming', '2026-06-20'::date, 'CRM', '4 signed, 2 in legal — pipeline healthy'
FROM seeded WHERE thesis_title = 'Hospital chains are the wedge'
UNION ALL
SELECT id, 'Per-chain ARPU', 'financial', 12.4, 9.0, 37.8, 'strong', 'confirming', '2026-06-22'::date, 'GST invoices', 'Chains pay 37 pct above forecast'
FROM seeded WHERE thesis_title = 'Hospital chains are the wedge'
UNION ALL
SELECT id, 'AMC pool buffer 11-week trailing', 'lagging', 34, 30, 13.3, 'definitive', 'confirming', '2026-06-24'::date, 'amc_payment_pool', 'Buffer 4 pts above target'
FROM seeded WHERE thesis_title = 'AMC float funds engineer payouts'
UNION ALL
SELECT id, 'Engineer 90d retention cohort', 'lagging', 71, 85, -16.5, 'moderate', 'contradicting', '2026-06-18'::date, 'engineers table', 'Up from 58 but short of 85 target'
FROM seeded WHERE thesis_title = 'Engineer tier ladder drives retention'
UNION ALL
SELECT id, 'Dental conversion ratio', 'leading', 1.8, 2.5, -28.0, 'moderate', 'contradicting', '2026-06-15'::date, 'analytics_funnel', 'Below 2.5x; ortho combo testing'
FROM seeded WHERE thesis_title = 'Dental vertical first super-specialty'
UNION ALL
SELECT id, 'LP touch to term-sheet days', 'lagging', 21, 14, 50.0, 'weak', 'contradicting', '2026-06-10'::date, 'investor_room_views', 'Slower than thesis — small n'
FROM seeded WHERE thesis_title = 'Investor data room is GTM'
UNION ALL
SELECT id, 'Payout webhook success', 'operational', 98.2, 99.5, -1.3, 'strong', 'confirming', '2026-06-25'::date, 'cashfree webhooks', 'Close to target; diversify rails'
FROM seeded WHERE thesis_title = 'Cashfree payouts at scale'
UNION ALL
SELECT id, 'Console action coverage audit', 'qualitative', 82, 90, -8.9, 'strong', 'confirming', '2026-06-23'::date, 'manual audit', '82 pct of ops decisions automated'
FROM seeded WHERE thesis_title = 'Founder console replaces ops headcount';

-- RPCs

DROP FUNCTION IF EXISTS founder_thesis_overview_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_overview_r2829()
RETURNS TABLE(total_theses int, validated int, partially int, inconclusive int, invalidated int, total_stake_lakh numeric, avg_confidence numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE verdict='validated')::int,
    COUNT(*) FILTER (WHERE verdict='partially_validated')::int,
    COUNT(*) FILTER (WHERE verdict='inconclusive')::int,
    COUNT(*) FILTER (WHERE verdict='invalidated')::int,
    COALESCE(SUM(capital_stake_lakh),0),
    COALESCE(ROUND(AVG(confidence_pct),1),0)
  FROM product_thesis_statements_r2829;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_overview_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_overview_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_by_pillar_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_by_pillar_r2829()
RETURNS TABLE(pillar text, thesis_count int, avg_confidence numeric, total_stake_lakh numeric, persist_count int, pivot_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.pillar,
    COUNT(*)::int,
    ROUND(AVG(t.confidence_pct),1),
    SUM(t.capital_stake_lakh),
    COUNT(*) FILTER (WHERE t.decision IN ('persist','double_down'))::int,
    COUNT(*) FILTER (WHERE t.decision='pivot')::int
  FROM product_thesis_statements_r2829 t
  GROUP BY t.pillar
  ORDER BY SUM(t.capital_stake_lakh) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_by_pillar_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_by_pillar_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_statements_list_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_statements_list_r2829()
RETURNS TABLE(id uuid, thesis_title text, pillar text, decision text, verdict text, confidence_pct numeric, capital_stake_lakh numeric, target_value numeric, current_value numeric, attainment_pct numeric, outcome_note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id, t.thesis_title, t.pillar, t.decision, t.verdict, t.confidence_pct, t.capital_stake_lakh,
    t.target_value, t.current_value,
    CASE WHEN t.target_value=0 THEN 0 ELSE ROUND((t.current_value/t.target_value)*100,1) END,
    t.outcome_note
  FROM product_thesis_statements_r2829 t
  ORDER BY t.capital_stake_lakh DESC, t.confidence_pct DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_statements_list_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_statements_list_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_signals_list_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_signals_list_r2829()
RETURNS TABLE(signal_label text, thesis_title text, signal_kind text, measured_value numeric, expected_value numeric, delta_pct numeric, strength text, direction text, observed_on date, note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_label, t.thesis_title, s.signal_kind, s.measured_value, s.expected_value, s.delta_pct, s.strength, s.direction, s.observed_on, s.note
  FROM product_thesis_signals_r2829 s
  JOIN product_thesis_statements_r2829 t ON t.id = s.thesis_id
  ORDER BY s.observed_on DESC, s.signal_label;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_signals_list_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_signals_list_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_decision_breakdown_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_decision_breakdown_r2829()
RETURNS TABLE(decision text, thesis_count int, total_stake_lakh numeric, avg_confidence numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.decision, COUNT(*)::int, SUM(t.capital_stake_lakh), ROUND(AVG(t.confidence_pct),1)
  FROM product_thesis_statements_r2829 t
  GROUP BY t.decision
  ORDER BY SUM(t.capital_stake_lakh) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_decision_breakdown_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_decision_breakdown_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_signal_strength_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_signal_strength_r2829()
RETURNS TABLE(direction text, strength text, signal_count int, avg_delta_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.direction, s.strength, COUNT(*)::int, ROUND(AVG(s.delta_pct),1)
  FROM product_thesis_signals_r2829 s
  GROUP BY s.direction, s.strength
  ORDER BY s.direction, s.strength;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_signal_strength_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_signal_strength_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_at_risk_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_at_risk_r2829()
RETURNS TABLE(thesis_title text, pillar text, confidence_pct numeric, capital_stake_lakh numeric, verdict text, decision text, attainment_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.thesis_title, t.pillar, t.confidence_pct, t.capital_stake_lakh, t.verdict, t.decision,
    CASE WHEN t.target_value=0 THEN 0 ELSE ROUND((t.current_value/t.target_value)*100,1) END
  FROM product_thesis_statements_r2829 t
  WHERE t.confidence_pct < 70 OR t.verdict IN ('inconclusive','invalidated')
  ORDER BY t.capital_stake_lakh DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_at_risk_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_at_risk_r2829() TO authenticated;

DROP FUNCTION IF EXISTS founder_thesis_capital_at_stake_r2829();
CREATE OR REPLACE FUNCTION founder_thesis_capital_at_stake_r2829()
RETURNS TABLE(verdict text, total_stake_lakh numeric, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  grand numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(capital_stake_lakh),0) INTO grand FROM product_thesis_statements_r2829;
  RETURN QUERY
  SELECT t.verdict, SUM(t.capital_stake_lakh),
    CASE WHEN grand=0 THEN 0 ELSE ROUND((SUM(t.capital_stake_lakh)/grand)*100,1) END
  FROM product_thesis_statements_r2829 t
  GROUP BY t.verdict
  ORDER BY SUM(t.capital_stake_lakh) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_thesis_capital_at_stake_r2829() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_thesis_capital_at_stake_r2829() TO authenticated;

COMMIT;
