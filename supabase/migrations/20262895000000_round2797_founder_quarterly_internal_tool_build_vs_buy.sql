BEGIN;

-- ============================================================
-- Round 2797: Founder Quarterly Internal Tool Build-vs-Buy
-- ============================================================

CREATE TABLE IF NOT EXISTS internal_tool_candidates_r2797 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tool_name text NOT NULL,
  need_description text NOT NULL,
  current_pain_level text NOT NULL CHECK (current_pain_level IN ('low','medium','high','critical')),
  current_workaround text NOT NULL,
  estimated_users int NOT NULL CHECK (estimated_users > 0),
  build_estimate_weeks numeric(5,1) NOT NULL CHECK (build_estimate_weeks > 0),
  build_estimate_rupees bigint NOT NULL CHECK (build_estimate_rupees > 0),
  ongoing_maint_rupees_yearly bigint NOT NULL CHECK (ongoing_maint_rupees_yearly >= 0),
  buy_options text NOT NULL,
  buy_cost_rupees_yearly bigint NOT NULL CHECK (buy_cost_rupees_yearly >= 0),
  strategic_moat_score int NOT NULL CHECK (strategic_moat_score BETWEEN 1 AND 10),
  verdict text NOT NULL CHECK (verdict IN ('build','buy','hybrid','defer','kill')),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE internal_tool_candidates_r2797 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON internal_tool_candidates_r2797 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS internal_tool_decisions_r2797 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES internal_tool_candidates_r2797(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('build','buy','hybrid','defer','kill')),
  decision_owner text NOT NULL,
  budget_approved_rupees bigint NOT NULL CHECK (budget_approved_rupees >= 0),
  target_ship_date date NOT NULL,
  actual_outcome text NOT NULL CHECK (actual_outcome IN ('pending','shipped_on_time','shipped_late','shipped_overbudget','rolled_back','cancelled')),
  rupees_actually_spent bigint NOT NULL CHECK (rupees_actually_spent >= 0),
  retro_lesson text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE internal_tool_decisions_r2797 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON internal_tool_decisions_r2797 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seed data
-- ============================================================

