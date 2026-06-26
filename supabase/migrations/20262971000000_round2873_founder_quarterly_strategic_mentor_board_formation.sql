BEGIN;

-- =========================================================================
-- Round r2873 — Founder Quarterly Strategic Mentor Board Formation
-- mentor × domain × ask × commit × meeting cadence × insights × verdict
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: mentor candidates being vetted for the strategic board
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mentor_board_candidates_r2873 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_name     text NOT NULL,
  domain          text NOT NULL CHECK (domain IN ('clinical','finance','operations','distribution','regulatory','technology','fundraising')),
  city            text NOT NULL,
  ask_summary     text NOT NULL,
  ask_value_rupees bigint NOT NULL DEFAULT 0,
  commit_hours_per_quarter int NOT NULL DEFAULT 0,
  cadence         text NOT NULL CHECK (cadence IN ('weekly','biweekly','monthly','quarterly')),
  insight_score   int NOT NULL DEFAULT 0 CHECK (insight_score BETWEEN 0 AND 100),
  verdict         text NOT NULL DEFAULT 'pending' CHECK (verdict IN ('pending','invited','onboard','declined','parked')),
  invited_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE mentor_board_candidates_r2873 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON mentor_board_candidates_r2873
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO mentor_board_candidates_r2873
  (mentor_name, domain, city, ask_summary, ask_value_rupees, commit_hours_per_quarter, cadence, insight_score, verdict, invited_at)
VALUES
  ('Dr. Anita Rao',          'clinical',     'Hyderabad', 'Intros to 8 Tier-1 hospital biomed heads', 4500000, 12, 'monthly',   92, 'onboard',  '2026-05-12 09:00+05:30'::timestamptz),
  ('Vikram Shenoy',          'finance',      'Mumbai',    'CFO playbook + Series A intro deck review', 2800000, 8,  'monthly',   88, 'onboard',  '2026-05-18 10:00+05:30'::timestamptz),
  ('Priya Iyer',             'operations',   'Bengaluru', 'Field-ops SOPs from 600-engineer fleet',    1500000, 16, 'biweekly',  85, 'invited',  '2026-06-02 11:00+05:30'::timestamptz),
  ('Rohan Mehta',            'distribution', 'Delhi',     'AMC bulk contracts via hospital networks',  6200000, 6,  'quarterly', 81, 'pending',  NULL),
  ('Dr. Sanjay Kulkarni',    'regulatory',   'Pune',      'CDSCO + DPDP filing acceleration',          3300000, 10, 'monthly',   90, 'onboard',  '2026-04-22 09:30+05:30'::timestamptz),
  ('Lakshmi Nair',           'technology',   'Bengaluru', 'AI triage models from prior medtech exit',  3900000, 12, 'biweekly',  87, 'invited',  '2026-06-08 14:00+05:30'::timestamptz),
  ('Arjun Bhatt',            'fundraising',  'Mumbai',    'Warm intros to 6 healthcare VC partners',   8500000, 5,  'quarterly', 94, 'pending',  NULL),
  ('Meera Krishnan',         'clinical',     'Chennai',   'Super-specialty cardiology procurement',    2100000, 8,  'monthly',   76, 'declined', '2026-04-10 09:00+05:30'::timestamptz),
  ('Karthik Reddy',          'operations',   'Hyderabad', 'Warehouse + reverse-logistics rebuild',     1800000, 14, 'biweekly',  82, 'parked',   NULL);

-- -------------------------------------------------------------------------
-- Table 2: meetings + insights logged per mentor
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mentor_board_meetings_r2873 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id    uuid NOT NULL REFERENCES mentor_board_candidates_r2873(id) ON DELETE CASCADE,
  meeting_date    date NOT NULL,
  duration_min    int NOT NULL DEFAULT 60 CHECK (duration_min BETWEEN 10 AND 480),
  topic           text NOT NULL,
  insight_text    text NOT NULL,
  action_taken    text NOT NULL DEFAULT 'none' CHECK (action_taken IN ('none','noted','in_progress','done','blocked')),
  impact_rupees   bigint NOT NULL DEFAULT 0,
  follow_up_due   date,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE mentor_board_meetings_r2873 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON mentor_board_meetings_r2873
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO mentor_board_meetings_r2873
  (candidate_id, meeting_date, duration_min, topic, insight_text, action_taken, impact_rupees, follow_up_due)
