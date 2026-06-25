BEGIN;

-- ============================================================================
-- Round 2701 — Founder Monthly Mentor & Advisor Engagement
-- mentor × topic × time invested × value × follow-up × deepen relationship
-- ============================================================================

-- Table 1: Monthly mentor sessions
CREATE TABLE IF NOT EXISTS founder_mentor_sessions_r2701 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_name text NOT NULL,
  mentor_role text NOT NULL,
  topic text NOT NULL,
  session_date date NOT NULL,
  time_invested_minutes integer NOT NULL CHECK (time_invested_minutes > 0),
  value_score integer NOT NULL CHECK (value_score BETWEEN 1 AND 10),
  key_insight text NOT NULL,
  follow_up_action text NOT NULL,
  follow_up_due_date date,
  follow_up_status text NOT NULL DEFAULT 'pending' CHECK (follow_up_status IN ('pending','in_progress','done','dropped')),
  deepen_relationship_action text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_mentor_sessions_r2701 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_mentor_sessions_r2701;
CREATE POLICY founder_all ON founder_mentor_sessions_r2701 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: Mentor relationship roster
CREATE TABLE IF NOT EXISTS founder_mentor_roster_r2701 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_name text NOT NULL UNIQUE,
  affiliation text NOT NULL,
  expertise_area text NOT NULL,
  relationship_depth text NOT NULL CHECK (relationship_depth IN ('cold','warm','close','inner_circle')),
  cadence_target_per_quarter integer NOT NULL CHECK (cadence_target_per_quarter > 0),
  last_touch_date date,
  next_touch_planned_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_mentor_roster_r2701 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_mentor_roster_r2701;
CREATE POLICY founder_all ON founder_mentor_roster_r2701 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================

INSERT INTO founder_mentor_sessions_r2701 (mentor_name, mentor_role, topic, session_date, time_invested_minutes, value_score, key_insight, follow_up_action, follow_up_due_date, follow_up_status, deepen_relationship_action) VALUES
  ('Ravi Subramanian', 'Ex-CTO MedTech Unicorn', 'Hospital chain pricing strategy', '2026-06-03'::date, 75, 9, 'Anchor on outcomes (uptime SLA) not unit price — chains pay 2x for guaranteed availability', 'Rewrite chain pricing deck around outcome SLA tiers', '2026-06-15'::date, 'in_progress', 'Send 2-page execution recap + ask to introduce to Apollo head of biomed'),
  ('Dr. Anjali Mehta', 'AIIMS Biomedical Dept Head', 'NABH compliance moats', '2026-06-08'::date, 60, 10, 'Bonded parts provenance is the unfakeable moat — competitors will need 18mo to catch up', 'File CDSCO addendum on bonded-parts traceability', '2026-06-20'::date, 'pending', 'Co-author a 1-pager on bonded-parts standard for NABH 6th-ed submission'),
  ('Karthik Nayak', 'Partner Sequoia India', 'Series A narrative', '2026-06-12'::date, 90, 8, 'Lead with revenue retention cohorts (NRR > 130%) not MRR — investors price retention, not growth', 'Pull 6mo cohort NRR + build investor data room cohort tab', '2026-06-25'::date, 'in_progress', 'Send weekly 3-bullet update every Friday, no ask attached for 4 weeks'),
  ('Suresh Iyer', 'Ex-COO Practo', 'Field engineer ops scaling', '2026-06-15'::date, 45, 7, 'Pod-based dispatch beats round-robin at 50+ engineers — start pod design at 30', 'Draft pod-charter doc + pilot in Hyderabad zone', '2026-07-01'::date, 'pending', 'Invite Suresh as observer on first pod kick-off call'),
  ('Meera Pillai', 'GP at Blume Ventures', 'Founder mental health & cadence', '2026-06-18'::date, 50, 9, 'Sustainable founder pace = 1 deep-work block + 1 ops block + hard stop — burn-out cuts valuation 30%', 'Block calendar 09:00-12:00 deep-work Mon-Thu', '2026-06-22'::date, 'done', 'Share quarterly wellness check + recommend mutual peer-mentor'),
  ('Vikram Joshi', 'Ex-VP Engineering Razorpay', 'Payment ops at scale', '2026-06-20'::date, 65, 8, 'Reconciliation breaks at 10k txn/day — invest in ledger tooling NOW not at scale', 'Spec out double-entry ledger schema for v0.5', '2026-07-05'::date, 'pending', 'Offer to brief his team on bonded-parts ledger pattern (reciprocal value)');