INSERT INTO internal_tool_candidates_r2797 (tool_name, need_description, current_pain_level, current_workaround, estimated_users, build_estimate_weeks, build_estimate_rupees, ongoing_maint_rupees_yearly, buy_options, buy_cost_rupees_yearly, strategic_moat_score, verdict) VALUES
('Engineer dispatch optimizer', 'Auto-route repair jobs to nearest engineer with right tier+skill', 'critical', 'Founder manually assigns in Telegram', 8, 6.0, 1800000, 600000, 'Onfleet (8k/mo), Bringg (12k/mo)', 1440000, 9, 'build'),
('Hospital BD CRM', 'Track 200+ hospital chains pipeline + procurement contacts', 'high', 'Notion database manually updated', 4, 4.0, 800000, 200000, 'HubSpot (3k/mo), Salesforce (12k/mo)', 540000, 4, 'buy'),
('GST e-invoice generator', 'Generate IRN+QR for invoices > 5cr turnover', 'critical', 'Manual ClearTax portal upload', 6, 5.0, 1200000, 400000, 'ClearTax API (60k/yr), Zoho (40k/yr)', 60000, 5, 'hybrid'),
('Engineer training LMS', 'Video courses + quizzes + tier certification', 'medium', 'Google Drive folder + WhatsApp quizzes', 30, 8.0, 2400000, 800000, 'TalentLMS (2k/mo), Docebo (8k/mo)', 360000, 6, 'buy'),
('AMC contract auto-renewal', 'Detect expiring AMCs + send renewal proposals + capture payment', 'high', 'Founder weekly spreadsheet check', 12, 5.0, 1500000, 500000, 'No off-shelf option fits', 0, 9, 'build'),
('Field-engineer photo QC', 'AI-verify before/after repair photos match job', 'medium', 'Founder eyeballs every job', 6, 12.0, 3600000, 1200000, 'Google Vision API + custom prompt (180k/yr)', 180000, 7, 'hybrid'),
('Investor data room', 'Public read-only deck + metrics for 50 investors', 'high', 'Notion shared page', 50, 3.0, 600000, 100000, 'DocSend (4k/mo), Foundersuite (6k/mo)', 720000, 3, 'buy'),
('Founder daily-brief email', 'Auto-compile KPIs + alerts every 08:00 IST', 'medium', 'Manual snapshot grep', 1, 2.0, 400000, 50000, 'Tableau Pulse (15k/mo), Metabase (10k/mo)', 1800000, 8, 'build'),
('Spare-part inventory ML forecast', 'Predict reorder 30 days ahead per part SKU', 'low', 'Reactive reorder when stockout', 4, 10.0, 3000000, 1000000, 'Inventory Planner (5k/mo), Ordoro (3k/mo)', 600000, 6, 'defer'),
('Customer NPS survey tool', 'Post-job CSAT + NPS + churn-risk scoring', 'medium', 'Manual google form link', 200, 3.0, 600000, 150000, 'Delighted (2k/mo), Wootric (3k/mo)', 360000, 4, 'buy');

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q1-2026', 'build', 'Ganesh', 2000000, '2026-03-31'::date, 'shipped_on_time', 1850000, 'Custom routing won — engineer SLA improved 35%'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Engineer dispatch optimizer';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q1-2026', 'buy', 'BD lead', 540000, '2026-02-15'::date, 'shipped_on_time', 540000, 'HubSpot free tier worked — saved 800k build'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Hospital BD CRM';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q2-2026', 'hybrid', 'Ganesh', 700000, '2026-05-15'::date, 'shipped_late', 850000, 'ClearTax API + thin UI layer — should have started earlier'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'GST e-invoice generator';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q2-2026', 'buy', 'Training lead', 360000, '2026-04-30'::date, 'shipped_on_time', 360000, 'TalentLMS bought back 8 weeks of eng time'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Engineer training LMS';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q2-2026', 'build', 'Ganesh', 1700000, '2026-06-30'::date, 'shipped_on_time', 1500000, 'Renewal flow is core moat — never outsource'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'AMC contract auto-renewal';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q3-2026', 'defer', 'Ganesh', 0, '2026-09-30'::date, 'cancelled', 0, 'Volume too low to justify ML — revisit at 1000 jobs/mo'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Spare-part inventory ML forecast';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q3-2026', 'build', 'Ganesh', 450000, '2026-07-15'::date, 'shipped_on_time', 380000, 'Daily-brief is founder-superpower — must be custom'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Founder daily-brief email';

INSERT INTO internal_tool_decisions_r2797 (candidate_id, quarter_label, decision, decision_owner, budget_approved_rupees, target_ship_date, actual_outcome, rupees_actually_spent, retro_lesson)
SELECT id, 'Q3-2026', 'buy', 'CS lead', 360000, '2026-08-15'::date, 'pending', 0, 'Delighted POC starts next week'
FROM internal_tool_candidates_r2797 WHERE tool_name = 'Customer NPS survey tool';

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2797_kpis();
CREATE OR REPLACE FUNCTION founder_r2797_kpis()
RETURNS TABLE(
  total_candidates bigint,
  build_count bigint,
  buy_count bigint,
  hybrid_count bigint,
  defer_kill_count bigint,
  total_build_estimate_rupees bigint,
  total_buy_yearly_rupees bigint,
  avg_moat_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE verdict = 'build'),
    COUNT(*) FILTER (WHERE verdict = 'buy'),
    COUNT(*) FILTER (WHERE verdict = 'hybrid'),
    COUNT(*) FILTER (WHERE verdict IN ('defer','kill')),
    COALESCE(SUM(build_estimate_rupees) FILTER (WHERE verdict IN ('build','hybrid')), 0)::bigint,
    COALESCE(SUM(buy_cost_rupees_yearly) FILTER (WHERE verdict IN ('buy','hybrid')), 0)::bigint,
    ROUND(AVG(strategic_moat_score)::numeric, 2)
  FROM internal_tool_candidates_r2797;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_candidates();
