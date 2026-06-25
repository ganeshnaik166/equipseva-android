BEGIN;

-- ============================================================================
-- Round 2793 — Founder Quarterly Executive Coach Engagement
-- coach × topic × frequency × value × actionable × continue/end decision
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: coach roster
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_exec_coaches_r2793 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_name text NOT NULL,
  coach_firm text NOT NULL,
  specialty text NOT NULL CHECK (specialty IN ('founder_psychology','scaling_ops','board_management','sales_leadership','product_strategy','fundraising')),
  monthly_retainer_rupees bigint NOT NULL CHECK (monthly_retainer_rupees >= 0),
  engagement_start_date date NOT NULL,
  engagement_status text NOT NULL CHECK (engagement_status IN ('active','paused','ended','renewing')),
  total_sessions_held int NOT NULL DEFAULT 0 CHECK (total_sessions_held >= 0),
  founder_rated_value text NOT NULL CHECK (founder_rated_value IN ('exceptional','high','moderate','low','negative')),
  continue_next_quarter boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_exec_coaches_r2793 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_exec_coaches_r2793;
CREATE POLICY founder_all ON founder_exec_coaches_r2793
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_exec_coaches_r2793 (coach_name, coach_firm, specialty, monthly_retainer_rupees, engagement_start_date, engagement_status, total_sessions_held, founder_rated_value, continue_next_quarter, notes) VALUES
  ('Ravi Krishnan', 'Stillpoint Advisors', 'founder_psychology', 12000000, '2026-01-15'::date, 'active', 11, 'exceptional', true, 'Anchor coach — weekly 1:1; saved founder from burnout twice'),
  ('Meena Iyer', 'Scaling Sherpa', 'scaling_ops', 8000000, '2026-02-01'::date, 'active', 9, 'high', true, 'Helped wire founder-priority-actions discipline'),
  ('Anjali Verma', 'BoardCraft', 'board_management', 6000000, '2026-03-10'::date, 'renewing', 6, 'moderate', true, 'Board pack prep + investor narrative; quarterly cadence'),
  ('Suresh Pillai', 'GoToMarket Labs', 'sales_leadership', 10000000, '2026-01-20'::date, 'paused', 7, 'low', false, 'Misaligned with B2B-hospital motion; pausing after Q1'),
  ('Karthik Rao', 'Founder Forge', 'product_strategy', 9500000, '2026-04-05'::date, 'active', 4, 'high', true, 'Sharpened v0.5 → v0.6 phase sequencing'),
  ('Deepa Nair', 'Capital Compass', 'fundraising', 14000000, '2026-05-12'::date, 'active', 3, 'exceptional', true, 'Pre-empts term-sheet traps; Series A prep'),
  ('Vikram Joshi', 'Mindful Founders', 'founder_psychology', 5000000, '2026-02-20'::date, 'ended', 5, 'negative', false, 'Generic mindfulness — not founder-specific; ended');

-- ----------------------------------------------------------------------------
-- Table 2: session log
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_coach_sessions_r2793 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid NOT NULL REFERENCES founder_exec_coaches_r2793(id) ON DELETE CASCADE,
  session_date date NOT NULL,
  topic text NOT NULL CHECK (topic IN ('hiring','firing','board_dynamics','cofounder_conflict','burnout','strategy','fundraise','product','sales','personal')),
  duration_minutes int NOT NULL CHECK (duration_minutes BETWEEN 15 AND 240),
  actionable_count int NOT NULL DEFAULT 0 CHECK (actionable_count >= 0),
  actions_executed int NOT NULL DEFAULT 0 CHECK (actions_executed >= 0),
  founder_rating int NOT NULL CHECK (founder_rating BETWEEN 1 AND 5),
  followup_required boolean NOT NULL DEFAULT false,
  session_summary text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_coach_sessions_r2793 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_coach_sessions_r2793;
