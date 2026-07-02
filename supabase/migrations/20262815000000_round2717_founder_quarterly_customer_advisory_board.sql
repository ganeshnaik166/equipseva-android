BEGIN;

-- =====================================================================
-- Round 2717 — Founder Quarterly Customer Advisory Board
-- Tracks CAB members, tenure, contributions, asks, engagement, decisions
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: CAB members + tenure + engagement + renew/retire decision
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cab_members_r2717 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_name     text NOT NULL,
  org_name        text NOT NULL,
  org_segment     text NOT NULL CHECK (org_segment IN ('hospital_chain','standalone_hospital','diagnostic_lab','clinic','distributor')),
  city            text NOT NULL,
  tier            text NOT NULL CHECK (tier IN ('tier1','tier2','tier3')),
  joined_on       date NOT NULL,
  tenure_quarters int  NOT NULL CHECK (tenure_quarters >= 0),
  engagement_score numeric(4,1) NOT NULL CHECK (engagement_score >= 0 AND engagement_score <= 10),
  meetings_attended int NOT NULL CHECK (meetings_attended >= 0),
  meetings_invited  int NOT NULL CHECK (meetings_invited >= 0),
  nps_given       int CHECK (nps_given >= 0 AND nps_given <= 10),
  arr_rupees      bigint NOT NULL CHECK (arr_rupees >= 0),
  decision        text NOT NULL CHECK (decision IN ('renew','retire','probation','rotate')),
  decision_reason text NOT NULL,
  decided_on      date NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cab_members_r2717 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cab_members_r2717;
CREATE POLICY founder_all ON cab_members_r2717
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO cab_members_r2717
  (member_name, org_name, org_segment, city, tier, joined_on, tenure_quarters, engagement_score, meetings_attended, meetings_invited, nps_given, arr_rupees, decision, decision_reason, decided_on)
VALUES
  ('Dr. Anjali Rao','Apollo Chain South','hospital_chain','Hyderabad','tier1','2025-04-01'::date, 5, 9.4, 5, 5, 9, 4800000, 'renew',   'Top contributor; drove AMC tier ladder feedback', '2026-06-20'::date),
  ('Mr. Rakesh Iyer','Manipal Whitefield','standalone_hospital','Bengaluru','tier1','2025-07-01'::date, 4, 8.6, 4, 4, 8, 3600000, 'renew',   'Champion of GST auto-invoice; high attendance', '2026-06-20'::date),
  ('Ms. Priya Menon','Suburban Diagnostics','diagnostic_lab','Chennai','tier2','2025-10-01'::date, 3, 5.8, 2, 3, 6, 1800000, 'probation','Skipped 1 meeting; needs Q1 re-engagement', '2026-06-20'::date),
  ('Dr. Vivek Sharma','LifeCare Clinic','clinic','Pune','tier3','2026-01-01'::date, 2, 7.2, 2, 2, 7,  720000, 'renew',   'Newer voice, strong tier-3 perspective', '2026-06-20'::date),
  ('Mr. Sandeep Goyal','MedSupply North','distributor','Delhi','tier2','2025-04-01'::date, 5, 4.1, 1, 5, 4, 2400000, 'retire',  'Low engagement; misaligned on AMC payment-first', '2026-06-20'::date),
  ('Dr. Kavitha Reddy','Yashoda Group','hospital_chain','Hyderabad','tier1','2025-07-01'::date, 4, 9.0, 4, 4, 9, 5200000, 'renew',   'Drove engineer-rotation policy; super-specialty insight', '2026-06-20'::date),
  ('Mr. Arjun Kapoor','PathLabs East','diagnostic_lab','Kolkata','tier2','2025-10-01'::date, 3, 6.4, 3, 3, 7, 2100000, 'rotate',  'Strong views; rotate seat to peer org for Q3', '2026-06-20'::date);