INSERT INTO founder_mentor_roster_r2701 (mentor_name, affiliation, expertise_area, relationship_depth, cadence_target_per_quarter, last_touch_date, next_touch_planned_date, notes) VALUES
  ('Ravi Subramanian', 'Independent / Board candidate', 'MedTech go-to-market', 'inner_circle', 6, '2026-06-03'::date, '2026-07-10'::date, 'Board seat conversation open — decide by Q3'),
  ('Dr. Anjali Mehta', 'AIIMS Delhi', 'Clinical engineering / NABH', 'close', 3, '2026-06-08'::date, '2026-07-15'::date, 'Co-author potential on bonded-parts standard'),
  ('Karthik Nayak', 'Sequoia India', 'Venture / fundraising', 'warm', 4, '2026-06-12'::date, '2026-06-19'::date, 'Weekly Friday update cadence active'),
  ('Suresh Iyer', 'Independent advisor', 'Field operations', 'warm', 2, '2026-06-15'::date, '2026-08-01'::date, 'Pod-design observer commitment given'),
  ('Meera Pillai', 'Blume Ventures', 'Founder wellbeing / strategy', 'close', 4, '2026-06-18'::date, '2026-07-20'::date, 'Peer-mentor intro pending'),
  ('Vikram Joshi', 'Independent', 'Payments / fintech ops', 'warm', 3, '2026-06-20'::date, '2026-08-05'::date, 'Reciprocal value swap on ledger pattern'),
  ('Priya Raman', 'Ex-Head of Product Tata 1mg', 'Consumer health UX', 'cold', 2, '2026-05-10'::date, '2026-07-01'::date, 'Re-warm with insight share on engineer app v0.5');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_mentor_kpis_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_kpis_r2701()
RETURNS TABLE (
  total_sessions_month integer,
  total_minutes_invested integer,
  avg_value_score numeric,
  open_followups integer,
  inner_circle_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::integer FROM founder_mentor_sessions_r2701 WHERE session_date >= date_trunc('month', current_date)::date),
    (SELECT COALESCE(sum(time_invested_minutes),0)::integer FROM founder_mentor_sessions_r2701 WHERE session_date >= date_trunc('month', current_date)::date),
    (SELECT COALESCE(round(avg(value_score)::numeric, 2), 0) FROM founder_mentor_sessions_r2701 WHERE session_date >= date_trunc('month', current_date)::date),
    (SELECT count(*)::integer FROM founder_mentor_sessions_r2701 WHERE follow_up_status IN ('pending','in_progress')),
    (SELECT count(*)::integer FROM founder_mentor_roster_r2701 WHERE relationship_depth = 'inner_circle');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_kpis_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_kpis_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_sessions_list_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_sessions_list_r2701()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_role text,
  topic text,
  session_date date,
  time_invested_minutes integer,
  value_score integer,
  follow_up_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.id, s.mentor_name, s.mentor_role, s.topic, s.session_date,
         s.time_invested_minutes, s.value_score, s.follow_up_status
  FROM founder_mentor_sessions_r2701 s
  ORDER BY s.session_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_sessions_list_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_sessions_list_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_open_followups_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_open_followups_r2701()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  topic text,
  follow_up_action text,
  follow_up_due_date date,
  follow_up_status text,
  days_until_due integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.id, s.mentor_name, s.topic, s.follow_up_action, s.follow_up_due_date, s.follow_up_status,
         CASE WHEN s.follow_up_due_date IS NULL THEN NULL
              ELSE (s.follow_up_due_date - current_date)::integer END
  FROM founder_mentor_sessions_r2701 s
  WHERE s.follow_up_status IN ('pending','in_progress')
  ORDER BY s.follow_up_due_date NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_open_followups_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_open_followups_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_roster_list_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_roster_list_r2701()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  affiliation text,
  expertise_area text,
  relationship_depth text,
  cadence_target_per_quarter integer,
  last_touch_date date,
  next_touch_planned_date date,
  days_since_touch integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.mentor_name, r.affiliation, r.expertise_area, r.relationship_depth,
         r.cadence_target_per_quarter, r.last_touch_date, r.next_touch_planned_date,
         CASE WHEN r.last_touch_date IS NULL THEN NULL
              ELSE (current_date - r.last_touch_date)::integer END
  FROM founder_mentor_roster_r2701 r
  ORDER BY
    CASE r.relationship_depth
      WHEN 'inner_circle' THEN 1
      WHEN 'close' THEN 2
      WHEN 'warm' THEN 3
      WHEN 'cold' THEN 4
    END,
    r.last_touch_date DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_roster_list_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_roster_list_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_topic_value_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_topic_value_r2701()
