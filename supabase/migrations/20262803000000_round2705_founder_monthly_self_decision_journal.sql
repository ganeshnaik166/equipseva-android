BEGIN;

-- ============================================================
-- Round 2705: Founder Monthly Self Decision Journal
-- Track founder decisions, stakes, hypotheses, outcomes,
-- surprises, lessons, and recurring patterns
-- ============================================================

-- ---------- table 1: decision entries ----------
DROP TABLE IF EXISTS founder_decision_journal_entries_r2705 CASCADE;
CREATE TABLE founder_decision_journal_entries_r2705 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_month date NOT NULL,
  decision_title text NOT NULL,
  decision_area text NOT NULL CHECK (decision_area IN ('product','hiring','capital','market','ops','tech','partnerships')),
  stakes_level text NOT NULL CHECK (stakes_level IN ('low','medium','high','existential')),
  reversibility text NOT NULL CHECK (reversibility IN ('one_way','two_way','hybrid')),
  hypothesis text NOT NULL,
  decision_rationale text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now(),
  evaluation_due_at timestamptz NOT NULL,
  outcome_status text NOT NULL DEFAULT 'pending' CHECK (outcome_status IN ('pending','validated','invalidated','mixed','too_early')),
  outcome_summary text,
  surprise_score int CHECK (surprise_score BETWEEN 0 AND 10),
  lesson_learned text,
  pattern_tag text,
  confidence_at_decision int CHECK (confidence_at_decision BETWEEN 0 AND 100),
  confidence_post_outcome int CHECK (confidence_post_outcome BETWEEN 0 AND 100),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_decision_journal_entries_r2705 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_decision_journal_entries_r2705;
CREATE POLICY founder_all ON founder_decision_journal_entries_r2705
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_decision_journal_entries_r2705
  (entry_month, decision_title, decision_area, stakes_level, reversibility, hypothesis, decision_rationale, decided_at, evaluation_due_at, outcome_status, outcome_summary, surprise_score, lesson_learned, pattern_tag, confidence_at_decision, confidence_post_outcome)
VALUES
  ('2026-06-01'::date, 'Scope down to Class A/B + super-specialty', 'market', 'existential', 'two_way',
   'Narrow ICP yields 3x close rate vs broad hospital market',
   'Skeptic panel forced ICP discipline; bloated pipeline wasting cycles',
   '2026-06-12 10:00:00+05:30', '2026-07-12 10:00:00+05:30', 'validated',
   'Pilot conversion jumped 38 to 71 percent in 3 weeks', 3,
   'Adversarial review beats consensus when stakes are existential', 'icp_focus', 60, 88),
  ('2026-06-01'::date, 'AMC payment-first architecture', 'product', 'high', 'one_way',
   'Payment-first eliminates free-service exploit and improves cash flow',
   'Audit-7 surfaced free-service-attack vector across all AMC triggers',
   '2026-06-11 14:00:00+05:30', '2026-07-11 14:00:00+05:30', 'validated',
   'Zero free-service exploits since rollout; AMC ARR up 22 percent', 4,
   'Money triggers must guard contract status before any side effect', 'security_economic', 75, 95),
  ('2026-05-15'::date, 'Hire senior Android dev externally', 'hiring', 'high', 'two_way',
   'External senior reduces ship velocity bottleneck by 40 percent',
   'Solo founder Android work blocking 3 features per week',
   '2026-05-20 09:00:00+05:30', '2026-06-20 09:00:00+05:30', 'invalidated',
   'Candidate withdrew week 2; lost 4 weeks of runway', 8,
   'Senior India hiring requires 3 parallel offers not sequential', 'hiring_risk', 70, 30),
  ('2026-06-01'::date, 'Defer Cashfree at-scale until KYC clears', 'capital', 'medium', 'hybrid',
   'Queueing payouts during KYC limbo causes acceptable founder pain only',
   'Cashfree activation in process; building reaper safer than blocking',
   '2026-06-09 11:00:00+05:30', '2026-07-09 11:00:00+05:30', 'validated',
   'Reaper held 14 payouts cleanly; founders kept happy', 2,
   'Build the queue before you need the queue', 'graceful_degradation', 80, 92),
  ('2026-04-01'::date, 'Launch hospital chain bulk v1', 'product', 'high', 'one_way',
   'Chain bulk pricing unlocks 5x ARR per logo vs single-site',
   '3 chains explicitly requested chain pricing in last 30 days',
   '2026-04-10 15:00:00+05:30', '2026-05-10 15:00:00+05:30', 'mixed',
   '2 chains adopted at 60 percent target; 1 churned over SLA', 5,
   'Chain SLA expectations exceed solo founder support capacity', 'support_scaling', 65, 50),
  ('2026-06-01'::date, 'DPDP grievance auto-routing', 'tech', 'high', 'two_way',
   'Auto-routing keeps SLA below 72 hours without founder bottleneck',
   'DPDP Act requires sub-72hr response; manual triage failing',
   '2026-06-13 12:00:00+05:30', '2026-07-13 12:00:00+05:30', 'validated',
   '11 of 11 grievances resolved under 48 hours since rollout', 1,
   'Compliance automation should be done 4 weeks before deadline not on it', 'compliance_ahead', 85, 98);

