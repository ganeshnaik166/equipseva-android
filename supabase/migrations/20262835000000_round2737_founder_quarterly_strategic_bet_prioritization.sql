BEGIN;

-- ============================================================================
-- Round 2737 — Founder Quarterly Strategic Bet Prioritization
-- bet × cost × upside × risk × commit × stop × reweight decision
-- ============================================================================

CREATE TABLE IF NOT EXISTS strategic_bets_r2737 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_code text NOT NULL UNIQUE,
  bet_name text NOT NULL,
  thesis text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027','Q2-2027')),
  category text NOT NULL CHECK (category IN ('vertical','geo','product','platform','ops','ai','channel')),
  cost_inr_lakhs numeric(12,2) NOT NULL CHECK (cost_inr_lakhs >= 0),
  upside_inr_lakhs numeric(14,2) NOT NULL CHECK (upside_inr_lakhs >= 0),
  risk_score numeric(4,2) NOT NULL CHECK (risk_score >= 0 AND risk_score <= 10),
  confidence_pct int NOT NULL CHECK (confidence_pct >= 0 AND confidence_pct <= 100),
  commit_level text NOT NULL CHECK (commit_level IN ('explore','pilot','commit','double_down','kill')),
  stop_trigger text NOT NULL,
  payback_months int NOT NULL CHECK (payback_months > 0),
  status text NOT NULL CHECK (status IN ('proposed','active','at_risk','paused','killed','succeeded')),
  owner_handle text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE strategic_bets_r2737 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON strategic_bets_r2737;
CREATE POLICY founder_all ON strategic_bets_r2737 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS bet_reweight_events_r2737 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_code text NOT NULL REFERENCES strategic_bets_r2737(bet_code) ON DELETE CASCADE,
  event_date date NOT NULL,
  prior_commit text NOT NULL CHECK (prior_commit IN ('explore','pilot','commit','double_down','kill')),
  new_commit text NOT NULL CHECK (new_commit IN ('explore','pilot','commit','double_down','kill')),
  prior_weight_pct int NOT NULL CHECK (prior_weight_pct >= 0 AND prior_weight_pct <= 100),
  new_weight_pct int NOT NULL CHECK (new_weight_pct >= 0 AND new_weight_pct <= 100),
  evidence_note text NOT NULL,
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','moderate','strong','overwhelming')),
  decided_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bet_reweight_events_r2737 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bet_reweight_events_r2737;
CREATE POLICY founder_all ON bet_reweight_events_r2737 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seeds
-- ============================================================================

INSERT INTO strategic_bets_r2737 (bet_code, bet_name, thesis, quarter, category, cost_inr_lakhs, upside_inr_lakhs, risk_score, confidence_pct, commit_level, stop_trigger, payback_months, status, owner_handle) VALUES
  ('BET-DENTAL-CHAIN', 'Dental chain vertical expansion', 'Dental chains have 6x AMC density vs single clinics; bundle pricing wins all 50 Apollo dental sites', 'Q3-2026', 'vertical', 42.00, 320.00, 4.20, 72, 'commit', 'GTM under 8 contracts by end of Q3', 9, 'active', 'ganesh'),
  ('BET-TIER2-HYD', 'Tier-2 Telangana cluster', 'Warangal+Khammam+Karimnagar uncontested; ride state govt diagnostics push', 'Q4-2026', 'geo', 18.50, 110.00, 5.80, 60, 'pilot', 'Sub-30 day SLA breach 3+ months', 14, 'active', 'ganesh'),
  ('BET-AI-TRIAGE', 'AI triage chatbot for hospitals', 'GPT-4o triage cuts engineer dispatches 25%; gross margin boost 6pp', 'Q2-2026', 'ai', 28.00, 240.00, 6.50, 55, 'pilot', 'Recall below 88% at 3-month review', 11, 'at_risk', 'ganesh'),
  ('BET-FRANCHISE', 'Engineer franchise model', 'Convert top-tier engineers to franchise owners; capital-light geo expansion', 'Q1-2027', 'ops', 12.00, 180.00, 7.10, 45, 'explore', '2 of first 3 pilots fail unit economics', 18, 'proposed', 'ganesh'),
  ('BET-HOSPITAL-DR', 'Hospital data room SaaS', 'Productize founder console as paid SaaS to non-customer hospitals; ₹15k/mo per facility', 'Q4-2026', 'product', 22.50, 90.00, 7.80, 35, 'explore', 'Below 5 paid logos by end of Q1-2027', 21, 'proposed', 'ganesh'),
  ('BET-INTL-SL', 'Sri Lanka pilot', 'Lower competitive density + USD pricing; 3 hospital LOIs signed already', 'Q2-2027', 'geo', 35.00, 160.00, 8.40, 30, 'explore', 'Customs+import duty kills margin below 30%', 24, 'proposed', 'ganesh'),
  ('BET-AMC-V3', 'AMC v3 dynamic pricing engine', 'ML-priced AMC tiers boost ARPU 18%; commit-after-pilot quarterly review', 'Q2-2026', 'platform', 8.50, 95.00, 3.40, 80, 'double_down', 'Tier1 churn spikes above 4% monthly', 6, 'active', 'ganesh');