CREATE POLICY founder_all ON founder_coach_sessions_r2793
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_coach_sessions_r2793 (coach_id, session_date, topic, duration_minutes, actionable_count, actions_executed, founder_rating, followup_required, session_summary)
SELECT id, '2026-06-18'::date, 'burnout', 60, 4, 4, 5, false, 'Hard reset on weekend protection; phone-off Sundays' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Ravi Krishnan'
UNION ALL
SELECT id, '2026-06-11'::date, 'cofounder_conflict', 90, 6, 5, 5, true, 'Restructured ops/eng split; written RACI in shared doc' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Ravi Krishnan'
UNION ALL
SELECT id, '2026-06-15'::date, 'hiring', 75, 5, 3, 4, true, 'GTM lead spec; rejected 2 candidates as wrong stage' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Meena Iyer'
UNION ALL
SELECT id, '2026-06-20'::date, 'board_dynamics', 60, 3, 3, 4, false, 'Board pack pre-read; pre-empt LP question about runway' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Anjali Verma'
UNION ALL
SELECT id, '2026-04-10'::date, 'sales', 60, 4, 1, 2, true, 'B2C playbooks pitched at B2B-hospital deal; low fit' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Suresh Pillai'
UNION ALL
SELECT id, '2026-06-19'::date, 'product', 90, 7, 6, 5, true, 'v0.6 phase sequencing; killed 2 nice-to-have features' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Karthik Rao'
UNION ALL
SELECT id, '2026-06-17'::date, 'fundraise', 120, 8, 7, 5, true, 'Term-sheet redlines; pro-rata + tag-along clauses' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Deepa Nair'
UNION ALL
SELECT id, '2026-06-05'::date, 'personal', 45, 2, 0, 2, false, 'Generic breathwork; not actionable for founder context' FROM founder_exec_coaches_r2793 WHERE coach_name = 'Vikram Joshi';