SELECT id, '2026-05-20'::date, 75, 'Tier-1 hospital procurement', 'Push AMC-bundled CT-scanner deal via Apollo biomed lead', 'in_progress', 4500000, '2026-07-01'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Dr. Anita Rao'
UNION ALL
SELECT id, '2026-06-03'::date, 60, 'Series A deck', 'Compress unit economics into 1 slide; cite r1888 cohort', 'done', 0, '2026-06-15'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Vikram Shenoy'
UNION ALL
SELECT id, '2026-06-10'::date, 90, 'Field-ops SLA breach root cause', 'Engineers waiting on parts 38% of jobs — bond supplier SLA', 'noted', 1800000, '2026-06-25'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Priya Iyer'
UNION ALL
SELECT id, '2026-05-05'::date, 45, 'CDSCO Class B fast-track', 'Submit annexure-7 via lawyer Kulkarni Co; saves 6 weeks', 'done', 3300000, '2026-06-01'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Dr. Sanjay Kulkarni'
UNION ALL
SELECT id, '2026-06-12'::date, 60, 'AI triage v0 spec', 'Use BERT-based intent classifier on prior tickets — 87% acc', 'in_progress', 3900000, '2026-07-05'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Lakshmi Nair'
UNION ALL
SELECT id, '2026-05-28'::date, 30, 'Investor warm-intro list', 'Top 3 = Elevation + Accel + Nexus; pitch in 4 weeks', 'noted', 0, '2026-07-15'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Arjun Bhatt'
UNION ALL
SELECT id, '2026-06-15'::date, 60, 'Hospital chain rollout', 'Aster MIMS pilot 3 sites; offer 18-month AMC bundle', 'in_progress', 6200000, '2026-07-30'::date
  FROM mentor_board_candidates_r2873 WHERE mentor_name = 'Rohan Mehta';

