-- Round 2913 — Quarterly Strategic Founder-Time Allocation Audit
-- HEAVY founder ops round: 2 tables + 7 RPCs (is_founder gated)

BEGIN;

-- ============================================================
-- Table 1: quarterly time blocks
-- ============================================================
CREATE TABLE IF NOT EXISTS founder_time_blocks_r2913 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  quarter text NOT NULL,
  block_date date NOT NULL,
  category text NOT NULL,
  strategic_pillar text NOT NULL,
  hours_spent numeric(6,2) NOT NULL,
  target_hours numeric(6,2) NOT NULL,
  energy_score integer NOT NULL,
  outcome_score integer NOT NULL,
  delegatable boolean NOT NULL DEFAULT false,
  notes text
);

ALTER TABLE founder_time_blocks_r2913 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: pillar weekly snapshots
-- ============================================================
CREATE TABLE IF NOT EXISTS founder_pillar_snapshots_r2913 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  quarter text NOT NULL,
  week_starting date NOT NULL,
  strategic_pillar text NOT NULL,
  hours_invested numeric(6,2) NOT NULL,
  decisions_made integer NOT NULL,
  decisions_deferred integer NOT NULL,
  outcomes_shipped integer NOT NULL,
  reflection text
);

ALTER TABLE founder_pillar_snapshots_r2913 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seed: founder_time_blocks_r2913 (24 rows)
-- ============================================================
INSERT INTO founder_time_blocks_r2913 (quarter, block_date, category, strategic_pillar, hours_spent, target_hours, energy_score, outcome_score, delegatable, notes) VALUES
('Q1-2026','2026-01-06'::date,'Product Strategy','Marketplace Growth',6.50,5.00,8,9,false,'Reviewed v0.4 roadmap with engineering'),
('Q1-2026','2026-01-07'::date,'Customer Calls','Hospital Chains',4.00,4.00,7,8,false,'KIMS chain quarterly review'),
('Q1-2026','2026-01-08'::date,'Operations','Engineer Quality',3.50,2.00,5,6,true,'Reviewing engineer onboarding queue'),
('Q1-2026','2026-01-12'::date,'Fundraising','Investor Relations',5.00,4.00,6,7,false,'Series A pitch deck v3 iteration'),
('Q1-2026','2026-01-14'::date,'Hiring','Team Building',4.50,3.00,7,8,false,'VP Engineering pipeline review'),
('Q1-2026','2026-01-19'::date,'Product Strategy','Marketplace Growth',7.00,5.00,9,9,false,'AMC tier system architecture deep-dive'),
('Q1-2026','2026-01-21'::date,'Customer Calls','Hospital Chains',3.00,4.00,6,7,false,'Apollo regional director sync'),
('Q1-2026','2026-01-23'::date,'Admin/Email','Operations',2.50,1.00,3,4,true,'Inbox triage and HR forms'),
('Q1-2026','2026-01-26'::date,'Fundraising','Investor Relations',6.00,4.00,7,8,false,'Term sheet negotiation with Lightspeed'),
('Q2-2026','2026-04-03'::date,'Product Strategy','Engineer App',5.50,5.00,8,9,false,'Engineer v0.5 supervised training feature spec'),
('Q2-2026','2026-04-07'::date,'Customer Calls','Hospital Chains',4.00,4.00,8,9,false,'Manipal chain expansion talks'),
('Q2-2026','2026-04-10'::date,'Compliance','Regulatory',3.50,3.00,5,6,false,'DPDP Act readiness review'),
('Q2-2026','2026-04-14'::date,'Operations','Engineer Quality',4.00,2.00,4,5,true,'Engineer payout escalations triage'),
('Q2-2026','2026-04-17'::date,'Fundraising','Investor Relations',7.00,4.00,8,9,false,'Sequoia partner meeting + follow-up'),
('Q2-2026','2026-04-21'::date,'Hiring','Team Building',5.00,3.00,7,8,false,'Head of Sales final-round interviews'),
('Q2-2026','2026-04-24'::date,'Product Strategy','Marketplace Growth',6.00,5.00,9,9,false,'Founder console roadmap planning'),
('Q3-2026','2026-07-02'::date,'Product Strategy','AI/ML',5.50,5.00,9,8,false,'AI triage v0 architecture'),
('Q3-2026','2026-07-08'::date,'Customer Calls','Hospital Chains',4.50,4.00,8,9,false,'Fortis chain integration kickoff'),
('Q3-2026','2026-07-11'::date,'Operations','Engineer Quality',3.00,2.00,6,7,true,'Engineer dispute board review'),
('Q3-2026','2026-07-15'::date,'Fundraising','Investor Relations',4.00,3.00,7,8,false,'Series A board update prep'),
('Q3-2026','2026-07-18'::date,'Admin/Email','Operations',3.00,1.00,2,3,true,'Quarterly statutory filings review'),
('Q3-2026','2026-07-22'::date,'Product Strategy','Marketplace Growth',6.50,5.00,8,9,false,'International expansion (SL/BD) discovery'),
('Q3-2026','2026-07-25'::date,'Hiring','Team Building',4.00,3.00,6,7,false,'Engineering manager candidate loop'),
('Q3-2026','2026-07-29'::date,'Customer Calls','Hospital Chains',5.00,4.00,9,9,false,'Max Healthcare CEO dinner');

