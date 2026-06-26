BEGIN;

-- =====================================================================
-- Round 2857: Quarterly Strategic Board Meeting Minutes Tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS board_meetings_r2857 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_code text NOT NULL UNIQUE,
  quarter_label text NOT NULL,
  meeting_date date NOT NULL,
  location text NOT NULL,
  chair_name text NOT NULL,
  attendees_count int NOT NULL CHECK (attendees_count >= 0),
  quorum_met boolean NOT NULL DEFAULT true,
  status text NOT NULL CHECK (status IN ('scheduled','in_progress','concluded','minutes_circulated','minutes_ratified')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS board_action_items_r2857 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES board_meetings_r2857(id) ON DELETE CASCADE,
  topic text NOT NULL,
  decision text NOT NULL,
  action_item text NOT NULL,
  owner_name text NOT NULL,
  due_date date NOT NULL,
  done boolean NOT NULL DEFAULT false,
  done_at timestamptz,
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_notes text,
  priority text NOT NULL CHECK (priority IN ('low','medium','high','critical')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE board_meetings_r2857 ENABLE ROW LEVEL SECURITY;
ALTER TABLE board_action_items_r2857 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON board_meetings_r2857;
CREATE POLICY founder_all ON board_meetings_r2857 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON board_action_items_r2857;
CREATE POLICY founder_all ON board_action_items_r2857 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed meetings
INSERT INTO board_meetings_r2857 (meeting_code, quarter_label, meeting_date, location, chair_name, attendees_count, quorum_met, status, notes)
VALUES
  ('BM-2026-Q1', 'FY26 Q1', '2026-04-15'::date, 'Hyderabad HQ', 'Ramesh Iyer', 7, true, 'minutes_ratified', 'Reviewed annual plan and capex'),
  ('BM-2026-Q2', 'FY26 Q2', '2026-07-12'::date, 'Bangalore Office', 'Ramesh Iyer', 6, true, 'minutes_circulated', 'Series A bridge round discussion'),
  ('BM-2026-Q3', 'FY26 Q3', '2026-10-08'::date, 'Mumbai Investor Suite', 'Sunita Kapoor', 8, true, 'concluded', 'Hospital chain rollout approved'),
  ('BM-2026-Q4', 'FY26 Q4', '2027-01-21'::date, 'Virtual (Zoom)', 'Ramesh Iyer', 5, true, 'scheduled', 'Annual budget review pending'),
  ('BM-2025-Q4', 'FY25 Q4', '2026-01-18'::date, 'Hyderabad HQ', 'Ramesh Iyer', 7, true, 'minutes_ratified', 'Prior year close-out');

-- Seed action items
INSERT INTO board_action_items_r2857 (meeting_id, topic, decision, action_item, owner_name, due_date, done, done_at, follow_up_required, follow_up_notes, priority)
SELECT m.id, 'Series A Bridge', 'Approve INR 4.5cr bridge round', 'Engage 3 lead investors by end of month', 'Ganesh D', '2026-08-15'::date, true, '2026-08-12 14:00:00+05:30'::timestamptz, false, null, 'critical'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2026-Q2'
UNION ALL
SELECT m.id, 'Hospital Chain Rollout', 'Greenlight Apollo + Manipal pilots', 'Sign MoU with 2 chains', 'Sales Head', '2026-11-30'::date, false, null, true, 'Pending Apollo legal review', 'high'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2026-Q3'
UNION ALL
SELECT m.id, 'DPDP Compliance', 'Adopt full DPDP framework', 'Appoint DPO and publish privacy policy', 'Legal Counsel', '2026-05-31'::date, true, '2026-05-25 11:00:00+05:30'::timestamptz, false, null, 'high'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2026-Q1'
UNION ALL
SELECT m.id, 'Engineer Hiring', 'Expand bench by 20 engineers', 'HR to onboard via campus drives', 'HR Lead', '2026-09-30'::date, false, null, false, null, 'medium'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2026-Q2'
UNION ALL
SELECT m.id, 'NABH Certification Push', 'Target NABH Tier-2 by Q4', 'Audit-prep gap analysis', 'QA Manager', '2026-12-15'::date, false, null, true, 'Awaiting consultant report', 'medium'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2026-Q3'
UNION ALL
SELECT m.id, 'Capex Approval FY25', 'Approve INR 1.2cr tooling', 'Procurement and install', 'Operations Head', '2026-03-31'::date, true, '2026-03-28 16:30:00+05:30'::timestamptz, false, null, 'low'
FROM board_meetings_r2857 m WHERE m.meeting_code = 'BM-2025-Q4';

-- =====================================================================
-- RPCs
-- =====================================================================

DROP FUNCTION IF EXISTS founder_r2857_meetings_list();
CREATE FUNCTION founder_r2857_meetings_list()
RETURNS TABLE(meeting_code text, quarter_label text, meeting_date date, location text, chair_name text, attendees_count int, quorum_met boolean, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_code, m.quarter_label, m.meeting_date, m.location, m.chair_name, m.attendees_count, m.quorum_met, m.status, m.notes
  FROM board_meetings_r2857 m
  ORDER BY m.meeting_date DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_meetings_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_meetings_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_action_items_list();
CREATE FUNCTION founder_r2857_action_items_list()
RETURNS TABLE(meeting_code text, topic text, decision text, action_item text, owner_name text, due_date date, done boolean, follow_up_required boolean, priority text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_code, a.topic, a.decision, a.action_item, a.owner_name, a.due_date, a.done, a.follow_up_required, a.priority
  FROM board_action_items_r2857 a
  JOIN board_meetings_r2857 m ON m.id = a.meeting_id
  ORDER BY a.due_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_action_items_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_action_items_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_kpi_overview();
CREATE FUNCTION founder_r2857_kpi_overview()
RETURNS TABLE(total_meetings int, ratified_meetings int, total_actions int, completed_actions int, overdue_actions int, follow_ups_pending int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM board_meetings_r2857),
    (SELECT COUNT(*)::int FROM board_meetings_r2857 WHERE status = 'minutes_ratified'),
    (SELECT COUNT(*)::int FROM board_action_items_r2857),
    (SELECT COUNT(*)::int FROM board_action_items_r2857 WHERE done = true),
    (SELECT COUNT(*)::int FROM board_action_items_r2857 WHERE done = false AND due_date < CURRENT_DATE),
    (SELECT COUNT(*)::int FROM board_action_items_r2857 WHERE follow_up_required = true AND done = false);
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_kpi_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_kpi_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_overdue_actions();
CREATE FUNCTION founder_r2857_overdue_actions()
RETURNS TABLE(meeting_code text, topic text, action_item text, owner_name text, due_date date, priority text, days_overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_code, a.topic, a.action_item, a.owner_name, a.due_date, a.priority,
         (CURRENT_DATE - a.due_date)::int
  FROM board_action_items_r2857 a
  JOIN board_meetings_r2857 m ON m.id = a.meeting_id
  WHERE a.done = false AND a.due_date < CURRENT_DATE
  ORDER BY a.due_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_overdue_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_overdue_actions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_owner_workload();
CREATE FUNCTION founder_r2857_owner_workload()
RETURNS TABLE(owner_name text, total_actions int, completed int, open int, overdue int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.owner_name,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE a.done = true)::int,
         COUNT(*) FILTER (WHERE a.done = false)::int,
         COUNT(*) FILTER (WHERE a.done = false AND a.due_date < CURRENT_DATE)::int
  FROM board_action_items_r2857 a
  GROUP BY a.owner_name
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_owner_workload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_owner_workload() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_follow_ups();
CREATE FUNCTION founder_r2857_follow_ups()
RETURNS TABLE(meeting_code text, topic text, action_item text, owner_name text, follow_up_notes text, priority text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_code, a.topic, a.action_item, a.owner_name, COALESCE(a.follow_up_notes,''), a.priority
  FROM board_action_items_r2857 a
  JOIN board_meetings_r2857 m ON m.id = a.meeting_id
  WHERE a.follow_up_required = true
  ORDER BY a.priority DESC, a.due_date ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_follow_ups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_follow_ups() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_completion_rate_by_meeting();
CREATE FUNCTION founder_r2857_completion_rate_by_meeting()
RETURNS TABLE(meeting_code text, quarter_label text, total_actions int, done_count int, completion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_code, m.quarter_label,
         COUNT(a.id)::int,
         COUNT(a.id) FILTER (WHERE a.done = true)::int,
         CASE WHEN COUNT(a.id) = 0 THEN 0::numeric
              ELSE ROUND(100.0 * COUNT(a.id) FILTER (WHERE a.done = true) / COUNT(a.id), 1)
         END
  FROM board_meetings_r2857 m
  LEFT JOIN board_action_items_r2857 a ON a.meeting_id = m.id
  GROUP BY m.meeting_code, m.quarter_label, m.meeting_date
  ORDER BY m.meeting_date DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_completion_rate_by_meeting() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_completion_rate_by_meeting() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2857_priority_breakdown();
CREATE FUNCTION founder_r2857_priority_breakdown()
RETURNS TABLE(priority text, total int, done_count int, open_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.priority,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE a.done = true)::int,
         COUNT(*) FILTER (WHERE a.done = false)::int
  FROM board_action_items_r2857 a
  GROUP BY a.priority
  ORDER BY CASE a.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2857_priority_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2857_priority_breakdown() TO authenticated;

COMMIT;