INSERT INTO bet_reweight_events_r2737 (bet_code, event_date, prior_commit, new_commit, prior_weight_pct, new_weight_pct, evidence_note, signal_strength, decided_by) VALUES
  ('BET-DENTAL-CHAIN', '2026-04-15'::date, 'pilot', 'commit', 10, 25, '3 of 3 pilot Apollo dental sites converted; NPS 72', 'strong', 'ganesh'),
  ('BET-AI-TRIAGE', '2026-05-10'::date, 'commit', 'pilot', 20, 12, 'Recall stuck at 84% — moved back to pilot pending model retraining', 'moderate', 'ganesh'),
  ('BET-AMC-V3', '2026-05-20'::date, 'commit', 'double_down', 18, 30, 'AMC v3 cohort showing 22% ARPU lift vs control; clear winner', 'overwhelming', 'ganesh'),
  ('BET-TIER2-HYD', '2026-06-01'::date, 'explore', 'pilot', 5, 12, 'Telangana govt diagnostics policy ratified — geo tailwind confirmed', 'strong', 'ganesh'),
  ('BET-FRANCHISE', '2026-06-12'::date, 'explore', 'explore', 8, 6, 'Reweighted down — engineer interview signal weaker than expected', 'weak', 'ganesh'),
  ('BET-HOSPITAL-DR', '2026-06-15'::date, 'pilot', 'explore', 15, 8, 'Only 2 paid LOIs — demand not yet validated; downgraded', 'moderate', 'ganesh'),
  ('BET-INTL-SL', '2026-06-18'::date, 'explore', 'explore', 4, 7, 'Bumped up due to 3 LOIs landing same week', 'moderate', 'ganesh');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2737_bet_portfolio_kpis();
CREATE OR REPLACE FUNCTION founder_r2737_bet_portfolio_kpis()
RETURNS TABLE (
  total_bets int,
  active_bets int,
  total_cost_lakhs numeric,
  total_upside_lakhs numeric,
  portfolio_payback_months numeric,
  weighted_risk numeric,
  weighted_confidence numeric,
  doubled_down_count int,
  killed_or_paused_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'active')::int,
    COALESCE(SUM(cost_inr_lakhs),0)::numeric,
    COALESCE(SUM(upside_inr_lakhs),0)::numeric,
    CASE WHEN SUM(upside_inr_lakhs) > 0
      THEN ROUND(SUM(cost_inr_lakhs * payback_months) / NULLIF(SUM(cost_inr_lakhs),0), 1)
      ELSE 0 END,
    ROUND(AVG(risk_score)::numeric, 2),
    ROUND(AVG(confidence_pct)::numeric, 1),
    COUNT(*) FILTER (WHERE commit_level = 'double_down')::int,
    COUNT(*) FILTER (WHERE status IN ('killed','paused'))::int
  FROM strategic_bets_r2737;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_portfolio_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_portfolio_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_priority_ranking();