-- ---------- table 2: monthly patterns + reflections ----------
DROP TABLE IF EXISTS founder_decision_pattern_reflections_r2705 CASCADE;
CREATE TABLE founder_decision_pattern_reflections_r2705 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_month date NOT NULL,
  pattern_tag text NOT NULL,
  pattern_label text NOT NULL,
  occurrence_count int NOT NULL DEFAULT 1 CHECK (occurrence_count >= 0),
  validated_count int NOT NULL DEFAULT 0 CHECK (validated_count >= 0),
  invalidated_count int NOT NULL DEFAULT 0 CHECK (invalidated_count >= 0),
  avg_surprise_score numeric(4,2),
  primary_insight text NOT NULL,
  corrective_action text,
  monthly_theme text NOT NULL CHECK (monthly_theme IN ('focus','growth','risk','build','heal','sprint')),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_decision_pattern_reflections_r2705 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_decision_pattern_reflections_r2705;
CREATE POLICY founder_all ON founder_decision_pattern_reflections_r2705
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO founder_decision_pattern_reflections_r2705
  (reflection_month, pattern_tag, pattern_label, occurrence_count, validated_count, invalidated_count, avg_surprise_score, primary_insight, corrective_action, monthly_theme)
VALUES
  ('2026-06-01'::date, 'icp_focus', 'ICP narrowing beats expansion', 4, 4, 0, 2.50,
   'Every ICP-narrowing decision in last 90 days validated',
   'Default to narrow; require evidence to broaden', 'focus'),
  ('2026-06-01'::date, 'security_economic', 'Money triggers need status guards', 3, 3, 0, 3.67,
   'All economic exploits trace to missing contract-status guard',
   'New rule: trigger touching money must SELECT FOR UPDATE status first', 'risk'),
  ('2026-06-01'::date, 'hiring_risk', 'Sequential offers fail', 2, 0, 2, 7.50,
   'India senior hiring funnel needs 3x parallel offers',
   'Open 3 reqs per role; expect 2 withdrawals', 'heal'),
  ('2026-06-01'::date, 'graceful_degradation', 'Queue before you need it', 5, 5, 0, 2.20,
   'Reapers and queues built ahead absorb shocks invisibly',
   'Bake queue + reaper into every external integration scaffold', 'build'),
  ('2026-05-01'::date, 'support_scaling', 'Chain support outpaces solo capacity', 2, 0, 1, 5.00,
   'Chain logos demand SLA founder cannot personally honor',
   'Bundle chain pricing with paid CS hours starting Q3', 'growth'),
  ('2026-06-01'::date, 'compliance_ahead', 'Compliance shipped early reduces surprise', 3, 3, 0, 1.33,
   'Every compliance shipped 4+ weeks early returned zero ops drag',
   'Add 4-week buffer rule to all compliance deadlines', 'sprint');

-- ============================================================
-- RPCs (all SECURITY DEFINER, founder-gated, plpgsql)
-- ============================================================

-- 1. KPI rollup
DROP FUNCTION IF EXISTS rpc_decision_journal_kpis_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_kpis_r2705()
RETURNS TABLE (
  total_decisions bigint,
  validated_count bigint,
  invalidated_count bigint,
  pending_count bigint,
  mixed_count bigint,
  avg_surprise numeric,
  avg_confidence_delta numeric,
  existential_decisions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE outcome_status = 'validated')::bigint,
    count(*) FILTER (WHERE outcome_status = 'invalidated')::bigint,
    count(*) FILTER (WHERE outcome_status = 'pending')::bigint,
    count(*) FILTER (WHERE outcome_status = 'mixed')::bigint,
    round(avg(surprise_score)::numeric, 2),
    round(avg(confidence_post_outcome - confidence_at_decision)::numeric, 2),
    count(*) FILTER (WHERE stakes_level = 'existential')::bigint
  FROM founder_decision_journal_entries_r2705;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_kpis_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_kpis_r2705() TO authenticated;