-- ============================================================
-- Seed: founder_pillar_snapshots_r2913 (18 rows)
-- ============================================================
INSERT INTO founder_pillar_snapshots_r2913 (quarter, week_starting, strategic_pillar, hours_invested, decisions_made, decisions_deferred, outcomes_shipped, reflection) VALUES
('Q1-2026','2026-01-05'::date,'Marketplace Growth',14.00,8,2,5,'Strong week — AMC tier system locked'),
('Q1-2026','2026-01-05'::date,'Hospital Chains',7.00,3,1,2,'KIMS contract renewal in flight'),
('Q1-2026','2026-01-05'::date,'Investor Relations',5.00,2,3,1,'Pitch deck still iterating'),
('Q1-2026','2026-01-12'::date,'Marketplace Growth',12.00,6,1,4,'Engineer payout pipeline shipped'),
('Q1-2026','2026-01-12'::date,'Team Building',4.50,2,1,1,'VP Eng shortlist narrowed to 3'),
('Q1-2026','2026-01-12'::date,'Operations',6.00,4,2,3,'Inbox bankruptcy declared; auto-routing on'),
('Q1-2026','2026-01-19'::date,'Marketplace Growth',16.00,10,1,7,'Best week of quarter'),
('Q1-2026','2026-01-19'::date,'Investor Relations',8.00,3,2,2,'Lightspeed term sheet received'),
('Q1-2026','2026-01-26'::date,'Investor Relations',9.00,5,1,3,'Term sheet negotiations active'),
('Q2-2026','2026-04-06'::date,'Engineer App',11.50,7,2,4,'Supervised training shipped to prod'),
('Q2-2026','2026-04-06'::date,'Hospital Chains',7.00,3,1,2,'Manipal chain pilot started'),
('Q2-2026','2026-04-13'::date,'Regulatory',5.50,4,1,1,'DPDP grievance routing live'),
('Q2-2026','2026-04-13'::date,'Engineer Quality',6.00,3,3,2,'Quality bar tightened — 4 engineers offboarded'),
('Q2-2026','2026-04-20'::date,'Investor Relations',8.50,4,1,2,'Sequoia diligence kicked off'),
('Q2-2026','2026-04-20'::date,'Team Building',6.00,2,1,1,'Head of Sales offer extended'),
('Q3-2026','2026-07-06'::date,'AI/ML',7.50,4,2,1,'Triage v0 prototype shipped'),
('Q3-2026','2026-07-13'::date,'Hospital Chains',9.50,5,1,3,'Fortis integration kicked off'),
('Q3-2026','2026-07-20'::date,'Marketplace Growth',9.00,6,2,4,'International expansion discovery wrapped');

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_kpi_summary()
RETURNS TABLE(
  total_hours_logged numeric,
  total_target_hours numeric,
  hours_variance numeric,
  avg_energy_score numeric,
  avg_outcome_score numeric,
  delegatable_hours numeric,
  delegatable_percent numeric,
  total_blocks integer,
  quarters_covered integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(SUM(hours_spent),0)::numeric,
    COALESCE(SUM(target_hours),0)::numeric,
    COALESCE(SUM(hours_spent) - SUM(target_hours),0)::numeric,
    COALESCE(AVG(energy_score),0)::numeric(5,2),
    COALESCE(AVG(outcome_score),0)::numeric(5,2),
    COALESCE(SUM(CASE WHEN delegatable THEN hours_spent ELSE 0 END),0)::numeric,
    CASE WHEN COALESCE(SUM(hours_spent),0) > 0
      THEN ROUND(100.0 * SUM(CASE WHEN delegatable THEN hours_spent ELSE 0 END) / SUM(hours_spent), 2)
      ELSE 0 END,
    COUNT(*)::integer,
    COUNT(DISTINCT quarter)::integer
  FROM founder_time_blocks_r2913;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_kpi_summary() TO authenticated;

-- ============================================================
-- RPC 2: time by pillar
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_time_by_pillar()
RETURNS TABLE(
  strategic_pillar text,
  total_hours numeric,
  target_hours numeric,
  variance numeric,
  avg_outcome numeric,
  block_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.strategic_pillar,
    SUM(b.hours_spent)::numeric,
    SUM(b.target_hours)::numeric,
    (SUM(b.hours_spent) - SUM(b.target_hours))::numeric,
    ROUND(AVG(b.outcome_score)::numeric, 2),
    COUNT(*)::integer
  FROM founder_time_blocks_r2913 b
  GROUP BY b.strategic_pillar
  ORDER BY SUM(b.hours_spent) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_time_by_pillar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_time_by_pillar() TO authenticated;

-- ============================================================
-- RPC 3: time by category
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_time_by_category()
RETURNS TABLE(
  category text,
  total_hours numeric,
  avg_energy numeric,
  avg_outcome numeric,
  delegatable_hours numeric,
  block_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.category,
    SUM(b.hours_spent)::numeric,
    ROUND(AVG(b.energy_score)::numeric, 2),
    ROUND(AVG(b.outcome_score)::numeric, 2),
    SUM(CASE WHEN b.delegatable THEN b.hours_spent ELSE 0 END)::numeric,
    COUNT(*)::integer
  FROM founder_time_blocks_r2913 b
  GROUP BY b.category
  ORDER BY SUM(b.hours_spent) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_time_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_time_by_category() TO authenticated;

-- ============================================================
-- RPC 4: quarter rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_quarter_rollup()
RETURNS TABLE(
  quarter text,
  total_hours numeric,
  target_hours numeric,
  variance numeric,
  avg_energy numeric,
  avg_outcome numeric,
  block_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.quarter,
    SUM(b.hours_spent)::numeric,
    SUM(b.target_hours)::numeric,
    (SUM(b.hours_spent) - SUM(b.target_hours))::numeric,
    ROUND(AVG(b.energy_score)::numeric, 2),
    ROUND(AVG(b.outcome_score)::numeric, 2),
    COUNT(*)::integer
  FROM founder_time_blocks_r2913 b
  GROUP BY b.quarter
  ORDER BY b.quarter;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_quarter_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_quarter_rollup() TO authenticated;

-- ============================================================
-- RPC 5: top time blocks (drilldown)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_top_blocks()
RETURNS TABLE(
  id uuid,
  quarter text,
  block_date date,
  category text,
  strategic_pillar text,
  hours_spent numeric,
  energy_score integer,
  outcome_score integer,
  delegatable boolean,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.id, b.quarter, b.block_date, b.category, b.strategic_pillar,
    b.hours_spent, b.energy_score, b.outcome_score, b.delegatable, b.notes
  FROM founder_time_blocks_r2913 b
  ORDER BY b.hours_spent DESC, b.block_date DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_top_blocks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_top_blocks() TO authenticated;

-- ============================================================
-- RPC 6: pillar snapshots
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_pillar_snapshots()
RETURNS TABLE(
  id uuid,
  quarter text,
  week_starting date,
  strategic_pillar text,
  hours_invested numeric,
  decisions_made integer,
  decisions_deferred integer,
  outcomes_shipped integer,
  reflection text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id, s.quarter, s.week_starting, s.strategic_pillar,
    s.hours_invested, s.decisions_made, s.decisions_deferred,
    s.outcomes_shipped, s.reflection
  FROM founder_pillar_snapshots_r2913 s
  ORDER BY s.week_starting DESC, s.hours_invested DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_pillar_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_pillar_snapshots() TO authenticated;

-- ============================================================
-- RPC 7: delegation candidates
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2913_delegation_candidates()
RETURNS TABLE(
  category text,
  strategic_pillar text,
  delegatable_hours numeric,
  avg_energy numeric,
  avg_outcome numeric,
  block_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.category,
    b.strategic_pillar,
    SUM(b.hours_spent)::numeric,
    ROUND(AVG(b.energy_score)::numeric, 2),
    ROUND(AVG(b.outcome_score)::numeric, 2),
    COUNT(*)::integer
  FROM founder_time_blocks_r2913 b
  WHERE b.delegatable = true
  GROUP BY b.category, b.strategic_pillar
  ORDER BY SUM(b.hours_spent) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2913_delegation_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2913_delegation_candidates() TO authenticated;

COMMIT;
