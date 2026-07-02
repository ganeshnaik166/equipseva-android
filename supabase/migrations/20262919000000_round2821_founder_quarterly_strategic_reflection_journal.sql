BEGIN;

-- ============================================================================
-- Round 2821: Founder Quarterly Strategic Reflection Journal
-- 2 tables, 8 SECDEF RPCs, 5+ seeds each
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: founder_quarterly_reflections_r2821
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_quarterly_reflections_r2821 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_id text NOT NULL UNIQUE,
  quarter_label text NOT NULL,
  reflection_date date NOT NULL,
  topic         text NOT NULL CHECK (topic IN ('strategy','people','product','growth','capital','ops','risk','culture')),
  insight       text NOT NULL,
  adjustment    text NOT NULL,
  outcome       text NOT NULL CHECK (outcome IN ('pending','partial','win','loss','deferred')),
  lessons       text NOT NULL,
  follow_up_due date,
  follow_up_owner text NOT NULL,
  confidence_score numeric(4,2) NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 10),
  impact_score  numeric(4,2) NOT NULL CHECK (impact_score >= 0 AND impact_score <= 10),
  status        text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','closed','archived')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_quarterly_reflections_r2821 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_quarterly_reflections_r2821;
CREATE POLICY founder_all ON founder_quarterly_reflections_r2821
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------
-- Table 2: founder_reflection_follow_ups_r2821
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_reflection_follow_ups_r2821 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follow_up_id  text NOT NULL UNIQUE,
  reflection_id text NOT NULL REFERENCES founder_quarterly_reflections_r2821(reflection_id) ON DELETE CASCADE,
  action_title  text NOT NULL,
  owner         text NOT NULL,
  due_date      date NOT NULL,
  completed_date date,
  state         text NOT NULL CHECK (state IN ('queued','in_progress','done','blocked','dropped')),
  outcome_note  text,
  effort_hours  numeric(6,1) NOT NULL DEFAULT 0,
  business_lift_score numeric(4,2) NOT NULL DEFAULT 0 CHECK (business_lift_score >= 0 AND business_lift_score <= 10),
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_reflection_follow_ups_r2821 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON founder_reflection_follow_ups_r2821;
CREATE POLICY founder_all ON founder_reflection_follow_ups_r2821
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------
-- Seeds — reflections
-- ----------------------------------------------------------------------------
INSERT INTO founder_quarterly_reflections_r2821
  (reflection_id, quarter_label, reflection_date, topic, insight, adjustment, outcome, lessons, follow_up_due, follow_up_owner, confidence_score, impact_score, status)
VALUES
  ('REF-2026Q1-01','2026-Q1','2026-03-28'::date,'strategy','Hospital chains close 4x faster than single sites','Reorient sales to top 50 chain GMs','win','Lead with chain economics not unit price','2026-06-30'::date,'founder',9.0,9.5,'closed'),
  ('REF-2026Q1-02','2026-Q1','2026-03-29'::date,'people','Senior engineer ramp time is 11 weeks not 6','Add structured mentorship + paid shadow weeks','partial','Hiring senior doesnt skip onboarding cost','2026-07-15'::date,'people-ops',7.5,8.0,'in_review'),
  ('REF-2026Q2-01','2026-Q2','2026-06-15'::date,'product','AMC tier upgrade flow loses 38 percent at price step','Show savings vs ad-hoc on same screen','pending','Friction lives in framing not in fields','2026-08-01'::date,'product',6.5,8.5,'open'),
  ('REF-2026Q2-02','2026-Q2','2026-06-18'::date,'capital','Burn dropped 22 percent after Cashfree payout cron fix','Lock cron monitor + weekly burn review','win','Infra reliability is a CAC line item','2026-09-30'::date,'finance',9.5,9.0,'closed'),
  ('REF-2026Q2-03','2026-Q2','2026-06-19'::date,'risk','3 of 7 audit-fix sweeps caught policy-bypass funcs','Mandatory pre-flight normalizer in CI','win','LANGUAGE plpgsql + GRANT authenticated = silent leak','2026-07-31'::date,'security',9.0,9.5,'closed'),
  ('REF-2026Q2-04','2026-Q2','2026-06-20'::date,'growth','Referral bounty consent gate drops referrals 14pct','Tighten copy + add WhatsApp share variant','partial','Consent UX beats consent legalese','2026-08-15'::date,'growth',6.0,7.0,'open'),
  ('REF-2026Q2-05','2026-Q2','2026-06-21'::date,'ops','Engineer payout disputes cluster on Mondays','Run Sunday-evening reconciliation cron','pending','Time-of-week ops debt is real','2026-07-25'::date,'ops',7.0,7.5,'open');