CREATE OR REPLACE FUNCTION founder_r2737_bet_priority_ranking()
RETURNS TABLE (
  bet_code text,
  bet_name text,
  quarter text,
  commit_level text,
  cost_inr_lakhs numeric,
  upside_inr_lakhs numeric,
  roi_multiple numeric,
  risk_adj_score numeric,
  priority_rank int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.bet_code,
    b.bet_name,
    b.quarter,
    b.commit_level,
    b.cost_inr_lakhs,
    b.upside_inr_lakhs,
    ROUND(b.upside_inr_lakhs / NULLIF(b.cost_inr_lakhs,0), 2),
    ROUND((b.upside_inr_lakhs / NULLIF(b.cost_inr_lakhs,0)) * (b.confidence_pct::numeric / 100.0) / NULLIF(b.risk_score,0), 3),
    RANK() OVER (ORDER BY (b.upside_inr_lakhs / NULLIF(b.cost_inr_lakhs,0)) * (b.confidence_pct::numeric / 100.0) / NULLIF(b.risk_score,0) DESC)::int
  FROM strategic_bets_r2737 b
  WHERE b.status NOT IN ('killed');
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_priority_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_priority_ranking() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_quarter_distribution();
CREATE OR REPLACE FUNCTION founder_r2737_bet_quarter_distribution()
RETURNS TABLE (
  quarter text,
  bet_count int,
  total_cost_lakhs numeric,
  total_upside_lakhs numeric,
  avg_risk numeric,
  avg_confidence numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.quarter,
    COUNT(*)::int,
    SUM(b.cost_inr_lakhs)::numeric,
    SUM(b.upside_inr_lakhs)::numeric,
    ROUND(AVG(b.risk_score)::numeric, 2),
    ROUND(AVG(b.confidence_pct)::numeric, 1)
  FROM strategic_bets_r2737 b
  GROUP BY b.quarter
  ORDER BY b.quarter;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_quarter_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_quarter_distribution() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_reweight_history();
CREATE OR REPLACE FUNCTION founder_r2737_bet_reweight_history()
RETURNS TABLE (
  bet_code text,
  bet_name text,
  event_date date,
  prior_commit text,
  new_commit text,
  prior_weight_pct int,
  new_weight_pct int,
  weight_delta int,
  signal_strength text,
  evidence_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.bet_code,
    b.bet_name,
    r.event_date,
    r.prior_commit,
    r.new_commit,
    r.prior_weight_pct,
    r.new_weight_pct,
    (r.new_weight_pct - r.prior_weight_pct)::int,
    r.signal_strength,
    r.evidence_note
  FROM bet_reweight_events_r2737 r
  JOIN strategic_bets_r2737 b ON b.bet_code = r.bet_code
  ORDER BY r.event_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_reweight_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_reweight_history() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_stop_triggers();
CREATE OR REPLACE FUNCTION founder_r2737_bet_stop_triggers()
RETURNS TABLE (
  bet_code text,
  bet_name text,
  status text,
  commit_level text,
  stop_trigger text,
  risk_score numeric,
  alert_level text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.bet_code,
    b.bet_name,
    b.status,
    b.commit_level,
    b.stop_trigger,
    b.risk_score,
    CASE
      WHEN b.status = 'at_risk' THEN 'critical'
      WHEN b.risk_score >= 7.5 THEN 'high'
      WHEN b.risk_score >= 5.0 THEN 'medium'
      ELSE 'low'
    END
  FROM strategic_bets_r2737 b
  WHERE b.status IN ('active','at_risk','pilot') OR b.commit_level IN ('commit','double_down','pilot')
  ORDER BY b.risk_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_stop_triggers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_stop_triggers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_commit_ladder();
CREATE OR REPLACE FUNCTION founder_r2737_bet_commit_ladder()
RETURNS TABLE (
  commit_level text,
  bet_count int,
  total_cost_lakhs numeric,
  total_upside_lakhs numeric,
  avg_payback_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.commit_level,
    COUNT(*)::int,
    SUM(b.cost_inr_lakhs)::numeric,
    SUM(b.upside_inr_lakhs)::numeric,
    ROUND(AVG(b.payback_months)::numeric, 1)
  FROM strategic_bets_r2737 b
  GROUP BY b.commit_level
  ORDER BY
    CASE b.commit_level
      WHEN 'double_down' THEN 1
      WHEN 'commit' THEN 2
      WHEN 'pilot' THEN 3
      WHEN 'explore' THEN 4
      WHEN 'kill' THEN 5
    END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_commit_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_commit_ladder() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2737_bet_reweight_velocity();
CREATE OR REPLACE FUNCTION founder_r2737_bet_reweight_velocity()
RETURNS TABLE (
  event_month text,
  reweight_count int,
  upgrades int,
  downgrades int,
  net_weight_delta int,
  overwhelming_signals int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(r.event_date, 'YYYY-MM'),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE r.new_weight_pct > r.prior_weight_pct)::int,
    COUNT(*) FILTER (WHERE r.new_weight_pct < r.prior_weight_pct)::int,
    SUM(r.new_weight_pct - r.prior_weight_pct)::int,
    COUNT(*) FILTER (WHERE r.signal_strength = 'overwhelming')::int
  FROM bet_reweight_events_r2737 r
  GROUP BY to_char(r.event_date, 'YYYY-MM')
  ORDER BY to_char(r.event_date, 'YYYY-MM') DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2737_bet_reweight_velocity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2737_bet_reweight_velocity() TO authenticated;

COMMIT;