-- ---------------------------------------------------------------------
-- Table 2: contributions + asks per member per quarter
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cab_contributions_r2717 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id     uuid NOT NULL REFERENCES cab_members_r2717(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  contribution_summary text NOT NULL,
  contribution_kind    text NOT NULL CHECK (contribution_kind IN ('feature_idea','process_fix','intro','case_study','reference_call','beta_test')),
  contribution_value_rupees bigint NOT NULL DEFAULT 0 CHECK (contribution_value_rupees >= 0),
  ask_summary   text NOT NULL,
  ask_kind      text NOT NULL CHECK (ask_kind IN ('discount','feature_request','sla_change','training','priority_support','roadmap_visibility')),
  ask_status    text NOT NULL CHECK (ask_status IN ('open','accepted','declined','deferred','shipped')),
  recorded_on   date NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cab_contributions_r2717 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cab_contributions_r2717;
CREATE POLICY founder_all ON cab_contributions_r2717
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO cab_contributions_r2717
  (member_id, quarter_label, contribution_summary, contribution_kind, contribution_value_rupees, ask_summary, ask_kind, ask_status, recorded_on)
SELECT id, 'Q2-2026', 'Proposed AMC tier ladder with cap+floor pricing', 'feature_idea', 1200000, 'Chain-wide dashboard rollup', 'feature_request', 'shipped',  '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Dr. Anjali Rao'
UNION ALL
SELECT id, 'Q2-2026', 'GST auto-invoice spec walkthrough + 3 hospital intros', 'intro', 900000, 'Priority engineer for super-specialty wing', 'priority_support', 'accepted', '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Mr. Rakesh Iyer'
UNION ALL
SELECT id, 'Q2-2026', 'Lab-only SLA template draft', 'process_fix', 200000, '15 percent diagnostic discount on AMC',  'discount', 'declined',  '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Ms. Priya Menon'
UNION ALL
SELECT id, 'Q2-2026', 'Beta tested tier-3 mobile flow on 4 devices', 'beta_test', 50000, 'Hindi i18n in engineer app', 'feature_request', 'shipped', '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Dr. Vivek Sharma'
UNION ALL
SELECT id, 'Q2-2026', 'No participation in two consecutive meetings', 'process_fix', 0, 'Looser AMC payment terms (net-60)', 'sla_change', 'declined', '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Mr. Sandeep Goyal'
UNION ALL
SELECT id, 'Q2-2026', 'Recorded reference call for investor data room', 'reference_call', 600000, 'Roadmap visibility for Q3 ship list', 'roadmap_visibility', 'accepted', '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Dr. Kavitha Reddy'
UNION ALL
SELECT id, 'Q2-2026', 'Co-authored diagnostic lab case study draft', 'case_study', 300000, 'Free onsite engineer training for 2 days', 'training', 'deferred', '2026-06-15'::date FROM cab_members_r2717 WHERE member_name='Mr. Arjun Kapoor';

-- =====================================================================
-- RPCs
-- =====================================================================

-- 1. KPI summary
DROP FUNCTION IF EXISTS founder_cab_summary_r2717();
CREATE OR REPLACE FUNCTION founder_cab_summary_r2717()
RETURNS TABLE (
  total_members int,
  renewing int,
  retiring int,
  probation int,
  rotating int,
  avg_engagement numeric,
  total_arr_rupees bigint,
  total_contribution_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM cab_members_r2717),
    (SELECT count(*)::int FROM cab_members_r2717 WHERE decision='renew'),
    (SELECT count(*)::int FROM cab_members_r2717 WHERE decision='retire'),
    (SELECT count(*)::int FROM cab_members_r2717 WHERE decision='probation'),
    (SELECT count(*)::int FROM cab_members_r2717 WHERE decision='rotate'),
    (SELECT round(avg(engagement_score)::numeric, 2) FROM cab_members_r2717),
    (SELECT COALESCE(sum(arr_rupees),0)::bigint FROM cab_members_r2717),
    (SELECT COALESCE(sum(contribution_value_rupees),0)::bigint FROM cab_contributions_r2717);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_summary_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_summary_r2717() TO authenticated;

-- 2. Member roster with attendance pct
DROP FUNCTION IF EXISTS founder_cab_roster_r2717();
CREATE OR REPLACE FUNCTION founder_cab_roster_r2717()
RETURNS TABLE (
  id uuid,
  member_name text,
  org_name text,
  org_segment text,
  tier text,
  tenure_quarters int,
  engagement_score numeric,
  attendance_pct numeric,
  nps_given int,
  arr_rupees bigint,
  decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.member_name, m.org_name, m.org_segment, m.tier,
         m.tenure_quarters, m.engagement_score::numeric,
         CASE WHEN m.meetings_invited=0 THEN 0
              ELSE round(100.0 * m.meetings_attended / m.meetings_invited, 1)
         END AS attendance_pct,
         m.nps_given, m.arr_rupees, m.decision
  FROM cab_members_r2717 m
  ORDER BY m.engagement_score DESC, m.arr_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_roster_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_roster_r2717() TO authenticated;

-- 3. Contributions feed
DROP FUNCTION IF EXISTS founder_cab_contributions_r2717();
CREATE OR REPLACE FUNCTION founder_cab_contributions_r2717()
RETURNS TABLE (
  id uuid,
  member_name text,
  org_name text,
  quarter_label text,
  contribution_kind text,
  contribution_summary text,
  contribution_value_rupees bigint,
  recorded_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, m.member_name, m.org_name, c.quarter_label,
         c.contribution_kind, c.contribution_summary,
         c.contribution_value_rupees, c.recorded_on
  FROM cab_contributions_r2717 c
  JOIN cab_members_r2717 m ON m.id = c.member_id
  ORDER BY c.contribution_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_contributions_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_contributions_r2717() TO authenticated;

-- 4. Asks pipeline
DROP FUNCTION IF EXISTS founder_cab_asks_pipeline_r2717();
CREATE OR REPLACE FUNCTION founder_cab_asks_pipeline_r2717()
RETURNS TABLE (
  id uuid,
  member_name text,
  org_name text,
  ask_kind text,
  ask_summary text,
  ask_status text,
  recorded_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, m.member_name, m.org_name, c.ask_kind, c.ask_summary, c.ask_status, c.recorded_on
  FROM cab_contributions_r2717 c
  JOIN cab_members_r2717 m ON m.id = c.member_id
  ORDER BY CASE c.ask_status
    WHEN 'open' THEN 0 WHEN 'accepted' THEN 1 WHEN 'deferred' THEN 2
    WHEN 'shipped' THEN 3 WHEN 'declined' THEN 4 END,
    c.recorded_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_asks_pipeline_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_asks_pipeline_r2717() TO authenticated;

-- 5. Decision board
DROP FUNCTION IF EXISTS founder_cab_decisions_r2717();
CREATE OR REPLACE FUNCTION founder_cab_decisions_r2717()
RETURNS TABLE (
  id uuid,
  member_name text,
  org_name text,
  tier text,
  tenure_quarters int,
  engagement_score numeric,
  decision text,
  decision_reason text,
  decided_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.member_name, m.org_name, m.tier, m.tenure_quarters,
         m.engagement_score::numeric, m.decision, m.decision_reason, m.decided_on
  FROM cab_members_r2717 m
  ORDER BY CASE m.decision
    WHEN 'retire' THEN 0 WHEN 'probation' THEN 1
    WHEN 'rotate' THEN 2 WHEN 'renew' THEN 3 END,
    m.engagement_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_decisions_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_decisions_r2717() TO authenticated;

-- 6. Engagement by tier
DROP FUNCTION IF EXISTS founder_cab_engagement_by_tier_r2717();
CREATE OR REPLACE FUNCTION founder_cab_engagement_by_tier_r2717()
RETURNS TABLE (
  tier text,
  members int,
  avg_engagement numeric,
  avg_attendance_pct numeric,
  total_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.tier,
         count(*)::int,
         round(avg(m.engagement_score)::numeric, 2),
         round(avg(CASE WHEN m.meetings_invited=0 THEN 0
                   ELSE 100.0 * m.meetings_attended / m.meetings_invited END)::numeric, 1),
         COALESCE(sum(m.arr_rupees),0)::bigint
  FROM cab_members_r2717 m
  GROUP BY m.tier
  ORDER BY m.tier;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_engagement_by_tier_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_engagement_by_tier_r2717() TO authenticated;

-- 7. Top contributors
DROP FUNCTION IF EXISTS founder_cab_top_contributors_r2717();
CREATE OR REPLACE FUNCTION founder_cab_top_contributors_r2717()
RETURNS TABLE (
  member_name text,
  org_name text,
  contributions int,
  total_value_rupees bigint,
  asks_open int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.member_name, m.org_name,
         count(c.*)::int,
         COALESCE(sum(c.contribution_value_rupees),0)::bigint,
         count(*) FILTER (WHERE c.ask_status='open')::int
  FROM cab_members_r2717 m
  LEFT JOIN cab_contributions_r2717 c ON c.member_id = m.id
  GROUP BY m.member_name, m.org_name
  ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_top_contributors_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_top_contributors_r2717() TO authenticated;

-- 8. Retire candidates (red flags)
DROP FUNCTION IF EXISTS founder_cab_retire_candidates_r2717();
CREATE OR REPLACE FUNCTION founder_cab_retire_candidates_r2717()
RETURNS TABLE (
  id uuid,
  member_name text,
  org_name text,
  engagement_score numeric,
  attendance_pct numeric,
  decision text,
  reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.member_name, m.org_name, m.engagement_score::numeric,
         CASE WHEN m.meetings_invited=0 THEN 0
              ELSE round(100.0 * m.meetings_attended / m.meetings_invited, 1)
         END AS attendance_pct,
         m.decision, m.decision_reason
  FROM cab_members_r2717 m
  WHERE m.decision IN ('retire','probation')
     OR m.engagement_score < 6.0
  ORDER BY m.engagement_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_cab_retire_candidates_r2717() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_cab_retire_candidates_r2717() TO authenticated;

COMMIT;