-- ----------------------------------------------------------------------------
-- Seeds — follow-ups
-- ----------------------------------------------------------------------------
INSERT INTO founder_reflection_follow_ups_r2821
  (follow_up_id, reflection_id, action_title, owner, due_date, completed_date, state, outcome_note, effort_hours, business_lift_score)
VALUES
  ('FU-2821-001','REF-2026Q1-01','Build chain-GM target list of 50','founder','2026-04-15'::date,'2026-04-12'::date,'done','List shared with sales',12.0,9.0),
  ('FU-2821-002','REF-2026Q1-02','Write 6-week senior-engineer mentor playbook','people-ops','2026-07-15'::date,NULL,'in_progress','Draft 60 percent',18.5,7.5),
  ('FU-2821-003','REF-2026Q2-01','A/B test new AMC price-step screen','product','2026-08-01'::date,NULL,'queued',NULL,0.0,8.5),
  ('FU-2821-004','REF-2026Q2-02','Add Slack alert on Cashfree cron failure','finance','2026-07-01'::date,'2026-06-25'::date,'done','PagerDuty + Slack wired',4.0,9.0),
  ('FU-2821-005','REF-2026Q2-03','Force pre-flight normalizer in CI','security','2026-07-10'::date,'2026-06-22'::date,'done','Blocks LANGUAGE plpgsql without gate',6.5,9.5),
  ('FU-2821-006','REF-2026Q2-04','Ship WhatsApp share variant for referrals','growth','2026-08-15'::date,NULL,'in_progress','Copy in review',7.0,7.0),
  ('FU-2821-007','REF-2026Q2-05','Build Sunday recon cron','ops','2026-07-25'::date,NULL,'queued',NULL,0.0,7.5);

