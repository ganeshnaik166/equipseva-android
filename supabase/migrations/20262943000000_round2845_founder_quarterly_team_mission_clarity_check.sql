BEGIN;

DROP TABLE IF EXISTS team_mission_clarity_signals_r2845 CASCADE;
DROP TABLE IF EXISTS team_mission_clarity_checks_r2845 CASCADE;

CREATE TABLE team_mission_clarity_checks_r2845 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  team_member text NOT NULL,
  role text NOT NULL,
  mission_alignment text NOT NULL CHECK (mission_alignment IN ('strong','moderate','weak','off_mission')),
  clarity_score numeric(3,1) NOT NULL CHECK (clarity_score >= 0 AND clarity_score <= 10),
  refocus_action text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('aligned','refocused','transitioning','exited')),
  checked_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_mission_clarity_checks_r2845 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON team_mission_clarity_checks_r2845 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE team_mission_clarity_signals_r2845 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_id uuid NOT NULL REFERENCES team_mission_clarity_checks_r2845(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('positive','neutral','warning','critical')),
  signal_description text NOT NULL,
  signal_weight numeric(3,1) NOT NULL CHECK (signal_weight >= 0 AND signal_weight <= 10),
  observed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_mission_clarity_signals_r2845 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON team_mission_clarity_signals_r2845 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO team_mission_clarity_checks_r2845 (quarter, team_member, role, mission_alignment, clarity_score, refocus_action, outcome, checked_at) VALUES
  ('Q2-2026','Priya Sharma','Head of Engineering','strong',9.2,'Continue current trajectory, expand ownership','aligned','2026-06-15 10:00:00+05:30'::timestamptz),
  ('Q2-2026','Rahul Verma','Field Ops Lead','moderate',7.0,'1:1 weekly to re-anchor on AMC retention metric','refocused','2026-06-16 11:30:00+05:30'::timestamptz),
  ('Q2-2026','Anjali Mehta','Marketing Lead','weak',5.4,'Move from brand to demand gen for next 60 days','refocused','2026-06-17 09:15:00+05:30'::timestamptz),
  ('Q2-2026','Vikram Singh','BD Manager','off_mission',3.1,'Performance plan; hospital chain focus required','transitioning','2026-06-18 14:45:00+05:30'::timestamptz),
  ('Q2-2026','Sneha Iyer','Product Designer','strong',8.8,'Lead UI v2 shared layer redesign through Q3','aligned','2026-06-19 16:20:00+05:30'::timestamptz),
  ('Q2-2026','Karthik Reddy','Customer Success','moderate',6.7,'Rotate to escalations desk for 30 days','refocused','2026-06-20 10:00:00+05:30'::timestamptz),
  ('Q2-2026','Deepa Nair','Finance Controller','strong',9.0,'Quarterly board pack ownership','aligned','2026-06-21 09:00:00+05:30'::timestamptz);

INSERT INTO team_mission_clarity_signals_r2845 (check_id, signal_type, signal_description, signal_weight, observed_at)
SELECT id, 'positive', 'Initiated cross-team unblock without prompt', 8.5, '2026-06-15 12:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Priya Sharma'
UNION ALL
SELECT id, 'warning', 'Missed two AMC retention reviews', 6.0, '2026-06-16 13:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Rahul Verma'
UNION ALL
SELECT id, 'critical', 'Promoted brand campaign over demand pipeline', 7.5, '2026-06-17 10:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Anjali Mehta'
UNION ALL
SELECT id, 'critical', 'Pursued SMB deals outside ICP', 9.0, '2026-06-18 15:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Vikram Singh'
UNION ALL
SELECT id, 'positive', 'Shipped 12 component redesigns in 2 weeks', 9.2, '2026-06-19 17:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Sneha Iyer'
UNION ALL
SELECT id, 'neutral', 'Steady CSAT but no proactive escalation handling', 5.5, '2026-06-20 11:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Karthik Reddy'
UNION ALL
SELECT id, 'positive', 'Closed Q1 board pack on time with zero rework', 8.7, '2026-06-21 10:00:00+05:30'::timestamptz FROM team_mission_clarity_checks_r2845 WHERE team_member='Deepa Nair';

DROP FUNCTION IF EXISTS founder_team_mission_clarity_overview_r2845();
CREATE FUNCTION founder_team_mission_clarity_overview_r2845()
RETURNS TABLE(total_members int, avg_clarity numeric, strong_count int, off_mission_count int, refocused_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         ROUND(AVG(clarity_score)::numeric, 2),
         COUNT(*) FILTER (WHERE mission_alignment='strong')::int,
         COUNT(*) FILTER (WHERE mission_alignment='off_mission')::int,
         COUNT(*) FILTER (WHERE outcome='refocused')::int
  FROM team_mission_clarity_checks_r2845;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_overview_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_overview_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_list_r2845();
CREATE FUNCTION founder_team_mission_clarity_list_r2845()
RETURNS SETOF team_mission_clarity_checks_r2845
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM team_mission_clarity_checks_r2845 ORDER BY clarity_score DESC, team_member;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_list_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_list_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_by_alignment_r2845();
CREATE FUNCTION founder_team_mission_clarity_by_alignment_r2845()
RETURNS TABLE(mission_alignment text, member_count int, avg_clarity numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.mission_alignment, COUNT(*)::int, ROUND(AVG(c.clarity_score)::numeric, 2)
  FROM team_mission_clarity_checks_r2845 c
  GROUP BY c.mission_alignment
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_by_alignment_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_by_alignment_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_signals_r2845();
CREATE FUNCTION founder_team_mission_clarity_signals_r2845()
RETURNS TABLE(team_member text, signal_type text, signal_description text, signal_weight numeric, observed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.team_member, s.signal_type, s.signal_description, s.signal_weight, s.observed_at
  FROM team_mission_clarity_signals_r2845 s
  JOIN team_mission_clarity_checks_r2845 c ON c.id = s.check_id
  ORDER BY s.signal_weight DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_signals_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_signals_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_outcomes_r2845();
CREATE FUNCTION founder_team_mission_clarity_outcomes_r2845()
RETURNS TABLE(outcome text, member_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.outcome, COUNT(*)::int
  FROM team_mission_clarity_checks_r2845 c
  GROUP BY c.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_outcomes_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_outcomes_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_refocus_actions_r2845();
CREATE FUNCTION founder_team_mission_clarity_refocus_actions_r2845()
RETURNS TABLE(team_member text, role text, clarity_score numeric, refocus_action text, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.team_member, c.role, c.clarity_score, c.refocus_action, c.outcome
  FROM team_mission_clarity_checks_r2845 c
  WHERE c.outcome IN ('refocused','transitioning')
  ORDER BY c.clarity_score;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_refocus_actions_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_refocus_actions_r2845() TO authenticated;

DROP FUNCTION IF EXISTS founder_team_mission_clarity_critical_signals_r2845();
CREATE FUNCTION founder_team_mission_clarity_critical_signals_r2845()
RETURNS TABLE(team_member text, role text, signal_description text, signal_weight numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.team_member, c.role, s.signal_description, s.signal_weight
  FROM team_mission_clarity_signals_r2845 s
  JOIN team_mission_clarity_checks_r2845 c ON c.id = s.check_id
  WHERE s.signal_type IN ('critical','warning')
  ORDER BY s.signal_weight DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_team_mission_clarity_critical_signals_r2845() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_mission_clarity_critical_signals_r2845() TO authenticated;

COMMIT;
