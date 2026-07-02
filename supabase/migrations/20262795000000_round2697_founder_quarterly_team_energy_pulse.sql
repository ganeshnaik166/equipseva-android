BEGIN;

-- ============================================================================
-- Round 2697 — Founder Quarterly Team Energy Pulse
-- team member x energy score x signal x supportive action x outcome x follow-up
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: team energy pulse readings
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_energy_pulse_r2697 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_member text NOT NULL,
  role text NOT NULL,
  quarter text NOT NULL,
  pulse_date date NOT NULL,
  energy_score int NOT NULL CHECK (energy_score BETWEEN 1 AND 10),
  signal text NOT NULL CHECK (signal IN ('burnout_risk','steady','high_energy','recovering','disengaged','flow_state')),
  signal_notes text,
  workload_load int NOT NULL CHECK (workload_load BETWEEN 1 AND 10),
  sleep_quality int NOT NULL CHECK (sleep_quality BETWEEN 1 AND 10),
  morale_color text NOT NULL CHECK (morale_color IN ('green','amber','red')),
  flagged_for_followup boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_energy_pulse_r2697 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON team_energy_pulse_r2697;
CREATE POLICY founder_all ON team_energy_pulse_r2697 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO team_energy_pulse_r2697 (team_member, role, quarter, pulse_date, energy_score, signal, signal_notes, workload_load, sleep_quality, morale_color, flagged_for_followup) VALUES
('Aarav Sharma','Senior Engineer','Q2-2026','2026-06-15'::date, 4,'burnout_risk','3 escalations same week + on-call rotation overlap',9,4,'red',true),
('Priya Reddy','Ops Lead','Q2-2026','2026-06-15'::date, 8,'high_energy','Just shipped AMC chain rollout — riding momentum',7,7,'green',false),
('Rohan Iyer','Hospital Account Mgr','Q2-2026','2026-06-15'::date, 6,'steady','Apollo + Yashoda flowing nicely',6,6,'green',false),
('Sneha Kulkarni','Field Engineer Mumbai','Q2-2026','2026-06-15'::date, 3,'disengaged','Quiet in standups, two missed AMC visits',8,5,'red',true),
('Vikram Nair','Founder Office','Q2-2026','2026-06-15'::date, 7,'flow_state','Investor pack + roadmap shipped this week',8,6,'green',false),
('Ananya Gupta','Customer Success','Q2-2026','2026-06-15'::date, 5,'recovering','Back from sick leave, ramping slowly',5,7,'amber',true),
('Kabir Mehta','Spare Parts Lead','Q2-2026','2026-06-15'::date, 7,'steady','Counterfeit-parts process holding up',6,7,'green',false);

-- ---------------------------------------------------------------------------
-- Table 2: supportive actions + outcomes + follow-up
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_energy_actions_r2697 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_id uuid REFERENCES team_energy_pulse_r2697(id) ON DELETE CASCADE,
  team_member text NOT NULL,
  supportive_action text NOT NULL,
  action_category text NOT NULL CHECK (action_category IN ('time_off','workload_shift','1on1','coaching','tool_help','recognition','therapy_stipend','role_change')),
  initiated_by text NOT NULL,
  initiated_at date NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('improved','stable','no_change','declined','still_in_progress','resolved')),
  outcome_notes text,
  followup_due date,
  followup_status text NOT NULL CHECK (followup_status IN ('pending','scheduled','completed','overdue','not_needed')),
  cost_inr numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_energy_actions_r2697 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON team_energy_actions_r2697;
CREATE POLICY founder_all ON team_energy_actions_r2697 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO team_energy_actions_r2697 (team_member, supportive_action, action_category, initiated_by, initiated_at, outcome, outcome_notes, followup_due, followup_status, cost_inr) VALUES
('Aarav Sharma','Mandatory 5-day off + offload on-call to Rohan','time_off','Founder','2026-06-16'::date,'still_in_progress','Started leave, will reassess after rotation',  '2026-06-25'::date,'scheduled', 0),
('Sneha Kulkarni','1:1 with founder + workload audit + Mumbai team backup','1on1','Founder','2026-06-16'::date,'improved','Opened up about commute fatigue, AMC visit count cut 30%','2026-06-22'::date,'pending', 0),
('Ananya Gupta','Therapy stipend approved + flexible hours through July','therapy_stipend','HR','2026-06-15'::date,'stable','Using stipend, hours flexed','2026-07-15'::date,'scheduled', 12000.00),
('Priya Reddy','Public shoutout in all-hands + bonus loaded','recognition','Founder','2026-06-15'::date,'improved','Energy sustained, took on chain rollout v2','2026-09-15'::date,'pending', 25000.00),
('Aarav Sharma','Free up Cursor Pro license + GPU credits for side experiments','tool_help','Founder','2026-06-16'::date,'still_in_progress','Aarav back next week, will use credits then','2026-06-30'::date,'pending', 8000.00),
('Vikram Nair','Quarterly equity refresh ack','recognition','Founder','2026-06-14'::date,'resolved','Acknowledged, signed','2026-09-14'::date,'not_needed', 0);