-- ============================================================================
-- RPC 1: list reflections
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_list_reflections();
CREATE OR REPLACE FUNCTION founder_r2821_list_reflections()
RETURNS TABLE (
  reflection_id text,
  quarter_label text,
  reflection_date date,
  topic text,
  insight text,
  outcome text,
  status text,
  confidence_score numeric,
  impact_score numeric,
  follow_up_owner text,
  follow_up_due date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.reflection_id, r.quarter_label, r.reflection_date, r.topic, r.insight,
         r.outcome, r.status, r.confidence_score, r.impact_score,
         r.follow_up_owner, r.follow_up_due
  FROM founder_quarterly_reflections_r2821 r
  ORDER BY r.reflection_date DESC, r.reflection_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_list_reflections() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_list_reflections() TO authenticated;

-- ============================================================================
-- RPC 2: list follow-ups
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_list_follow_ups();
CREATE OR REPLACE FUNCTION founder_r2821_list_follow_ups()
RETURNS TABLE (
  follow_up_id text,
  reflection_id text,
  action_title text,
  owner text,
  due_date date,
  completed_date date,
  state text,
  effort_hours numeric,
  business_lift_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.follow_up_id, f.reflection_id, f.action_title, f.owner, f.due_date,
         f.completed_date, f.state, f.effort_hours, f.business_lift_score
  FROM founder_reflection_follow_ups_r2821 f
  ORDER BY f.due_date ASC, f.follow_up_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_list_follow_ups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_list_follow_ups() TO authenticated;

-- ============================================================================
-- RPC 3: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2821_kpi_summary()
RETURNS TABLE (
  total_reflections int,
  wins int,
  open_count int,
  avg_confidence numeric,
  avg_impact numeric,
  follow_ups_total int,
  follow_ups_done int,
  follow_ups_overdue int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM founder_quarterly_reflections_r2821),
    (SELECT count(*)::int FROM founder_quarterly_reflections_r2821 WHERE outcome = 'win'),
    (SELECT count(*)::int FROM founder_quarterly_reflections_r2821 WHERE status = 'open'),
    (SELECT COALESCE(round(avg(confidence_score)::numeric, 2), 0) FROM founder_quarterly_reflections_r2821),
    (SELECT COALESCE(round(avg(impact_score)::numeric, 2), 0) FROM founder_quarterly_reflections_r2821),
    (SELECT count(*)::int FROM founder_reflection_follow_ups_r2821),
    (SELECT count(*)::int FROM founder_reflection_follow_ups_r2821 WHERE state = 'done'),
    (SELECT count(*)::int FROM founder_reflection_follow_ups_r2821 WHERE state IN ('queued','in_progress','blocked') AND due_date < current_date);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_kpi_summary() TO authenticated;

-- ============================================================================
-- RPC 4: by-topic breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_by_topic();
CREATE OR REPLACE FUNCTION founder_r2821_by_topic()
RETURNS TABLE (
  topic text,
  reflection_count int,
  avg_impact numeric,
  win_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.topic,
         count(*)::int,
         round(avg(r.impact_score)::numeric, 2),
         count(*) FILTER (WHERE r.outcome = 'win')::int
  FROM founder_quarterly_reflections_r2821 r
  GROUP BY r.topic
  ORDER BY count(*) DESC, r.topic;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_by_topic() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_by_topic() TO authenticated;

-- ============================================================================
-- RPC 5: overdue follow-ups
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_overdue_follow_ups();
CREATE OR REPLACE FUNCTION founder_r2821_overdue_follow_ups()
RETURNS TABLE (
  follow_up_id text,
  action_title text,
  owner text,
  due_date date,
  days_overdue int,
  state text,
  business_lift_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.follow_up_id, f.action_title, f.owner, f.due_date,
         (current_date - f.due_date)::int,
         f.state, f.business_lift_score
  FROM founder_reflection_follow_ups_r2821 f
  WHERE f.state IN ('queued','in_progress','blocked')
    AND f.due_date < current_date
  ORDER BY (current_date - f.due_date) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_overdue_follow_ups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_overdue_follow_ups() TO authenticated;

-- ============================================================================
-- RPC 6: quarterly rollup
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_quarterly_rollup();
CREATE OR REPLACE FUNCTION founder_r2821_quarterly_rollup()
RETURNS TABLE (
  quarter_label text,
  reflection_count int,
  avg_confidence numeric,
  avg_impact numeric,
  wins int,
  losses int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.quarter_label,
         count(*)::int,
         round(avg(r.confidence_score)::numeric, 2),
         round(avg(r.impact_score)::numeric, 2),
         count(*) FILTER (WHERE r.outcome = 'win')::int,
         count(*) FILTER (WHERE r.outcome = 'loss')::int
  FROM founder_quarterly_reflections_r2821 r
  GROUP BY r.quarter_label
  ORDER BY r.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_quarterly_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_quarterly_rollup() TO authenticated;

-- ============================================================================
-- RPC 7: log a new reflection
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_log_reflection(text, text, date, text, text, text, text, text, date, text, numeric, numeric);
CREATE OR REPLACE FUNCTION founder_r2821_log_reflection(
  p_reflection_id text,
  p_quarter_label text,
  p_reflection_date date,
  p_topic text,
  p_insight text,
  p_adjustment text,
  p_outcome text,
  p_lessons text,
  p_follow_up_due date,
  p_follow_up_owner text,
  p_confidence numeric,
  p_impact numeric
)
RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id text;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_quarterly_reflections_r2821
    (reflection_id, quarter_label, reflection_date, topic, insight, adjustment, outcome, lessons, follow_up_due, follow_up_owner, confidence_score, impact_score, status)
  VALUES
    (p_reflection_id, p_quarter_label, p_reflection_date, p_topic, p_insight, p_adjustment, p_outcome, p_lessons, p_follow_up_due, p_follow_up_owner, p_confidence, p_impact, 'open')
  RETURNING reflection_id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_log_reflection(text, text, date, text, text, text, text, text, date, text, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_log_reflection(text, text, date, text, text, text, text, text, date, text, numeric, numeric) TO authenticated;

-- ============================================================================
-- RPC 8: top lessons (by impact)
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2821_top_lessons();
CREATE OR REPLACE FUNCTION founder_r2821_top_lessons()
RETURNS TABLE (
  reflection_id text,
  quarter_label text,
  topic text,
  lessons text,
  impact_score numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.reflection_id, r.quarter_label, r.topic, r.lessons, r.impact_score, r.outcome
  FROM founder_quarterly_reflections_r2821 r
  ORDER BY r.impact_score DESC, r.reflection_date DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2821_top_lessons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2821_top_lessons() TO authenticated;

COMMIT;
