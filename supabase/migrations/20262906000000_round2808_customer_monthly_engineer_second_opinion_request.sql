BEGIN;

-- ============================================================================
-- Round r2808 — Customer Monthly Engineer Second Opinion Request
-- HEAVY ★★★★ founder console
-- Dimensions: job × first eng × second opinion eng × delta × consensus × outcome × learning
-- ============================================================================

-- Table 1: second opinion requests
CREATE TABLE IF NOT EXISTS customer_second_opinion_requests_r2808 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_month date NOT NULL,
  job_ref text NOT NULL,
  customer_org text NOT NULL,
  city text NOT NULL,
  equipment_kind text NOT NULL,
  first_engineer_name text NOT NULL,
  first_engineer_tier text NOT NULL CHECK (first_engineer_tier IN ('bronze','silver','gold','platinum')),
  first_diagnosis text NOT NULL,
  first_quote_rupees numeric(12,2) NOT NULL,
  second_engineer_name text NOT NULL,
  second_engineer_tier text NOT NULL CHECK (second_engineer_tier IN ('bronze','silver','gold','platinum')),
  second_diagnosis text NOT NULL,
  second_quote_rupees numeric(12,2) NOT NULL,
  delta_rupees numeric(12,2) NOT NULL,
  consensus_state text NOT NULL CHECK (consensus_state IN ('full_agree','partial_agree','disagree','escalated')),
  outcome text NOT NULL CHECK (outcome IN ('first_correct','second_correct','both_partial','panel_review','pending')),
  learning_logged boolean NOT NULL DEFAULT false,
  customer_satisfaction smallint NOT NULL CHECK (customer_satisfaction BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_second_opinion_requests_r2808 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_second_opinion_requests_r2808 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: learning catalog (root causes + corrective actions per delta)
CREATE TABLE IF NOT EXISTS second_opinion_learning_catalog_r2808 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES customer_second_opinion_requests_r2808(id) ON DELETE CASCADE,
  learning_month date NOT NULL,
  root_cause_category text NOT NULL CHECK (root_cause_category IN ('skill_gap','tool_gap','part_unavailable','process_miss','oem_manual_outdated','communication_gap')),
  root_cause_detail text NOT NULL,
  corrective_action text NOT NULL,
  owner_team text NOT NULL CHECK (owner_team IN ('training','ops','supply','quality','engineering','field')),
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  impact_avoided_rupees numeric(12,2) NOT NULL DEFAULT 0,
  due_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE second_opinion_learning_catalog_r2808 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON second_opinion_learning_catalog_r2808 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seeds
-- ============================================================================

INSERT INTO customer_second_opinion_requests_r2808
  (request_month, job_ref, customer_org, city, equipment_kind, first_engineer_name, first_engineer_tier, first_diagnosis, first_quote_rupees, second_engineer_name, second_engineer_tier, second_diagnosis, second_quote_rupees, delta_rupees, consensus_state, outcome, learning_logged, customer_satisfaction)
VALUES
  ('2026-06-01'::date, 'RJ-44011', 'Apollo Jubilee Hills', 'Hyderabad', 'X-Ray 500mA', 'Ravi Kumar', 'silver', 'Tube replacement needed', 185000.00, 'Anand Iyer', 'platinum', 'HV cable + collimator only', 42000.00, 143000.00, 'disagree', 'second_correct', true, 5),
  ('2026-06-01'::date, 'RJ-44087', 'KIMS Secunderabad', 'Hyderabad', 'Ultrasound', 'Suresh M', 'gold', 'Probe replacement', 78000.00, 'Vikram Joshi', 'gold', 'Probe replacement + recalibrate', 81000.00, 3000.00, 'full_agree', 'first_correct', false, 4),
  ('2026-06-01'::date, 'RJ-44102', 'Continental Hospitals', 'Hyderabad', 'CT Scanner', 'Karthik R', 'bronze', 'Detector card swap', 245000.00, 'Prashant Naik', 'platinum', 'Cooling pump + firmware', 67000.00, 178000.00, 'disagree', 'second_correct', true, 5),
  ('2026-06-01'::date, 'RJ-44144', 'Yashoda LB Nagar', 'Hyderabad', 'Ventilator', 'Manoj T', 'silver', 'PCB module replacement', 92000.00, 'Deepak Rao', 'gold', 'PCB module + flow sensor', 108000.00, 16000.00, 'partial_agree', 'both_partial', true, 4),
  ('2026-06-01'::date, 'RJ-44168', 'Care Banjara', 'Hyderabad', 'ECG Machine', 'Vinod K', 'gold', 'Cable harness replace', 18500.00, 'Sandeep Pillai', 'silver', 'Cable harness replace', 18500.00, 0.00, 'full_agree', 'first_correct', false, 5),
  ('2026-06-01'::date, 'RJ-44199', 'Rainbow Vikrampuri', 'Hyderabad', 'Incubator', 'Naresh G', 'bronze', 'Heater coil + sensor', 34000.00, 'Rohit Mehra', 'platinum', 'Sensor only', 6500.00, 27500.00, 'disagree', 'second_correct', true, 5),
  ('2026-06-01'::date, 'RJ-44231', 'AIG Gachibowli', 'Hyderabad', 'Anesthesia Workstation', 'Bhaskar S', 'silver', 'Vaporizer overhaul', 156000.00, 'Arjun Desai', 'gold', 'Vaporizer service + O2 cell', 88000.00, 68000.00, 'partial_agree', 'panel_review', false, 3);

INSERT INTO second_opinion_learning_catalog_r2808
  (request_id, learning_month, root_cause_category, root_cause_detail, corrective_action, owner_team, status, impact_avoided_rupees, due_date)
SELECT id, '2026-06-01'::date, 'skill_gap', 'Silver engineer cannot test HV cable in field', 'Add HV cable test module to silver-tier certification', 'training', 'in_progress', 143000.00, '2026-07-15'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44011'
UNION ALL
SELECT id, '2026-06-01'::date, 'tool_gap', 'Bronze engineer lacks CT cooling diagnostic kit', 'Issue cooling diagnostic kit to all bronze+ assigned CT jobs', 'supply', 'open', 178000.00, '2026-07-10'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44102'
UNION ALL
SELECT id, '2026-06-01'::date, 'process_miss', 'Flow sensor not in default ventilator checklist', 'Update ventilator SOP to include flow sensor verification', 'quality', 'done', 16000.00, '2026-06-30'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44144'
UNION ALL
SELECT id, '2026-06-01'::date, 'skill_gap', 'Bronze engineer overquoted incubator due to fear', 'Mentor pairing for next 5 incubator jobs', 'field', 'in_progress', 27500.00, '2026-07-20'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44199'
UNION ALL
SELECT id, '2026-06-01'::date, 'oem_manual_outdated', 'Vaporizer service manual missing O2 cell life chart', 'Request OEM updated manual; add internal addendum', 'engineering', 'open', 68000.00, '2026-08-05'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44231'
UNION ALL
SELECT id, '2026-06-01'::date, 'communication_gap', 'First engineer did not explain probe vs recalibrate trade-off', 'Add customer-facing diagnosis explainer template', 'ops', 'done', 3000.00, '2026-06-25'::date
FROM customer_second_opinion_requests_r2808 WHERE job_ref = 'RJ-44087';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2808_kpis();
CREATE OR REPLACE FUNCTION founder_r2808_kpis()
RETURNS TABLE (
  total_requests bigint,
  total_delta_rupees numeric,
  avg_delta_rupees numeric,
  disagree_count bigint,
  full_agree_count bigint,
  learning_logged_count bigint,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(delta_rupees),0)::numeric,
    COALESCE(AVG(delta_rupees),0)::numeric,
    COUNT(*) FILTER (WHERE consensus_state = 'disagree')::bigint,
    COUNT(*) FILTER (WHERE consensus_state = 'full_agree')::bigint,
    COUNT(*) FILTER (WHERE learning_logged)::bigint,
    COALESCE(AVG(customer_satisfaction),0)::numeric
  FROM customer_second_opinion_requests_r2808;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_list_requests();
CREATE OR REPLACE FUNCTION founder_r2808_list_requests()
RETURNS TABLE (
  id uuid,
  job_ref text,
  customer_org text,
  equipment_kind text,
  first_engineer_name text,
  first_quote_rupees numeric,
  second_engineer_name text,
  second_quote_rupees numeric,
  delta_rupees numeric,
  consensus_state text,
  outcome text,
  customer_satisfaction smallint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.job_ref, r.customer_org, r.equipment_kind,
         r.first_engineer_name, r.first_quote_rupees,
         r.second_engineer_name, r.second_quote_rupees,
         r.delta_rupees, r.consensus_state, r.outcome, r.customer_satisfaction
  FROM customer_second_opinion_requests_r2808 r
  ORDER BY r.delta_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_list_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_list_requests() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_consensus_breakdown();
CREATE OR REPLACE FUNCTION founder_r2808_consensus_breakdown()
RETURNS TABLE (
  consensus_state text,
  request_count bigint,
  total_delta numeric,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.consensus_state,
         COUNT(*)::bigint,
         COALESCE(SUM(r.delta_rupees),0)::numeric,
         COALESCE(AVG(r.customer_satisfaction),0)::numeric
  FROM customer_second_opinion_requests_r2808 r
  GROUP BY r.consensus_state
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_consensus_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_consensus_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_outcome_breakdown();
CREATE OR REPLACE FUNCTION founder_r2808_outcome_breakdown()
RETURNS TABLE (
  outcome text,
  request_count bigint,
  total_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.outcome,
         COUNT(*)::bigint,
         COALESCE(SUM(r.delta_rupees),0)::numeric
  FROM customer_second_opinion_requests_r2808 r
  GROUP BY r.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_outcome_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_engineer_scorecard();
CREATE OR REPLACE FUNCTION founder_r2808_engineer_scorecard()
RETURNS TABLE (
  engineer_name text,
  appearances bigint,
  first_correct_count bigint,
  total_delta_saved numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE e.was_correct)::bigint,
         COALESCE(SUM(e.delta_attributed),0)::numeric
  FROM (
    SELECT first_engineer_name AS engineer_name,
           (outcome = 'first_correct') AS was_correct,
           CASE WHEN outcome = 'first_correct' THEN delta_rupees ELSE 0 END AS delta_attributed
    FROM customer_second_opinion_requests_r2808
    UNION ALL
    SELECT second_engineer_name,
           (outcome = 'second_correct'),
           CASE WHEN outcome = 'second_correct' THEN delta_rupees ELSE 0 END
    FROM customer_second_opinion_requests_r2808
  ) e
  GROUP BY e.engineer_name
  ORDER BY COUNT(*) FILTER (WHERE e.was_correct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_engineer_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_engineer_scorecard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_learning_catalog();
CREATE OR REPLACE FUNCTION founder_r2808_learning_catalog()
RETURNS TABLE (
  id uuid,
  job_ref text,
  root_cause_category text,
  root_cause_detail text,
  corrective_action text,
  owner_team text,
  status text,
  impact_avoided_rupees numeric,
  due_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, r.job_ref, l.root_cause_category, l.root_cause_detail,
         l.corrective_action, l.owner_team, l.status, l.impact_avoided_rupees, l.due_date
  FROM second_opinion_learning_catalog_r2808 l
  JOIN customer_second_opinion_requests_r2808 r ON r.id = l.request_id
  ORDER BY l.impact_avoided_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_learning_catalog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_learning_catalog() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_root_cause_rollup();
CREATE OR REPLACE FUNCTION founder_r2808_root_cause_rollup()
RETURNS TABLE (
  root_cause_category text,
  learning_count bigint,
  total_impact numeric,
  open_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.root_cause_category,
         COUNT(*)::bigint,
         COALESCE(SUM(l.impact_avoided_rupees),0)::numeric,
         COUNT(*) FILTER (WHERE l.status = 'open')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'done')::bigint
  FROM second_opinion_learning_catalog_r2808 l
  GROUP BY l.root_cause_category
  ORDER BY SUM(l.impact_avoided_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_root_cause_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_root_cause_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2808_owner_team_load();
CREATE OR REPLACE FUNCTION founder_r2808_owner_team_load()
RETURNS TABLE (
  owner_team text,
  open_items bigint,
  in_progress_items bigint,
  done_items bigint,
  total_impact numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.owner_team,
         COUNT(*) FILTER (WHERE l.status = 'open')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'in_progress')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'done')::bigint,
         COALESCE(SUM(l.impact_avoided_rupees),0)::numeric
  FROM second_opinion_learning_catalog_r2808 l
  GROUP BY l.owner_team
  ORDER BY SUM(l.impact_avoided_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2808_owner_team_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2808_owner_team_load() TO authenticated;

COMMIT;