CREATE OR REPLACE FUNCTION founder_r2797_candidates()
RETURNS SETOF internal_tool_candidates_r2797
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM internal_tool_candidates_r2797 ORDER BY strategic_moat_score DESC, build_estimate_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_candidates() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_decisions();
CREATE OR REPLACE FUNCTION founder_r2797_decisions()
RETURNS TABLE(
  tool_name text,
  quarter_label text,
  decision text,
  decision_owner text,
  budget_approved_rupees bigint,
  rupees_actually_spent bigint,
  target_ship_date date,
  actual_outcome text,
  retro_lesson text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.tool_name, d.quarter_label, d.decision, d.decision_owner,
         d.budget_approved_rupees, d.rupees_actually_spent,
         d.target_ship_date, d.actual_outcome, d.retro_lesson
  FROM internal_tool_decisions_r2797 d
  JOIN internal_tool_candidates_r2797 c ON c.id = d.candidate_id
  ORDER BY d.target_ship_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_decisions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_verdict_breakdown();
CREATE OR REPLACE FUNCTION founder_r2797_verdict_breakdown()
RETURNS TABLE(
  verdict text,
  candidate_count bigint,
  total_build_rupees bigint,
  total_buy_yearly_rupees bigint,
  avg_moat numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.verdict,
         COUNT(*)::bigint,
         COALESCE(SUM(c.build_estimate_rupees), 0)::bigint,
         COALESCE(SUM(c.buy_cost_rupees_yearly), 0)::bigint,
         ROUND(AVG(c.strategic_moat_score)::numeric, 2)
  FROM internal_tool_candidates_r2797 c
  GROUP BY c.verdict
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_verdict_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_high_moat_builds();
CREATE OR REPLACE FUNCTION founder_r2797_high_moat_builds()
RETURNS TABLE(
  tool_name text,
  need_description text,
  strategic_moat_score int,
  build_estimate_weeks numeric,
  build_estimate_rupees bigint,
  verdict text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.tool_name, c.need_description, c.strategic_moat_score,
         c.build_estimate_weeks, c.build_estimate_rupees, c.verdict
  FROM internal_tool_candidates_r2797 c
  WHERE c.strategic_moat_score >= 7
  ORDER BY c.strategic_moat_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_high_moat_builds() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_high_moat_builds() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_budget_variance();
CREATE OR REPLACE FUNCTION founder_r2797_budget_variance()
RETURNS TABLE(
  tool_name text,
  quarter_label text,
  budget_approved_rupees bigint,
  rupees_actually_spent bigint,
  variance_rupees bigint,
  variance_pct numeric,
  actual_outcome text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.tool_name, d.quarter_label,
         d.budget_approved_rupees, d.rupees_actually_spent,
         (d.rupees_actually_spent - d.budget_approved_rupees)::bigint,
         CASE WHEN d.budget_approved_rupees = 0 THEN 0::numeric
              ELSE ROUND(((d.rupees_actually_spent - d.budget_approved_rupees)::numeric * 100 / d.budget_approved_rupees), 1)
         END,
         d.actual_outcome
  FROM internal_tool_decisions_r2797 d
  JOIN internal_tool_candidates_r2797 c ON c.id = d.candidate_id
  WHERE d.actual_outcome NOT IN ('pending','cancelled')
  ORDER BY ABS(d.rupees_actually_spent - d.budget_approved_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_budget_variance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_budget_variance() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_outcome_summary();
CREATE OR REPLACE FUNCTION founder_r2797_outcome_summary()
RETURNS TABLE(
  actual_outcome text,
  decision_count bigint,
  total_spent_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.actual_outcome,
         COUNT(*)::bigint,
         COALESCE(SUM(d.rupees_actually_spent), 0)::bigint
  FROM internal_tool_decisions_r2797 d
  GROUP BY d.actual_outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_outcome_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_outcome_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2797_pain_review();
CREATE OR REPLACE FUNCTION founder_r2797_pain_review()
RETURNS TABLE(
  current_pain_level text,
  candidate_count bigint,
  avg_users numeric,
  avg_moat numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.current_pain_level,
         COUNT(*)::bigint,
         ROUND(AVG(c.estimated_users)::numeric, 1),
         ROUND(AVG(c.strategic_moat_score)::numeric, 2)
  FROM internal_tool_candidates_r2797 c
  GROUP BY c.current_pain_level
  ORDER BY CASE c.current_pain_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2797_pain_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2797_pain_review() TO authenticated;

COMMIT;
