BEGIN;

-- Round 2729: Founder monthly cofounder energy alignment
-- Tables: cofounder energy topics + alignment resolutions

CREATE TABLE IF NOT EXISTS cofounder_energy_topics_r2729 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  cofounder_name text NOT NULL,
  topic text NOT NULL,
  founder_position text NOT NULL,
  cofounder_position text NOT NULL,
  delta_score int NOT NULL CHECK (delta_score BETWEEN 0 AND 100),
  energy_level text NOT NULL CHECK (energy_level IN ('low','medium','high','critical')),
  status text NOT NULL CHECK (status IN ('open','discussing','resolved','escalated')),
  bond_score int NOT NULL CHECK (bond_score BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cofounder_energy_topics_r2729 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cofounder_energy_topics_r2729;
CREATE POLICY founder_all ON cofounder_energy_topics_r2729 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS cofounder_alignment_resolutions_r2729 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id uuid REFERENCES cofounder_energy_topics_r2729(id) ON DELETE CASCADE,
  resolution_date date NOT NULL,
  resolution_path text NOT NULL,
  follow_up_action text NOT NULL,
  follow_up_due date NOT NULL,
  follow_up_status text NOT NULL CHECK (follow_up_status IN ('pending','in_progress','done','blocked')),
  bond_delta int NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('aligned','partial','stalled','rupture')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cofounder_alignment_resolutions_r2729 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cofounder_alignment_resolutions_r2729;
CREATE POLICY founder_all ON cofounder_alignment_resolutions_r2729 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: topics
INSERT INTO cofounder_energy_topics_r2729 (cycle_month, cofounder_name, topic, founder_position, cofounder_position, delta_score, energy_level, status, bond_score, notes) VALUES
  ('2026-06-01'::date, 'Rajesh K', 'Hiring pace next quarter', 'Hire 6 engineers fast', 'Hire 3 senior only', 72, 'high', 'discussing', 78, 'Speed vs quality debate'),
  ('2026-06-01'::date, 'Priya S', 'Hospital chain pricing', 'Discount up to 22 percent', 'Cap at 15 percent', 45, 'medium', 'open', 82, 'Margin protection concern'),
  ('2026-06-01'::date, 'Amit V', 'Series A timing', 'Raise in Q3', 'Raise in Q4 after metrics', 60, 'high', 'escalated', 70, 'Runway anxiety'),
  ('2026-06-01'::date, 'Rajesh K', 'Engineer payout tiers', 'Move to weekly cycle', 'Keep bi-weekly', 30, 'low', 'resolved', 85, 'Cashflow neutral move'),
  ('2026-06-01'::date, 'Priya S', 'Founder ops hours', 'Cut to 8 hours daily', 'Push 12 hours through pilot', 55, 'critical', 'discussing', 68, 'Burnout signal');

-- Seeds: resolutions
INSERT INTO cofounder_alignment_resolutions_r2729 (topic_id, resolution_date, resolution_path, follow_up_action, follow_up_due, follow_up_status, bond_delta, outcome)
SELECT id, '2026-06-22'::date, 'Split the difference at 4 hires', 'Confirm budget with CFO', '2026-07-05'::date, 'in_progress', 4, 'partial' FROM cofounder_energy_topics_r2729 WHERE topic = 'Hiring pace next quarter' LIMIT 1;

INSERT INTO cofounder_alignment_resolutions_r2729 (topic_id, resolution_date, resolution_path, follow_up_action, follow_up_due, follow_up_status, bond_delta, outcome)
SELECT id, '2026-06-23'::date, 'Tier-based discount matrix', 'Draft pricing memo', '2026-07-10'::date, 'pending', 2, 'aligned' FROM cofounder_energy_topics_r2729 WHERE topic = 'Hospital chain pricing' LIMIT 1;

INSERT INTO cofounder_alignment_resolutions_r2729 (topic_id, resolution_date, resolution_path, follow_up_action, follow_up_due, follow_up_status, bond_delta, outcome)
SELECT id, '2026-06-20'::date, 'Bring in board advisor for tie-break', 'Schedule advisor call', '2026-07-01'::date, 'blocked', -3, 'stalled' FROM cofounder_energy_topics_r2729 WHERE topic = 'Series A timing' LIMIT 1;

INSERT INTO cofounder_alignment_resolutions_r2729 (topic_id, resolution_date, resolution_path, follow_up_action, follow_up_due, follow_up_status, bond_delta, outcome)
SELECT id, '2026-06-15'::date, 'Accepted bi-weekly with mid-cycle relief', 'Set up partial-payout cron', '2026-06-30'::date, 'done', 6, 'aligned' FROM cofounder_energy_topics_r2729 WHERE topic = 'Engineer payout tiers' LIMIT 1;

INSERT INTO cofounder_alignment_resolutions_r2729 (topic_id, resolution_date, resolution_path, follow_up_action, follow_up_due, follow_up_status, bond_delta, outcome)
SELECT id, '2026-06-24'::date, 'Trial 10-hour cap for 2 weeks', 'Weekly energy check-in', '2026-07-08'::date, 'in_progress', 5, 'partial' FROM cofounder_energy_topics_r2729 WHERE topic = 'Founder ops hours' LIMIT 1;

-- RPCs
DROP FUNCTION IF EXISTS r2729_topics_overview();
CREATE OR REPLACE FUNCTION r2729_topics_overview()
RETURNS TABLE(total_topics int, open_topics int, resolved_topics int, escalated_topics int, avg_delta numeric, avg_bond numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'open')::int,
    COUNT(*) FILTER (WHERE status = 'resolved')::int,
    COUNT(*) FILTER (WHERE status = 'escalated')::int,
    ROUND(AVG(delta_score)::numeric, 2),
    ROUND(AVG(bond_score)::numeric, 2)
  FROM cofounder_energy_topics_r2729;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_topics_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_topics_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2729_topics_list();
CREATE OR REPLACE FUNCTION r2729_topics_list()
RETURNS TABLE(id uuid, cofounder_name text, topic text, founder_position text, cofounder_position text, delta_score int, energy_level text, status text, bond_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.cofounder_name, t.topic, t.founder_position, t.cofounder_position, t.delta_score, t.energy_level, t.status, t.bond_score
  FROM cofounder_energy_topics_r2729 t
  ORDER BY t.delta_score DESC, t.cycle_month DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_topics_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_topics_list() TO authenticated;

DROP FUNCTION IF EXISTS r2729_resolutions_list();
CREATE OR REPLACE FUNCTION r2729_resolutions_list()
RETURNS TABLE(id uuid, topic text, cofounder_name text, resolution_date date, resolution_path text, follow_up_action text, follow_up_due date, follow_up_status text, bond_delta int, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, t.topic, t.cofounder_name, r.resolution_date, r.resolution_path, r.follow_up_action, r.follow_up_due, r.follow_up_status, r.bond_delta, r.outcome
  FROM cofounder_alignment_resolutions_r2729 r
  JOIN cofounder_energy_topics_r2729 t ON t.id = r.topic_id
  ORDER BY r.resolution_date DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_resolutions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_resolutions_list() TO authenticated;

DROP FUNCTION IF EXISTS r2729_energy_breakdown();
CREATE OR REPLACE FUNCTION r2729_energy_breakdown()
RETURNS TABLE(energy_level text, topic_count int, avg_delta numeric, avg_bond numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.energy_level, COUNT(*)::int, ROUND(AVG(t.delta_score)::numeric, 2), ROUND(AVG(t.bond_score)::numeric, 2)
  FROM cofounder_energy_topics_r2729 t
  GROUP BY t.energy_level
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_energy_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_energy_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2729_cofounder_bond_summary();
CREATE OR REPLACE FUNCTION r2729_cofounder_bond_summary()
RETURNS TABLE(cofounder_name text, topics_count int, avg_bond numeric, total_bond_delta int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.cofounder_name, COUNT(t.id)::int, ROUND(AVG(t.bond_score)::numeric, 2), COALESCE(SUM(r.bond_delta), 0)::int
  FROM cofounder_energy_topics_r2729 t
  LEFT JOIN cofounder_alignment_resolutions_r2729 r ON r.topic_id = t.id
  GROUP BY t.cofounder_name
  ORDER BY AVG(t.bond_score) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_cofounder_bond_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_cofounder_bond_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2729_follow_ups_pending();
CREATE OR REPLACE FUNCTION r2729_follow_ups_pending()
RETURNS TABLE(topic text, cofounder_name text, follow_up_action text, follow_up_due date, follow_up_status text, days_to_due int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic, t.cofounder_name, r.follow_up_action, r.follow_up_due, r.follow_up_status,
         (r.follow_up_due - CURRENT_DATE)::int
  FROM cofounder_alignment_resolutions_r2729 r
  JOIN cofounder_energy_topics_r2729 t ON t.id = r.topic_id
  WHERE r.follow_up_status IN ('pending','in_progress','blocked')
  ORDER BY r.follow_up_due ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_follow_ups_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_follow_ups_pending() TO authenticated;

DROP FUNCTION IF EXISTS r2729_outcome_breakdown();
CREATE OR REPLACE FUNCTION r2729_outcome_breakdown()
RETURNS TABLE(outcome text, resolution_count int, avg_bond_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.outcome, COUNT(*)::int, ROUND(AVG(r.bond_delta)::numeric, 2)
  FROM cofounder_alignment_resolutions_r2729 r
  GROUP BY r.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_outcome_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2729_critical_topics();
CREATE OR REPLACE FUNCTION r2729_critical_topics()
RETURNS TABLE(cofounder_name text, topic text, delta_score int, bond_score int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.cofounder_name, t.topic, t.delta_score, t.bond_score, t.status
  FROM cofounder_energy_topics_r2729 t
  WHERE t.energy_level IN ('high','critical') OR t.delta_score >= 60
  ORDER BY t.delta_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2729_critical_topics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2729_critical_topics() TO authenticated;

COMMIT;
