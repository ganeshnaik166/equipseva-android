BEGIN;

-- =====================================================================
-- Round 2869: Founder Quarterly Strategic Team 1-on-1 Cadence
-- =====================================================================

CREATE TABLE IF NOT EXISTS team_1on1_sessions_r2869 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_member text NOT NULL,
  role text NOT NULL,
  meeting_cadence text NOT NULL CHECK (meeting_cadence IN ('weekly','biweekly','monthly','quarterly')),
  depth_level text NOT NULL CHECK (depth_level IN ('shallow','standard','deep','strategic')),
  topic text NOT NULL,
  commitment text NOT NULL,
  outcome text NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('on_track','at_risk','blocked','exceeded','escalate')),
  session_date date NOT NULL,
  duration_minutes int NOT NULL CHECK (duration_minutes > 0),
  next_session_date date,
  founder_rating int NOT NULL CHECK (founder_rating BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS team_1on1_commitments_r2869 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES team_1on1_sessions_r2869(id) ON DELETE CASCADE,
  team_member text NOT NULL,
  commitment_text text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','in_progress','completed','missed','deferred')),
  impact_area text NOT NULL CHECK (impact_area IN ('revenue','product','team','ops','customer','strategy')),
  completion_percent int NOT NULL CHECK (completion_percent BETWEEN 0 AND 100),
  blocker text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_1on1_sessions_r2869 ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_1on1_commitments_r2869 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON team_1on1_sessions_r2869;
CREATE POLICY founder_all ON team_1on1_sessions_r2869
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON team_1on1_commitments_r2869;
CREATE POLICY founder_all ON team_1on1_commitments_r2869
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================================
-- Seeds
-- =====================================================================

INSERT INTO team_1on1_sessions_r2869
  (team_member, role, meeting_cadence, depth_level, topic, commitment, outcome, verdict, session_date, duration_minutes, next_session_date, founder_rating)
VALUES
  ('Priya Nair','Head of Ops','weekly','deep','Q3 SLA breach on dental cluster','Hire 2 regional supervisors by week 6','Hired 1 + 1 offer out','on_track','2026-06-15'::date,60,'2026-06-22'::date,4),
  ('Rohan Mehta','VP Engineering','biweekly','strategic','AMC churn model v2 launch','Ship v2 with regression delta less than 5 percent','Shipped at 3.2 percent delta','exceeded','2026-06-12'::date,75,'2026-06-26'::date,5),
  ('Aisha Khan','Head of Sales','weekly','standard','Pipeline coverage gap Q3','Add 12 hospital chain leads','7 of 12 added','at_risk','2026-06-14'::date,45,'2026-06-21'::date,3),
  ('Vikram Joshi','CFO','monthly','strategic','Series A bridge round close','Term sheet by month-end','Two LOIs in hand','on_track','2026-06-10'::date,90,'2026-07-10'::date,4),
  ('Sneha Reddy','Head of Customer Success','biweekly','deep','Tier-1 hospital expansion blocked on compliance','Resolve DPDP review with 3 hospitals','1 resolved, 2 escalated','blocked','2026-06-13'::date,50,'2026-06-27'::date,2),
  ('Arjun Patel','Head of Engineer Network','quarterly','strategic','Engineer attrition spike north zone','Retention bonus rollout by Q3','Pilot ran with 8 engineers','escalate','2026-06-08'::date,120,'2026-09-08'::date,2);

INSERT INTO team_1on1_commitments_r2869
  (team_member, commitment_text, due_date, status, impact_area, completion_percent, blocker)
VALUES
  ('Priya Nair','Onboard 2 regional supervisors',  '2026-07-15'::date, 'in_progress', 'ops',      50, NULL),
  ('Rohan Mehta','Ship AMC churn model v2 to prod','2026-06-20'::date, 'completed',  'product',  100, NULL),
  ('Aisha Khan','Add 12 hospital chain leads to CRM','2026-07-01'::date, 'in_progress', 'revenue', 58, 'Procurement contacts not responding'),
  ('Vikram Joshi','Close bridge round term sheet','2026-06-30'::date, 'in_progress', 'strategy', 65, NULL),
  ('Sneha Reddy','Clear DPDP review for 3 hospitals','2026-06-25'::date, 'missed', 'customer', 33, 'Legal review backlog at hospital side'),
  ('Arjun Patel','Roll out engineer retention bonus','2026-08-15'::date, 'deferred', 'team', 20, 'Cash burn ceiling pending CFO approval');

-- =====================================================================
-- RPCs
-- =====================================================================

DROP FUNCTION IF EXISTS founder_r2869_session_overview();
CREATE FUNCTION founder_r2869_session_overview()
RETURNS TABLE(total_sessions bigint, avg_rating numeric, on_track bigint, at_risk bigint, blocked bigint, escalate bigint, exceeded bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    round(avg(founder_rating)::numeric, 2),
    count(*) FILTER (WHERE verdict='on_track')::bigint,
    count(*) FILTER (WHERE verdict='at_risk')::bigint,
    count(*) FILTER (WHERE verdict='blocked')::bigint,
    count(*) FILTER (WHERE verdict='escalate')::bigint,
    count(*) FILTER (WHERE verdict='exceeded')::bigint
  FROM team_1on1_sessions_r2869;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_session_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_session_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_recent_sessions();
CREATE FUNCTION founder_r2869_recent_sessions()
RETURNS SETOF team_1on1_sessions_r2869
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM team_1on1_sessions_r2869 ORDER BY session_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_recent_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_recent_sessions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_cadence_breakdown();
CREATE FUNCTION founder_r2869_cadence_breakdown()
RETURNS TABLE(meeting_cadence text, sessions bigint, avg_rating numeric, escalations bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.meeting_cadence,
         count(*)::bigint,
         round(avg(s.founder_rating)::numeric, 2),
         count(*) FILTER (WHERE s.verdict IN ('escalate','blocked'))::bigint
  FROM team_1on1_sessions_r2869 s
  GROUP BY s.meeting_cadence
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_cadence_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_cadence_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_commitment_overview();
CREATE FUNCTION founder_r2869_commitment_overview()
RETURNS TABLE(total bigint, completed bigint, in_progress bigint, missed bigint, deferred bigint, pending bigint, avg_completion numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         count(*) FILTER (WHERE status='completed')::bigint,
         count(*) FILTER (WHERE status='in_progress')::bigint,
         count(*) FILTER (WHERE status='missed')::bigint,
         count(*) FILTER (WHERE status='deferred')::bigint,
         count(*) FILTER (WHERE status='pending')::bigint,
         round(avg(completion_percent)::numeric, 1)
  FROM team_1on1_commitments_r2869;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_commitment_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_commitment_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_commitments_at_risk();
CREATE FUNCTION founder_r2869_commitments_at_risk()
RETURNS SETOF team_1on1_commitments_r2869
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM team_1on1_commitments_r2869
  WHERE status IN ('missed','deferred','in_progress')
  ORDER BY due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_commitments_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_commitments_at_risk() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_impact_area_breakdown();
CREATE FUNCTION founder_r2869_impact_area_breakdown()
RETURNS TABLE(impact_area text, count bigint, avg_completion numeric, missed bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.impact_area,
         count(*)::bigint,
         round(avg(c.completion_percent)::numeric, 1),
         count(*) FILTER (WHERE c.status='missed')::bigint
  FROM team_1on1_commitments_r2869 c
  GROUP BY c.impact_area
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_impact_area_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_impact_area_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_member_scorecard();
CREATE FUNCTION founder_r2869_member_scorecard()
RETURNS TABLE(team_member text, sessions bigint, avg_rating numeric, commitments bigint, completed bigint, completion_rate numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_member,
         count(DISTINCT s.id)::bigint,
         round(avg(s.founder_rating)::numeric, 2),
         count(c.id)::bigint,
         count(c.id) FILTER (WHERE c.status='completed')::bigint,
         CASE WHEN count(c.id) > 0
              THEN round((count(c.id) FILTER (WHERE c.status='completed')::numeric * 100.0) / count(c.id)::numeric, 1)
              ELSE 0 END
  FROM team_1on1_sessions_r2869 s
  LEFT JOIN team_1on1_commitments_r2869 c ON c.team_member = s.team_member
  GROUP BY s.team_member
  ORDER BY avg_rating DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_member_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_member_scorecard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2869_upcoming_sessions();
CREATE FUNCTION founder_r2869_upcoming_sessions()
RETURNS TABLE(team_member text, role text, meeting_cadence text, next_session_date date, last_verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.team_member, s.role, s.meeting_cadence, s.next_session_date, s.verdict
  FROM team_1on1_sessions_r2869 s
  WHERE s.next_session_date IS NOT NULL
  ORDER BY s.next_session_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2869_upcoming_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2869_upcoming_sessions() TO authenticated;

COMMIT;
