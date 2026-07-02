BEGIN;

-- =====================================================================
-- Round r2670 — Engineer Monthly Coaching Feedback Loop (HEAVY ★★★★)
-- 2 tables · 7+ SECDEF RPCs · founder-gated
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: monthly coaching sessions (engineer × coach × cycle)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_coaching_sessions_r2670 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month     date NOT NULL,
  engineer_code   text NOT NULL,
  engineer_tier   text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  coach_name      text NOT NULL,
  feedback_kind   text NOT NULL CHECK (feedback_kind IN ('1on1','field_ride_along','peer_review','customer_voc','escalation_postmortem')),
  improvement_area text NOT NULL CHECK (improvement_area IN ('diagnostic_speed','customer_comms','spare_handling','safety','upsell','documentation','escalation_handling')),
  action_taken    text NOT NULL,
  outcome_score   numeric(4,2) NOT NULL CHECK (outcome_score BETWEEN 0 AND 10),
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','escalated')),
  owner_coach     text NOT NULL,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  closed_at       timestamptz
);

ALTER TABLE engineer_monthly_coaching_sessions_r2670 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_coaching_sessions_r2670;
CREATE POLICY founder_all ON engineer_monthly_coaching_sessions_r2670
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_coaching_sessions_r2670
  (cycle_month, engineer_code, engineer_tier, coach_name, feedback_kind, improvement_area, action_taken, outcome_score, status, owner_coach, notes, closed_at)
VALUES
  ('2026-05-01','ENG-HYD-021','gold','Ravi Menon','1on1','diagnostic_speed','Shadow senior on 3 ultrasound calls',7.50,'closed','Ravi Menon','Avg first-fix time dropped 22%', now() - interval '20 days'),
  ('2026-05-01','ENG-BLR-044','silver','Priya Iyer','field_ride_along','customer_comms','Roleplay irate-customer scripts twice weekly',6.20,'in_progress','Priya Iyer','Hospital escalation reduced',NULL),
  ('2026-06-01','ENG-MUM-009','platinum','Anita Rao','peer_review','upsell','AMC pitch deck v3 + objection cards',8.40,'closed','Anita Rao','AMC attach +14 pp', now() - interval '4 days'),
  ('2026-06-01','ENG-CHN-031','bronze','Suresh Pillai','customer_voc','documentation','Daily checklist photo upload mandatory',5.10,'open','Suresh Pillai','Photo compliance still 60%',NULL),
  ('2026-06-01','ENG-DEL-018','silver','Ravi Menon','escalation_postmortem','escalation_handling','Reread escalation playbook + mock call',7.00,'in_progress','Ravi Menon','Awaiting next live escalation',NULL),
  ('2026-06-01','ENG-PNQ-077','gold','Priya Iyer','1on1','safety','LOTO refresher + quiz pass',9.10,'closed','Priya Iyer','100% LOTO adherence audited', now() - interval '2 days'),
  ('2026-06-01','ENG-HYD-052','bronze','Anita Rao','field_ride_along','spare_handling','Spare-kit audit before each job',4.80,'escalated','Anita Rao','Repeat spare-mismatch — escalated to ops head',NULL);

-- ---------------------------------------------------------------------
-- Table 2: improvement-area benchmarks per tier
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_coaching_area_benchmarks_r2670 (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  improvement_area  text NOT NULL CHECK (improvement_area IN ('diagnostic_speed','customer_comms','spare_handling','safety','upsell','documentation','escalation_handling')),
  engineer_tier     text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  target_score      numeric(4,2) NOT NULL CHECK (target_score BETWEEN 0 AND 10),
  pass_threshold    numeric(4,2) NOT NULL CHECK (pass_threshold BETWEEN 0 AND 10),
  weight_pct        int NOT NULL CHECK (weight_pct BETWEEN 0 AND 100),
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (improvement_area, engineer_tier)
);

ALTER TABLE engineer_coaching_area_benchmarks_r2670 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_coaching_area_benchmarks_r2670;
CREATE POLICY founder_all ON engineer_coaching_area_benchmarks_r2670
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_coaching_area_benchmarks_r2670
  (improvement_area, engineer_tier, target_score, pass_threshold, weight_pct, notes)
