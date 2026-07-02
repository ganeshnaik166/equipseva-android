BEGIN;

-- ============================================================================
-- Round 2846: Engineer Monthly Customer Job Quality Score Card
-- Spec: engineer × job × dimension × score × variance × intervention × verdict
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: Monthly engineer score card rows (dimension-level)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_score_card_r2846 (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_start      date NOT NULL,
  engineer_code    text NOT NULL,
  engineer_name    text NOT NULL,
  job_code         text NOT NULL,
  dimension        text NOT NULL CHECK (dimension IN ('punctuality','craftsmanship','communication','safety','cleanup','followup','parts_handling')),
  raw_score        numeric(4,2) NOT NULL CHECK (raw_score >= 0 AND raw_score <= 10),
  cohort_median    numeric(4,2) NOT NULL CHECK (cohort_median >= 0 AND cohort_median <= 10),
  variance         numeric(5,2) NOT NULL,
  customer_count   int NOT NULL CHECK (customer_count >= 0),
  verdict          text NOT NULL CHECK (verdict IN ('excellent','solid','watch','coach','escalate')),
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_score_card_r2846 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_score_card_r2846;
CREATE POLICY founder_all ON engineer_monthly_score_card_r2846
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_score_card_r2846
  (month_start, engineer_code, engineer_name, job_code, dimension, raw_score, cohort_median, variance, customer_count, verdict, notes)
VALUES
  ('2026-06-01'::date, 'ENG-101', 'Ravi Kumar',   'JOB-5501', 'punctuality',    9.40, 8.10,  1.30,  6, 'excellent', 'On-site within SLA every call'),
  ('2026-06-01'::date, 'ENG-101', 'Ravi Kumar',   'JOB-5501', 'craftsmanship',  9.10, 8.20,  0.90,  6, 'excellent', 'Zero rework month'),
  ('2026-06-01'::date, 'ENG-102', 'Anjali Mehta', 'JOB-5502', 'communication',  7.20, 8.00, -0.80,  5, 'watch',     'Customers asked for clearer ETAs'),
  ('2026-06-01'::date, 'ENG-103', 'Suresh Patil', 'JOB-5503', 'safety',         6.10, 8.30, -2.20,  4, 'coach',     'Missed PPE checklist twice'),
  ('2026-06-01'::date, 'ENG-104', 'Lakshmi Iyer', 'JOB-5504', 'cleanup',        8.90, 8.40,  0.50,  7, 'solid',     'Customers noted neat handover'),
  ('2026-06-01'::date, 'ENG-105', 'Vikram Singh', 'JOB-5505', 'followup',       5.40, 8.10, -2.70,  3, 'escalate',  'No followup calls placed'),
  ('2026-06-01'::date, 'ENG-106', 'Priya Nair',   'JOB-5506', 'parts_handling', 8.20, 8.00,  0.20,  5, 'solid',     'Used bonded parts only');

-- ----------------------------------------------------------------------------
-- Table 2: Interventions issued against the score card
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_score_card_interventions_r2846 (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id           uuid NOT NULL REFERENCES engineer_monthly_score_card_r2846(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('coaching','training','shadow','pip','recognition','reroute')),
  owner             text NOT NULL,
  due_date          date NOT NULL,
  status            text NOT NULL CHECK (status IN ('open','in_progress','completed','blocked','cancelled')),
  outcome_note      text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_score_card_interventions_r2846 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_score_card_interventions_r2846;
CREATE POLICY founder_all ON engineer_score_card_interventions_r2846
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_score_card_interventions_r2846
  (card_id, intervention_type, owner, due_date, status, outcome_note)
SELECT id, 'recognition', 'Ops Lead',     '2026-06-25'::date, 'completed',   'Spot bonus issued'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-101' AND dimension = 'punctuality'
UNION ALL
SELECT id, 'recognition', 'Ops Lead',     '2026-06-25'::date, 'completed',   'Featured in monthly all-hands'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-101' AND dimension = 'craftsmanship'
UNION ALL
SELECT id, 'coaching',    'Training Mgr', '2026-06-28'::date, 'in_progress', 'ETA script practice scheduled'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-102'
UNION ALL
SELECT id, 'training',    'Safety Lead',  '2026-06-30'::date, 'open',        'Refresher booked for next week'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-103'
UNION ALL
SELECT id, 'shadow',      'Senior Tech',  '2026-07-02'::date, 'open',        'Pair with ENG-101 for one rotation'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-104'
UNION ALL
SELECT id, 'pip',         'Founder',      '2026-07-05'::date, 'open',        'Formal PIP — followup discipline'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-105'
UNION ALL
SELECT id, 'reroute',     'Dispatch',     '2026-06-27'::date, 'in_progress', 'Lower complexity jobs while coaching'
  FROM engineer_monthly_score_card_r2846 WHERE engineer_code = 'ENG-106';

-- ============================================================================
-- RPCs (all SECURITY DEFINER, gated by is_founder())
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2846_score_card_kpis();
CREATE OR REPLACE FUNCTION founder_r2846_score_card_kpis()
RETURNS TABLE (
  engineers_scored     int,
  avg_raw_score        numeric,
  avg_variance         numeric,
  escalate_count       int,
  excellent_count      int,
  open_interventions   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT engineer_code)::int FROM engineer_monthly_score_card_r2846),
    (SELECT ROUND(AVG(raw_score)::numeric, 2)  FROM engineer_monthly_score_card_r2846),
    (SELECT ROUND(AVG(variance)::numeric, 2)   FROM engineer_monthly_score_card_r2846),
    (SELECT COUNT(*)::int FROM engineer_monthly_score_card_r2846 WHERE verdict = 'escalate'),
    (SELECT COUNT(*)::int FROM engineer_monthly_score_card_r2846 WHERE verdict = 'excellent'),
    (SELECT COUNT(*)::int FROM engineer_score_card_interventions_r2846 WHERE status IN ('open','in_progress'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_score_card_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_score_card_kpis() TO authenticated;

-- RPC 2: All rows
DROP FUNCTION IF EXISTS founder_r2846_score_card_rows();
CREATE OR REPLACE FUNCTION founder_r2846_score_card_rows()
RETURNS SETOF engineer_monthly_score_card_r2846
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_monthly_score_card_r2846
  ORDER BY variance ASC, engineer_code, dimension;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_score_card_rows() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_score_card_rows() TO authenticated;

-- RPC 3: Per-engineer rollup
DROP FUNCTION IF EXISTS founder_r2846_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2846_engineer_rollup()
RETURNS TABLE (
  engineer_code   text,
  engineer_name   text,
  dimensions      int,
  avg_score       numeric,
  avg_variance    numeric,
  worst_verdict   text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_code,
    MAX(s.engineer_name),
    COUNT(*)::int,
    ROUND(AVG(s.raw_score)::numeric, 2),
    ROUND(AVG(s.variance)::numeric, 2),
    (ARRAY_AGG(s.verdict ORDER BY
       CASE s.verdict
         WHEN 'escalate'  THEN 1
         WHEN 'coach'     THEN 2
         WHEN 'watch'     THEN 3
         WHEN 'solid'     THEN 4
         WHEN 'excellent' THEN 5
       END))[1]
  FROM engineer_monthly_score_card_r2846 s
  GROUP BY s.engineer_code
  ORDER BY ROUND(AVG(s.variance)::numeric, 2) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_engineer_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_engineer_rollup() TO authenticated;

-- RPC 4: Dimension breakdown
DROP FUNCTION IF EXISTS founder_r2846_dimension_breakdown();
CREATE OR REPLACE FUNCTION founder_r2846_dimension_breakdown()
RETURNS TABLE (
  dimension     text,
  rows_count    int,
  avg_score     numeric,
  avg_variance  numeric,
  worst_score   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.dimension,
    COUNT(*)::int,
    ROUND(AVG(s.raw_score)::numeric, 2),
    ROUND(AVG(s.variance)::numeric, 2),
    MIN(s.raw_score)
  FROM engineer_monthly_score_card_r2846 s
  GROUP BY s.dimension
  ORDER BY ROUND(AVG(s.variance)::numeric, 2) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_dimension_breakdown() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_dimension_breakdown() TO authenticated;

-- RPC 5: Intervention queue
DROP FUNCTION IF EXISTS founder_r2846_intervention_queue();
CREATE OR REPLACE FUNCTION founder_r2846_intervention_queue()
RETURNS TABLE (
  intervention_id    uuid,
  engineer_code      text,
  engineer_name      text,
  dimension          text,
  intervention_type  text,
  owner              text,
  due_date           date,
  status             text,
  outcome_note       text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    s.engineer_code,
    s.engineer_name,
    s.dimension,
    i.intervention_type,
    i.owner,
    i.due_date,
    i.status,
    i.outcome_note
  FROM engineer_score_card_interventions_r2846 i
  JOIN engineer_monthly_score_card_r2846 s ON s.id = i.card_id
  ORDER BY
    CASE i.status WHEN 'open' THEN 1 WHEN 'in_progress' THEN 2 WHEN 'blocked' THEN 3 WHEN 'completed' THEN 4 WHEN 'cancelled' THEN 5 END,
    i.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_intervention_queue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_intervention_queue() TO authenticated;

-- RPC 6: Verdict mix
DROP FUNCTION IF EXISTS founder_r2846_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2846_verdict_mix()
RETURNS TABLE (
  verdict     text,
  rows_count  int,
  share_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_monthly_score_card_r2846;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT
    s.verdict,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric * 100.0) / total, 1)
  FROM engineer_monthly_score_card_r2846 s
  GROUP BY s.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_verdict_mix() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_verdict_mix() TO authenticated;

-- RPC 7: Top negative variance rows
DROP FUNCTION IF EXISTS founder_r2846_worst_variance(int);
CREATE OR REPLACE FUNCTION founder_r2846_worst_variance(p_limit int DEFAULT 5)
RETURNS TABLE (
  engineer_code  text,
  engineer_name  text,
  job_code       text,
  dimension      text,
  raw_score      numeric,
  cohort_median  numeric,
  variance       numeric,
  verdict        text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_code, s.engineer_name, s.job_code, s.dimension,
    s.raw_score, s.cohort_median, s.variance, s.verdict
  FROM engineer_monthly_score_card_r2846 s
  ORDER BY s.variance ASC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_worst_variance(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_worst_variance(int) TO authenticated;

-- RPC 8: Intervention status counts
DROP FUNCTION IF EXISTS founder_r2846_intervention_status_counts();
CREATE OR REPLACE FUNCTION founder_r2846_intervention_status_counts()
RETURNS TABLE (
  status      text,
  rows_count  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.status, COUNT(*)::int
  FROM engineer_score_card_interventions_r2846 i
  GROUP BY i.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2846_intervention_status_counts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2846_intervention_status_counts() TO authenticated;

COMMIT;