-- ============================================================================
-- RPC 1: roster overview
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_coach_roster();
CREATE OR REPLACE FUNCTION founder_r2793_coach_roster()
RETURNS TABLE (
  coach_name text,
  coach_firm text,
  specialty text,
  monthly_retainer_rupees bigint,
  engagement_status text,
  total_sessions_held int,
  founder_rated_value text,
  continue_next_quarter boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.coach_name, c.coach_firm, c.specialty, c.monthly_retainer_rupees,
         c.engagement_status, c.total_sessions_held, c.founder_rated_value, c.continue_next_quarter
  FROM founder_exec_coaches_r2793 c
  ORDER BY c.monthly_retainer_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_coach_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_coach_roster() TO authenticated;

-- ============================================================================
-- RPC 2: spend summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_spend_summary();
CREATE OR REPLACE FUNCTION founder_r2793_spend_summary()
RETURNS TABLE (
  active_coaches int,
  paused_coaches int,
  ended_coaches int,
  monthly_spend_rupees bigint,
  quarterly_spend_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE engagement_status = 'active')::int,
    COUNT(*) FILTER (WHERE engagement_status = 'paused')::int,
    COUNT(*) FILTER (WHERE engagement_status = 'ended')::int,
    COALESCE(SUM(monthly_retainer_rupees) FILTER (WHERE engagement_status IN ('active','renewing')), 0)::bigint,
    (COALESCE(SUM(monthly_retainer_rupees) FILTER (WHERE engagement_status IN ('active','renewing')), 0) * 3)::bigint
  FROM founder_exec_coaches_r2793;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_spend_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_spend_summary() TO authenticated;

-- ============================================================================
-- RPC 3: value distribution
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_value_distribution();
CREATE OR REPLACE FUNCTION founder_r2793_value_distribution()
RETURNS TABLE (
  founder_rated_value text,
  coach_count int,
  monthly_spend_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.founder_rated_value, COUNT(*)::int, COALESCE(SUM(c.monthly_retainer_rupees),0)::bigint
  FROM founder_exec_coaches_r2793 c
  GROUP BY c.founder_rated_value
  ORDER BY CASE c.founder_rated_value
    WHEN 'exceptional' THEN 1
    WHEN 'high' THEN 2
    WHEN 'moderate' THEN 3
    WHEN 'low' THEN 4
    WHEN 'negative' THEN 5
  END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_value_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_value_distribution() TO authenticated;

-- ============================================================================
-- RPC 4: topic frequency
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_topic_frequency();
CREATE OR REPLACE FUNCTION founder_r2793_topic_frequency()
RETURNS TABLE (
  topic text,
  session_count int,
  avg_rating numeric,
  avg_actions_executed numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.topic,
         COUNT(*)::int,
         ROUND(AVG(s.founder_rating)::numeric, 2),
         ROUND(AVG(s.actions_executed)::numeric, 2)
  FROM founder_coach_sessions_r2793 s
  GROUP BY s.topic
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_topic_frequency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_topic_frequency() TO authenticated;

-- ============================================================================
-- RPC 5: recent sessions
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_recent_sessions();
CREATE OR REPLACE FUNCTION founder_r2793_recent_sessions()
RETURNS TABLE (
  session_date date,
  coach_name text,
  topic text,
  duration_minutes int,
  actionable_count int,
  actions_executed int,
  founder_rating int,
  followup_required boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.session_date, c.coach_name, s.topic, s.duration_minutes,
         s.actionable_count, s.actions_executed, s.founder_rating, s.followup_required
  FROM founder_coach_sessions_r2793 s
  JOIN founder_exec_coaches_r2793 c ON c.id = s.coach_id
  ORDER BY s.session_date DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_recent_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_recent_sessions() TO authenticated;

-- ============================================================================
-- RPC 6: continue vs end decisions
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_continue_decisions();
CREATE OR REPLACE FUNCTION founder_r2793_continue_decisions()
RETURNS TABLE (
  coach_name text,
  specialty text,
  founder_rated_value text,
  total_sessions_held int,
  continue_next_quarter boolean,
  decision_rationale text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.coach_name, c.specialty, c.founder_rated_value, c.total_sessions_held, c.continue_next_quarter,
         CASE
           WHEN c.continue_next_quarter AND c.founder_rated_value IN ('exceptional','high') THEN 'high-value retain'
           WHEN c.continue_next_quarter AND c.founder_rated_value = 'moderate' THEN 'retain on probation'
           WHEN NOT c.continue_next_quarter AND c.founder_rated_value IN ('low','negative') THEN 'end — low ROI'
           ELSE 'review'
         END
  FROM founder_exec_coaches_r2793 c
  ORDER BY c.continue_next_quarter DESC, c.founder_rated_value;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_continue_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_continue_decisions() TO authenticated;

-- ============================================================================
-- RPC 7: actionability KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_actionability_kpis();
CREATE OR REPLACE FUNCTION founder_r2793_actionability_kpis()
RETURNS TABLE (
  total_sessions int,
  total_actionables int,
  total_executed int,
  execution_rate_pct numeric,
  avg_rating numeric,
  followups_open int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(actionable_count),0)::int,
    COALESCE(SUM(actions_executed),0)::int,
    CASE WHEN COALESCE(SUM(actionable_count),0) = 0 THEN 0
         ELSE ROUND((SUM(actions_executed)::numeric / SUM(actionable_count)::numeric) * 100, 2)
    END,
    ROUND(AVG(founder_rating)::numeric, 2),
    COUNT(*) FILTER (WHERE followup_required)::int
  FROM founder_coach_sessions_r2793;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_actionability_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_actionability_kpis() TO authenticated;

-- ============================================================================
-- RPC 8: roi per coach
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2793_coach_roi();
CREATE OR REPLACE FUNCTION founder_r2793_coach_roi()
RETURNS TABLE (
  coach_name text,
  sessions_held int,
  avg_rating numeric,
  actions_executed int,
  monthly_retainer_rupees bigint,
  cost_per_executed_action_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.coach_name,
         COUNT(s.id)::int,
         ROUND(COALESCE(AVG(s.founder_rating),0)::numeric, 2),
         COALESCE(SUM(s.actions_executed),0)::int,
         c.monthly_retainer_rupees,
         CASE WHEN COALESCE(SUM(s.actions_executed),0) = 0 THEN c.monthly_retainer_rupees
              ELSE (c.monthly_retainer_rupees / COALESCE(SUM(s.actions_executed),1))::bigint
         END
  FROM founder_exec_coaches_r2793 c
  LEFT JOIN founder_coach_sessions_r2793 s ON s.coach_id = c.id
  GROUP BY c.coach_name, c.monthly_retainer_rupees
  ORDER BY c.monthly_retainer_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2793_coach_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2793_coach_roi() TO authenticated;

COMMIT;
