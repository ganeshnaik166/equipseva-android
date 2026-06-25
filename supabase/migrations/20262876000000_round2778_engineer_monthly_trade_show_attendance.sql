BEGIN;

-- ============================================================================
-- Round 2778 — Engineer Monthly Trade Show Attendance
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_trade_show_attendance_r2778 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  show_name text NOT NULL,
  show_city text NOT NULL,
  attended_on date NOT NULL,
  booth_hours numeric(6,2) NOT NULL,
  goal_leads int NOT NULL,
  actual_leads int NOT NULL,
  demos_given int NOT NULL,
  qualified_leads int NOT NULL,
  learning_score int NOT NULL CHECK (learning_score BETWEEN 1 AND 10),
  travel_cost_rupees int NOT NULL,
  booth_cost_rupees int NOT NULL,
  pipeline_value_rupees bigint NOT NULL,
  roi_verdict text NOT NULL CHECK (roi_verdict IN ('excellent','positive','breakeven','negative','disaster')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_trade_show_attendance_r2778 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_trade_show_attendance_r2778;
CREATE POLICY founder_all ON engineer_trade_show_attendance_r2778
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_trade_show_lead_followup_r2778 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES engineer_trade_show_attendance_r2778(id) ON DELETE CASCADE,
  lead_hospital text NOT NULL,
  lead_contact text NOT NULL,
  followup_stage text NOT NULL CHECK (followup_stage IN ('new','contacted','demo_scheduled','quote_sent','won','lost')),
  expected_value_rupees int NOT NULL,
  followup_due date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_trade_show_lead_followup_r2778 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_trade_show_lead_followup_r2778;
CREATE POLICY founder_all ON engineer_trade_show_lead_followup_r2778
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================

INSERT INTO engineer_trade_show_attendance_r2778
  (engineer_name, show_name, show_city, attended_on, booth_hours, goal_leads, actual_leads, demos_given, qualified_leads, learning_score, travel_cost_rupees, booth_cost_rupees, pipeline_value_rupees, roi_verdict)
VALUES
  ('Ravi Kumar',     'MedicAll 2026',          'Chennai',   '2026-05-12'::date, 32.0, 40, 56, 22, 18,  9,  18000,  85000, 4200000, 'excellent'),
  ('Anita Sharma',   'India Health Expo',      'Mumbai',    '2026-05-19'::date, 28.5, 35, 31, 14, 12,  8,  22000,  90000, 1800000, 'positive'),
  ('Sundar Iyer',    'Hospitech South',        'Bengaluru', '2026-05-22'::date, 24.0, 30, 18,  7,  5,  6,  12000,  60000,  600000, 'breakeven'),
  ('Priya Reddy',    'AMTZ Visakha Med',       'Vizag',     '2026-05-26'::date, 18.0, 25,  9,  3,  2,  4,  16000,  72000,  150000, 'negative'),
  ('Mohan Verma',    'CardioCon 2026',         'Delhi',     '2026-05-29'::date, 30.0, 45, 12,  4,  1,  3,  28000, 110000,   80000, 'disaster'),
  ('Lakshmi Pillai', 'Hyderabad Hospital Mgmt','Hyderabad', '2026-05-30'::date, 26.0, 38, 44, 19, 15,  9,  10000,  68000, 3100000, 'excellent');

INSERT INTO engineer_trade_show_lead_followup_r2778
  (attendance_id, lead_hospital, lead_contact, followup_stage, expected_value_rupees, followup_due, notes)
SELECT id, 'Apollo Hospitals',     'biomed@apollo.in',     'demo_scheduled', 850000, '2026-06-30'::date, 'CT scanner AMC interest'    FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Ravi Kumar'
UNION ALL
SELECT id, 'Fortis Healthcare',    'maint@fortis.in',      'quote_sent',     620000, '2026-07-02'::date, 'MRI quarterly AMC'          FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Ravi Kumar'
UNION ALL
SELECT id, 'Kokilaben Hospital',   'tech@kokilaben.in',    'contacted',      410000, '2026-07-05'::date, 'Ventilator repair pool'     FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Anita Sharma'
UNION ALL
SELECT id, 'Manipal Hospitals',    'ops@manipal.in',       'won',            980000, '2026-06-28'::date, 'Signed 12-mo AMC'           FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Lakshmi Pillai'
UNION ALL
SELECT id, 'AIIMS Delhi',          'biomed@aiims.edu',     'lost',           220000, '2026-06-15'::date, 'Procurement froze budget'   FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Mohan Verma'
UNION ALL
SELECT id, 'Narayana Health',      'amc@narayana.in',      'new',            340000, '2026-07-10'::date, 'Met booth Day 2'            FROM engineer_trade_show_attendance_r2778 WHERE engineer_name = 'Sundar Iyer';

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_kpis();
CREATE OR REPLACE FUNCTION r2778_trade_show_kpis()
RETURNS TABLE (
  total_shows int,
  total_leads bigint,
  total_qualified bigint,
  total_pipeline_rupees bigint,
  total_spend_rupees bigint,
  roi_multiple numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::int,
      COALESCE(SUM(actual_leads),0)::bigint,
      COALESCE(SUM(qualified_leads),0)::bigint,
      COALESCE(SUM(pipeline_value_rupees),0)::bigint,
      COALESCE(SUM(travel_cost_rupees + booth_cost_rupees),0)::bigint,
      CASE WHEN COALESCE(SUM(travel_cost_rupees + booth_cost_rupees),0) = 0 THEN 0
           ELSE ROUND(SUM(pipeline_value_rupees)::numeric / NULLIF(SUM(travel_cost_rupees + booth_cost_rupees),0), 2)
      END
    FROM engineer_trade_show_attendance_r2778;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: list all attendance rows
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_attendance_list();
CREATE OR REPLACE FUNCTION r2778_trade_show_attendance_list()
RETURNS SETOF engineer_trade_show_attendance_r2778
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_trade_show_attendance_r2778 ORDER BY attended_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_attendance_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_attendance_list() TO authenticated;

-- ============================================================================
-- RPC 3: ROI verdict breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_verdict_breakdown();
CREATE OR REPLACE FUNCTION r2778_trade_show_verdict_breakdown()
RETURNS TABLE (verdict text, show_count int, pipeline_rupees bigint, spend_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT roi_verdict,
           COUNT(*)::int,
           COALESCE(SUM(pipeline_value_rupees),0)::bigint,
           COALESCE(SUM(travel_cost_rupees + booth_cost_rupees),0)::bigint
    FROM engineer_trade_show_attendance_r2778
    GROUP BY roi_verdict
    ORDER BY pipeline_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_verdict_breakdown() TO authenticated;

-- ============================================================================
-- RPC 4: engineer leaderboard
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_engineer_leaderboard();
CREATE OR REPLACE FUNCTION r2778_trade_show_engineer_leaderboard()
RETURNS TABLE (
  engineer_name text,
  shows_attended int,
  total_leads bigint,
  qualified_leads bigint,
  pipeline_rupees bigint,
  avg_learning_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.engineer_name,
           COUNT(*)::int,
           COALESCE(SUM(a.actual_leads),0)::bigint,
           COALESCE(SUM(a.qualified_leads),0)::bigint,
           COALESCE(SUM(a.pipeline_value_rupees),0)::bigint,
           ROUND(AVG(a.learning_score)::numeric, 2)
    FROM engineer_trade_show_attendance_r2778 a
    GROUP BY a.engineer_name
    ORDER BY pipeline_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_engineer_leaderboard() TO authenticated;

-- ============================================================================
-- RPC 5: goal vs actual lead gap
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_goal_gap();
CREATE OR REPLACE FUNCTION r2778_trade_show_goal_gap()
RETURNS TABLE (show_name text, engineer_name text, goal_leads int, actual_leads int, gap int, hit_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.show_name, a.engineer_name, a.goal_leads, a.actual_leads,
           (a.actual_leads - a.goal_leads)::int,
           ROUND((a.actual_leads::numeric / NULLIF(a.goal_leads,0)) * 100, 1)
    FROM engineer_trade_show_attendance_r2778 a
    ORDER BY gap ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_goal_gap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_goal_gap() TO authenticated;

-- ============================================================================
-- RPC 6: open followups
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_open_followups();
CREATE OR REPLACE FUNCTION r2778_trade_show_open_followups()
RETURNS TABLE (
  lead_hospital text,
  lead_contact text,
  followup_stage text,
  expected_value_rupees int,
  followup_due date,
  engineer_name text,
  show_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.lead_hospital, f.lead_contact, f.followup_stage, f.expected_value_rupees, f.followup_due,
           a.engineer_name, a.show_name
    FROM engineer_trade_show_lead_followup_r2778 f
    JOIN engineer_trade_show_attendance_r2778 a ON a.id = f.attendance_id
    WHERE f.followup_stage NOT IN ('won','lost')
    ORDER BY f.followup_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_open_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_open_followups() TO authenticated;

-- ============================================================================
-- RPC 7: pipeline funnel by stage
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_funnel();
CREATE OR REPLACE FUNCTION r2778_trade_show_funnel()
RETURNS TABLE (followup_stage text, lead_count int, expected_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.followup_stage,
           COUNT(*)::int,
           COALESCE(SUM(f.expected_value_rupees),0)::bigint
    FROM engineer_trade_show_lead_followup_r2778 f
    GROUP BY f.followup_stage
    ORDER BY expected_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_funnel() TO authenticated;

-- ============================================================================
-- RPC 8: learning score insights
-- ============================================================================
DROP FUNCTION IF EXISTS r2778_trade_show_learning_insights();
CREATE OR REPLACE FUNCTION r2778_trade_show_learning_insights()
RETURNS TABLE (
  show_name text,
  engineer_name text,
  learning_score int,
  booth_hours numeric,
  cost_per_qualified_lead numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.show_name, a.engineer_name, a.learning_score, a.booth_hours,
           CASE WHEN a.qualified_leads = 0 THEN NULL
                ELSE ROUND(((a.travel_cost_rupees + a.booth_cost_rupees)::numeric / a.qualified_leads), 0)
           END
    FROM engineer_trade_show_attendance_r2778 a
    ORDER BY a.learning_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2778_trade_show_learning_insights() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2778_trade_show_learning_insights() TO authenticated;

COMMIT;