-- 2. Recent entries
DROP FUNCTION IF EXISTS rpc_decision_journal_recent_r2705(int);
CREATE OR REPLACE FUNCTION rpc_decision_journal_recent_r2705(p_limit int DEFAULT 50)
RETURNS SETOF founder_decision_journal_entries_r2705
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM founder_decision_journal_entries_r2705
  ORDER BY decided_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_recent_r2705(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_recent_r2705(int) TO authenticated;

-- 3. Pattern reflections
DROP FUNCTION IF EXISTS rpc_decision_journal_patterns_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_patterns_r2705()
RETURNS SETOF founder_decision_pattern_reflections_r2705
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM founder_decision_pattern_reflections_r2705
  ORDER BY reflection_month DESC, occurrence_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_patterns_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_patterns_r2705() TO authenticated;

-- 4. Surprises (high-surprise outcomes)
DROP FUNCTION IF EXISTS rpc_decision_journal_high_surprise_r2705(int);
CREATE OR REPLACE FUNCTION rpc_decision_journal_high_surprise_r2705(p_threshold int DEFAULT 5)
RETURNS TABLE (
  decision_title text,
  decision_area text,
  surprise_score int,
  outcome_status text,
  lesson_learned text,
  decided_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.decision_title, e.decision_area, e.surprise_score, e.outcome_status, e.lesson_learned, e.decided_at
  FROM founder_decision_journal_entries_r2705 e
  WHERE e.surprise_score >= p_threshold
  ORDER BY e.surprise_score DESC, e.decided_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_high_surprise_r2705(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_high_surprise_r2705(int) TO authenticated;

-- 5. Validation rate by area
DROP FUNCTION IF EXISTS rpc_decision_journal_area_validation_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_area_validation_r2705()
RETURNS TABLE (
  decision_area text,
  total bigint,
  validated bigint,
  invalidated bigint,
  validation_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.decision_area,
    count(*)::bigint,
    count(*) FILTER (WHERE e.outcome_status = 'validated')::bigint,
    count(*) FILTER (WHERE e.outcome_status = 'invalidated')::bigint,
    CASE WHEN count(*) FILTER (WHERE e.outcome_status IN ('validated','invalidated')) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * count(*) FILTER (WHERE e.outcome_status = 'validated')
        / count(*) FILTER (WHERE e.outcome_status IN ('validated','invalidated')),
        2)
    END
  FROM founder_decision_journal_entries_r2705 e
  GROUP BY e.decision_area
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_area_validation_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_area_validation_r2705() TO authenticated;

-- 6. Pending evaluation overdue
DROP FUNCTION IF EXISTS rpc_decision_journal_overdue_evaluations_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_overdue_evaluations_r2705()
RETURNS TABLE (
  decision_title text,
  decision_area text,
  stakes_level text,
  evaluation_due_at timestamptz,
  days_overdue int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.decision_title, e.decision_area, e.stakes_level, e.evaluation_due_at,
    GREATEST(0, EXTRACT(DAY FROM (now() - e.evaluation_due_at))::int) AS days_overdue
  FROM founder_decision_journal_entries_r2705 e
  WHERE e.outcome_status = 'pending'
    AND e.evaluation_due_at < now()
  ORDER BY e.evaluation_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_overdue_evaluations_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_overdue_evaluations_r2705() TO authenticated;

-- 7. Stakes ladder
DROP FUNCTION IF EXISTS rpc_decision_journal_stakes_ladder_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_stakes_ladder_r2705()
RETURNS TABLE (
  stakes_level text,
  total bigint,
  avg_surprise numeric,
  avg_confidence_delta numeric,
  one_way_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.stakes_level,
    count(*)::bigint,
    round(avg(e.surprise_score)::numeric, 2),
    round(avg(e.confidence_post_outcome - e.confidence_at_decision)::numeric, 2),
    count(*) FILTER (WHERE e.reversibility = 'one_way')::bigint
  FROM founder_decision_journal_entries_r2705 e
  GROUP BY e.stakes_level
  ORDER BY
    CASE e.stakes_level
      WHEN 'existential' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_stakes_ladder_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_stakes_ladder_r2705() TO authenticated;

-- 8. Monthly theme summary
DROP FUNCTION IF EXISTS rpc_decision_journal_monthly_themes_r2705();
CREATE OR REPLACE FUNCTION rpc_decision_journal_monthly_themes_r2705()
RETURNS TABLE (
  reflection_month date,
  monthly_theme text,
  patterns_count bigint,
  total_validated bigint,
  total_invalidated bigint,
  avg_surprise numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.reflection_month,
    p.monthly_theme,
    count(*)::bigint,
    sum(p.validated_count)::bigint,
    sum(p.invalidated_count)::bigint,
    round(avg(p.avg_surprise_score)::numeric, 2)
  FROM founder_decision_pattern_reflections_r2705 p
  GROUP BY p.reflection_month, p.monthly_theme
  ORDER BY p.reflection_month DESC, count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_decision_journal_monthly_themes_r2705() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_decision_journal_monthly_themes_r2705() TO authenticated;

COMMIT;