RETURNS TABLE (
  topic text,
  session_count integer,
  total_minutes integer,
  avg_value_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.topic, count(*)::integer, sum(s.time_invested_minutes)::integer, round(avg(s.value_score)::numeric, 2)
  FROM founder_mentor_sessions_r2701 s
  GROUP BY s.topic
  ORDER BY avg(s.value_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_topic_value_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_topic_value_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_high_value_sessions_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_high_value_sessions_r2701()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  topic text,
  value_score integer,
  key_insight text,
  deepen_relationship_action text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.id, s.mentor_name, s.topic, s.value_score, s.key_insight, s.deepen_relationship_action
  FROM founder_mentor_sessions_r2701 s
  WHERE s.value_score >= 8
  ORDER BY s.value_score DESC, s.session_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_high_value_sessions_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_high_value_sessions_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_relationship_health_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_relationship_health_r2701()
RETURNS TABLE (
  relationship_depth text,
  mentor_count integer,
  avg_days_since_touch numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.relationship_depth,
         count(*)::integer,
         round(avg(current_date - r.last_touch_date)::numeric, 1)
  FROM founder_mentor_roster_r2701 r
  GROUP BY r.relationship_depth
  ORDER BY
    CASE r.relationship_depth
      WHEN 'inner_circle' THEN 1
      WHEN 'close' THEN 2
      WHEN 'warm' THEN 3
      WHEN 'cold' THEN 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_relationship_health_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_relationship_health_r2701() TO authenticated;

DROP FUNCTION IF EXISTS founder_mentor_cadence_risk_r2701();
CREATE OR REPLACE FUNCTION founder_mentor_cadence_risk_r2701()
RETURNS TABLE (
  mentor_name text,
  relationship_depth text,
  days_since_touch integer,
  next_touch_planned_date date,
  risk_label text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.mentor_name,
         r.relationship_depth,
         (current_date - r.last_touch_date)::integer,
         r.next_touch_planned_date,
         CASE
           WHEN r.last_touch_date IS NULL THEN 'no_touch'
           WHEN current_date - r.last_touch_date > 60 THEN 'stale'
           WHEN current_date - r.last_touch_date > 30 THEN 'aging'
           ELSE 'fresh'
         END
  FROM founder_mentor_roster_r2701 r
  ORDER BY (current_date - r.last_touch_date) DESC NULLS FIRST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_mentor_cadence_risk_r2701() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_mentor_cadence_risk_r2701() TO authenticated;

COMMIT;