-- ---------------------------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_kpis_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_kpis_r2697()
RETURNS TABLE (
  total_members int,
  avg_energy numeric,
  red_count int,
  amber_count int,
  green_count int,
  burnout_risk_count int,
  flagged_followup int,
  actions_in_progress int,
  total_support_cost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697),
    (SELECT ROUND(AVG(energy_score)::numeric, 2) FROM team_energy_pulse_r2697),
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697 WHERE morale_color = 'red'),
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697 WHERE morale_color = 'amber'),
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697 WHERE morale_color = 'green'),
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697 WHERE signal = 'burnout_risk'),
    (SELECT COUNT(*)::int FROM team_energy_pulse_r2697 WHERE flagged_for_followup),
    (SELECT COUNT(*)::int FROM team_energy_actions_r2697 WHERE outcome = 'still_in_progress'),
    (SELECT COALESCE(SUM(cost_inr), 0) FROM team_energy_actions_r2697);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_kpis_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_kpis_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: pulse list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_pulses_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_pulses_r2697()
RETURNS TABLE (
  team_member text,
  role text,
  energy_score int,
  signal text,
  morale_color text,
  workload_load int,
  sleep_quality int,
  flagged_for_followup boolean,
  signal_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.team_member, p.role, p.energy_score, p.signal, p.morale_color, p.workload_load, p.sleep_quality, p.flagged_for_followup, p.signal_notes
  FROM team_energy_pulse_r2697 p
  ORDER BY p.energy_score ASC, p.team_member ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_pulses_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_pulses_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: at-risk roster
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_at_risk_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_at_risk_r2697()
RETURNS TABLE (
  team_member text,
  role text,
  energy_score int,
  signal text,
  signal_notes text,
  workload_load int,
  sleep_quality int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.team_member, p.role, p.energy_score, p.signal, p.signal_notes, p.workload_load, p.sleep_quality
  FROM team_energy_pulse_r2697 p
  WHERE p.morale_color IN ('red','amber') OR p.energy_score <= 5
  ORDER BY p.energy_score ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_at_risk_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_at_risk_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: supportive actions list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_actions_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_actions_r2697()
RETURNS TABLE (
  team_member text,
  supportive_action text,
  action_category text,
  initiated_by text,
  initiated_at date,
  outcome text,
  followup_status text,
  cost_inr numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.team_member, a.supportive_action, a.action_category, a.initiated_by, a.initiated_at, a.outcome, a.followup_status, a.cost_inr
  FROM team_energy_actions_r2697 a
  ORDER BY a.initiated_at DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_actions_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_actions_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: outcome breakdown
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_outcomes_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_outcomes_r2697()
RETURNS TABLE (
  outcome text,
  action_count int,
  total_cost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.outcome, COUNT(*)::int, COALESCE(SUM(a.cost_inr), 0)
  FROM team_energy_actions_r2697 a
  GROUP BY a.outcome
  ORDER BY COUNT(*) DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_outcomes_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_outcomes_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: follow-up queue
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_followups_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_followups_r2697()
RETURNS TABLE (
  team_member text,
  supportive_action text,
  followup_due date,
  followup_status text,
  days_until_due int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.team_member, a.supportive_action, a.followup_due, a.followup_status,
    (a.followup_due - CURRENT_DATE)::int
  FROM team_energy_actions_r2697 a
  WHERE a.followup_status IN ('pending','scheduled','overdue') AND a.followup_due IS NOT NULL
  ORDER BY a.followup_due ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_followups_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_followups_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: signal distribution
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_signal_distribution_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_signal_distribution_r2697()
RETURNS TABLE (
  signal text,
  member_count int,
  avg_energy numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.signal, COUNT(*)::int, ROUND(AVG(p.energy_score)::numeric, 2)
  FROM team_energy_pulse_r2697 p
  GROUP BY p.signal
  ORDER BY COUNT(*) DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_signal_distribution_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_signal_distribution_r2697() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: action category breakdown
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_team_energy_action_categories_r2697();
CREATE OR REPLACE FUNCTION founder_team_energy_action_categories_r2697()
RETURNS TABLE (
  action_category text,
  action_count int,
  total_cost numeric,
  resolved_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_category,
    COUNT(*)::int,
    COALESCE(SUM(a.cost_inr), 0),
    COUNT(*) FILTER (WHERE a.outcome IN ('resolved','improved'))::int
  FROM team_energy_actions_r2697 a
  GROUP BY a.action_category
  ORDER BY COUNT(*) DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION founder_team_energy_action_categories_r2697() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_energy_action_categories_r2697() TO authenticated;

COMMIT;