-- -------------------------------------------------------------------------
-- RPC 1: KPI roll-up
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_mentor_board_kpis_r2873();
CREATE OR REPLACE FUNCTION get_mentor_board_kpis_r2873()
RETURNS TABLE (
  total_candidates    bigint,
  onboard_count       bigint,
  invited_count       bigint,
  pending_count       bigint,
  total_ask_rupees    bigint,
  total_commit_hours  bigint,
  avg_insight_score   numeric,
  total_meetings      bigint,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM mentor_board_candidates_r2873),
    (SELECT count(*) FROM mentor_board_candidates_r2873 WHERE verdict = 'onboard'),
    (SELECT count(*) FROM mentor_board_candidates_r2873 WHERE verdict = 'invited'),
    (SELECT count(*) FROM mentor_board_candidates_r2873 WHERE verdict = 'pending'),
    COALESCE((SELECT sum(ask_value_rupees) FROM mentor_board_candidates_r2873), 0)::bigint,
    COALESCE((SELECT sum(commit_hours_per_quarter) FROM mentor_board_candidates_r2873 WHERE verdict = 'onboard'), 0)::bigint,
    COALESCE((SELECT avg(insight_score) FROM mentor_board_candidates_r2873), 0)::numeric,
    (SELECT count(*) FROM mentor_board_meetings_r2873),
    COALESCE((SELECT sum(impact_rupees) FROM mentor_board_meetings_r2873), 0)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_mentor_board_kpis_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_mentor_board_kpis_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 2: list candidates
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_mentor_candidates_r2873();
CREATE OR REPLACE FUNCTION list_mentor_candidates_r2873()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  domain text,
  city text,
  ask_summary text,
  ask_value_rupees bigint,
  commit_hours_per_quarter int,
  cadence text,
  insight_score int,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.mentor_name, c.domain, c.city, c.ask_summary,
         c.ask_value_rupees, c.commit_hours_per_quarter, c.cadence, c.insight_score, c.verdict
  FROM mentor_board_candidates_r2873 c
  ORDER BY c.insight_score DESC, c.mentor_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_mentor_candidates_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_mentor_candidates_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 3: domain rollup
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_mentor_domain_rollup_r2873();
CREATE OR REPLACE FUNCTION get_mentor_domain_rollup_r2873()
RETURNS TABLE (
  domain text,
  candidates bigint,
  onboard bigint,
  total_ask_rupees bigint,
  avg_insight_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.domain,
         count(*)::bigint,
         count(*) FILTER (WHERE c.verdict = 'onboard')::bigint,
         COALESCE(sum(c.ask_value_rupees), 0)::bigint,
         COALESCE(avg(c.insight_score), 0)::numeric
  FROM mentor_board_candidates_r2873 c
  GROUP BY c.domain
  ORDER BY count(*) FILTER (WHERE c.verdict = 'onboard') DESC, c.domain ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_mentor_domain_rollup_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_mentor_domain_rollup_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 4: recent meetings with insights
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_mentor_meetings_r2873();
CREATE OR REPLACE FUNCTION list_mentor_meetings_r2873()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  domain text,
  meeting_date date,
  duration_min int,
  topic text,
  insight_text text,
  action_taken text,
  impact_rupees bigint,
  follow_up_due date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, c.mentor_name, c.domain, m.meeting_date, m.duration_min,
         m.topic, m.insight_text, m.action_taken, m.impact_rupees, m.follow_up_due
  FROM mentor_board_meetings_r2873 m
  JOIN mentor_board_candidates_r2873 c ON c.id = m.candidate_id
  ORDER BY m.meeting_date DESC, c.mentor_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_mentor_meetings_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_mentor_meetings_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 5: cadence schedule
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_mentor_cadence_rollup_r2873();
CREATE OR REPLACE FUNCTION get_mentor_cadence_rollup_r2873()
RETURNS TABLE (
  cadence text,
  onboard bigint,
  total_quarterly_hours bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cadence,
         count(*) FILTER (WHERE c.verdict = 'onboard')::bigint,
         COALESCE(sum(c.commit_hours_per_quarter) FILTER (WHERE c.verdict = 'onboard'), 0)::bigint
  FROM mentor_board_candidates_r2873 c
  GROUP BY c.cadence
  ORDER BY c.cadence;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_mentor_cadence_rollup_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_mentor_cadence_rollup_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 6: action follow-ups pending
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_mentor_followups_r2873();
CREATE OR REPLACE FUNCTION list_mentor_followups_r2873()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  topic text,
  action_taken text,
  follow_up_due date,
  days_until_due int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, c.mentor_name, m.topic, m.action_taken, m.follow_up_due,
         (m.follow_up_due - current_date)::int
  FROM mentor_board_meetings_r2873 m
  JOIN mentor_board_candidates_r2873 c ON c.id = m.candidate_id
  WHERE m.follow_up_due IS NOT NULL
    AND m.action_taken IN ('noted','in_progress')
  ORDER BY m.follow_up_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_mentor_followups_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_mentor_followups_r2873() TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 7: mark verdict
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS set_mentor_verdict_r2873(uuid, text);
CREATE OR REPLACE FUNCTION set_mentor_verdict_r2873(p_candidate_id uuid, p_verdict text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_verdict NOT IN ('pending','invited','onboard','declined','parked') THEN
    RAISE EXCEPTION 'invalid verdict';
  END IF;
  UPDATE mentor_board_candidates_r2873
     SET verdict = p_verdict,
         invited_at = CASE WHEN p_verdict IN ('invited','onboard') AND invited_at IS NULL THEN now() ELSE invited_at END
   WHERE id = p_candidate_id
   RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION set_mentor_verdict_r2873(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_mentor_verdict_r2873(uuid, text) TO authenticated;

-- -------------------------------------------------------------------------
-- RPC 8: top insights ranked by impact
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_top_mentor_insights_r2873();
CREATE OR REPLACE FUNCTION list_top_mentor_insights_r2873()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  domain text,
  topic text,
  insight_text text,
  impact_rupees bigint,
  action_taken text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, c.mentor_name, c.domain, m.topic, m.insight_text, m.impact_rupees, m.action_taken
  FROM mentor_board_meetings_r2873 m
  JOIN mentor_board_candidates_r2873 c ON c.id = m.candidate_id
  ORDER BY m.impact_rupees DESC, m.meeting_date DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_top_mentor_insights_r2873() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_top_mentor_insights_r2873() TO authenticated;

COMMIT;