VALUES
  ('diagnostic_speed','bronze',6.00,5.00,20,'Bronze must hit 5+ to keep tier'),
  ('diagnostic_speed','platinum',9.00,8.00,25,'Platinum carries hardest jobs'),
  ('customer_comms','silver',7.00,6.00,15,'Silver = first patient-facing tier'),
  ('safety','gold',9.50,8.50,30,'Gold leads safety on-site'),
  ('upsell','platinum',8.50,7.00,20,'AMC + spare attach targets'),
  ('documentation','bronze',6.50,5.50,10,'Photo + checklist compliance'),
  ('escalation_handling','gold',8.00,7.00,15,'Gold absorbs escalations from below');

-- =====================================================================
-- RPC 1: list_coaching_sessions
-- =====================================================================
DROP FUNCTION IF EXISTS list_coaching_sessions_r2670();
CREATE OR REPLACE FUNCTION list_coaching_sessions_r2670()
RETURNS TABLE (
  id uuid, cycle_month date, engineer_code text, engineer_tier text,
  coach_name text, feedback_kind text, improvement_area text,
  action_taken text, outcome_score numeric, status text, owner_coach text,
  notes text, created_at timestamptz, closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.cycle_month, s.engineer_code, s.engineer_tier,
           s.coach_name, s.feedback_kind, s.improvement_area,
           s.action_taken, s.outcome_score, s.status, s.owner_coach,
           s.notes, s.created_at, s.closed_at
    FROM engineer_monthly_coaching_sessions_r2670 s
    ORDER BY s.cycle_month DESC, s.engineer_code ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_coaching_sessions_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_coaching_sessions_r2670() TO authenticated;

-- =====================================================================
-- RPC 2: top_improvement_focus
-- =====================================================================
DROP FUNCTION IF EXISTS top_improvement_focus_r2670();
CREATE OR REPLACE FUNCTION top_improvement_focus_r2670()
RETURNS TABLE (
  improvement_area text, sessions_count bigint, avg_score numeric, open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.improvement_area,
           COUNT(*)::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric,
           COUNT(*) FILTER (WHERE s.status IN ('open','in_progress','escalated'))::bigint
    FROM engineer_monthly_coaching_sessions_r2670 s
    GROUP BY s.improvement_area
    ORDER BY COUNT(*) DESC, AVG(s.outcome_score) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION top_improvement_focus_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION top_improvement_focus_r2670() TO authenticated;

-- =====================================================================
-- RPC 3: status_funnel
-- =====================================================================
DROP FUNCTION IF EXISTS coaching_status_funnel_r2670();
CREATE OR REPLACE FUNCTION coaching_status_funnel_r2670()
RETURNS TABLE (status text, sessions_count bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.status,
           COUNT(*)::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric
    FROM engineer_monthly_coaching_sessions_r2670 s
    GROUP BY s.status
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION coaching_status_funnel_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION coaching_status_funnel_r2670() TO authenticated;

-- =====================================================================
-- RPC 4: monthly_score_trend
-- =====================================================================
DROP FUNCTION IF EXISTS monthly_coaching_score_trend_r2670();
CREATE OR REPLACE FUNCTION monthly_coaching_score_trend_r2670()
RETURNS TABLE (cycle_month date, sessions_count bigint, avg_score numeric, closed_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.cycle_month,
           COUNT(*)::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric,
           COUNT(*) FILTER (WHERE s.status = 'closed')::bigint
    FROM engineer_monthly_coaching_sessions_r2670 s
    GROUP BY s.cycle_month
    ORDER BY s.cycle_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION monthly_coaching_score_trend_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION monthly_coaching_score_trend_r2670() TO authenticated;

-- =====================================================================
-- RPC 5: quarterly_kind_trend
-- =====================================================================
DROP FUNCTION IF EXISTS quarterly_coaching_kind_trend_r2670();
CREATE OR REPLACE FUNCTION quarterly_coaching_kind_trend_r2670()
RETURNS TABLE (quarter_start date, feedback_kind text, sessions_count bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('quarter', s.cycle_month)::date,
           s.feedback_kind,
           COUNT(*)::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric
    FROM engineer_monthly_coaching_sessions_r2670 s
    GROUP BY date_trunc('quarter', s.cycle_month), s.feedback_kind
    ORDER BY date_trunc('quarter', s.cycle_month) DESC, COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION quarterly_coaching_kind_trend_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION quarterly_coaching_kind_trend_r2670() TO authenticated;

-- =====================================================================
-- RPC 6: coaching_summary (KPIs)
-- =====================================================================
DROP FUNCTION IF EXISTS coaching_summary_r2670();
CREATE OR REPLACE FUNCTION coaching_summary_r2670()
RETURNS TABLE (
  total_sessions bigint,
  open_sessions bigint,
  closed_sessions bigint,
  escalated_sessions bigint,
  avg_outcome_score numeric,
  distinct_engineers bigint,
  distinct_coaches bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE s.status IN ('open','in_progress'))::bigint,
           COUNT(*) FILTER (WHERE s.status = 'closed')::bigint,
           COUNT(*) FILTER (WHERE s.status = 'escalated')::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric,
           COUNT(DISTINCT s.engineer_code)::bigint,
           COUNT(DISTINCT s.coach_name)::bigint
    FROM engineer_monthly_coaching_sessions_r2670 s;
END;
$$;
REVOKE EXECUTE ON FUNCTION coaching_summary_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION coaching_summary_r2670() TO authenticated;

-- =====================================================================
-- RPC 7: coach_owner_load
-- =====================================================================
DROP FUNCTION IF EXISTS coach_owner_load_r2670();
CREATE OR REPLACE FUNCTION coach_owner_load_r2670()
RETURNS TABLE (owner_coach text, open_count bigint, closed_count bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.owner_coach,
           COUNT(*) FILTER (WHERE s.status IN ('open','in_progress','escalated'))::bigint,
           COUNT(*) FILTER (WHERE s.status = 'closed')::bigint,
           ROUND(AVG(s.outcome_score), 2)::numeric
    FROM engineer_monthly_coaching_sessions_r2670 s
    GROUP BY s.owner_coach
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION coach_owner_load_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION coach_owner_load_r2670() TO authenticated;

-- =====================================================================
-- RPC 8: tier_gap_vs_benchmark
-- =====================================================================
DROP FUNCTION IF EXISTS tier_gap_vs_benchmark_r2670();
CREATE OR REPLACE FUNCTION tier_gap_vs_benchmark_r2670()
RETURNS TABLE (
  improvement_area text, engineer_tier text,
  target_score numeric, pass_threshold numeric,
  actual_avg numeric, gap_vs_target numeric, sessions_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.improvement_area,
           b.engineer_tier,
           b.target_score,
           b.pass_threshold,
           ROUND(AVG(s.outcome_score), 2)::numeric AS actual_avg,
           ROUND(AVG(s.outcome_score) - b.target_score, 2)::numeric AS gap_vs_target,
           COUNT(s.id)::bigint
    FROM engineer_coaching_area_benchmarks_r2670 b
    LEFT JOIN engineer_monthly_coaching_sessions_r2670 s
      ON s.improvement_area = b.improvement_area
     AND s.engineer_tier    = b.engineer_tier
    GROUP BY b.improvement_area, b.engineer_tier, b.target_score, b.pass_threshold
    ORDER BY gap_vs_target ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION tier_gap_vs_benchmark_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tier_gap_vs_benchmark_r2670() TO authenticated;

-- =====================================================================
-- RPC 9: list_benchmarks
-- =====================================================================
DROP FUNCTION IF EXISTS list_coaching_benchmarks_r2670();
CREATE OR REPLACE FUNCTION list_coaching_benchmarks_r2670()
RETURNS TABLE (
  id uuid, improvement_area text, engineer_tier text,
  target_score numeric, pass_threshold numeric, weight_pct int, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.improvement_area, b.engineer_tier,
           b.target_score, b.pass_threshold, b.weight_pct, b.notes
    FROM engineer_coaching_area_benchmarks_r2670 b
    ORDER BY b.improvement_area ASC, b.engineer_tier ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_coaching_benchmarks_r2670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_coaching_benchmarks_r2670() TO authenticated;

COMMIT;
