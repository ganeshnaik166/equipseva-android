BEGIN;

-- ============================================================================
-- Round 2704: Customer Monthly Spare Part Substitution Quality
-- ============================================================================

-- Drop existing objects
DROP TABLE IF EXISTS spare_part_substitution_events_r2704 CASCADE;
DROP TABLE IF EXISTS spare_part_substitution_feedback_r2704 CASCADE;

-- ----------------------------------------------------------------------------
-- Table 1: Substitution events
-- ----------------------------------------------------------------------------
CREATE TABLE spare_part_substitution_events_r2704 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_month date NOT NULL,
  customer_org text NOT NULL,
  equipment_model text NOT NULL,
  original_part_sku text NOT NULL,
  original_part_name text NOT NULL,
  substitute_part_sku text NOT NULL,
  substitute_part_name text NOT NULL,
  substitute_source text NOT NULL CHECK (substitute_source IN ('oem_alt','third_party','refurb','local_fab')),
  fit_quality text NOT NULL CHECK (fit_quality IN ('exact','acceptable','poor','failed')),
  performance_delta_pct numeric(6,2) NOT NULL,
  cost_savings_rupees integer NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('approved_recurring','approved_one_off','rejected','watchlist')),
  approved_by_engineer text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE spare_part_substitution_events_r2704 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON spare_part_substitution_events_r2704;
CREATE POLICY founder_all ON spare_part_substitution_events_r2704
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO spare_part_substitution_events_r2704
  (event_month, customer_org, equipment_model, original_part_sku, original_part_name, substitute_part_sku, substitute_part_name, substitute_source, fit_quality, performance_delta_pct, cost_savings_rupees, verdict, approved_by_engineer)
VALUES
  ('2026-06-01'::date,'Apollo Jubilee','GE Vivid E95','GE-PROBE-M5Sc','M5Sc Cardiac Probe','SONO-M5SC-ALT','Sonohealth M5Sc Alt','oem_alt','exact',-1.20,180000,'approved_recurring','Ravi K'),
  ('2026-06-01'::date,'KIMS Secunderabad','Philips Azurion 7','PHIL-DET-FD20','FD20 Flat Detector','TPL-FD20-REFURB','Toshiba Refurb FD20','refurb','acceptable',-4.50,420000,'approved_one_off','Suresh M'),
  ('2026-06-01'::date,'Fortis Bangalore','Siemens Magnetom','SIE-GRAD-AMP','Gradient Amp Module','LOCAL-GRAD-FAB','Local Fab Gradient','local_fab','poor',-12.80,95000,'watchlist','Anand P'),
  ('2026-06-01'::date,'Medanta Gurugram','GE Discovery CT','GE-XRAY-TUBE','X-Ray Tube Assembly','VARIAN-TUBE-COMP','Varian Compatible','third_party','exact',0.50,275000,'approved_recurring','Deepak J'),
  ('2026-06-01'::date,'AIIMS Delhi','Philips Ingenia','PHIL-RF-COIL','RF Body Coil','GENERIC-RF-COIL','Generic RF Coil','third_party','failed',-28.40,45000,'rejected','Priya N'),
  ('2026-06-01'::date,'Manipal Whitefield','Mindray DC-70','MIN-PROBE-L12','L12 Linear Probe','ALPI-L12-CLONE','Alpinion L12 Clone','third_party','acceptable',-3.10,62000,'approved_one_off','Kavya R');

-- ----------------------------------------------------------------------------
-- Table 2: Customer feedback per substitution
-- ----------------------------------------------------------------------------
CREATE TABLE spare_part_substitution_feedback_r2704 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES spare_part_substitution_events_r2704(id) ON DELETE CASCADE,
  feedback_month date NOT NULL,
  customer_contact text NOT NULL,
  customer_role text NOT NULL CHECK (customer_role IN ('biomed_engineer','radiologist','procurement_head','operations_director')),
  satisfaction_score integer NOT NULL CHECK (satisfaction_score BETWEEN 1 AND 10),
  would_repeat boolean NOT NULL,
  reported_issues text NOT NULL,
  follow_up_required boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE spare_part_substitution_feedback_r2704 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON spare_part_substitution_feedback_r2704;
CREATE POLICY founder_all ON spare_part_substitution_feedback_r2704
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO spare_part_substitution_feedback_r2704
  (event_id, feedback_month, customer_contact, customer_role, satisfaction_score, would_repeat, reported_issues, follow_up_required)
SELECT id, '2026-06-15'::date, 'Dr. Rao', 'biomed_engineer', 9, true, 'None. Performs identical to OEM.', false
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'GE-PROBE-M5Sc'
UNION ALL
SELECT id, '2026-06-15'::date, 'Mr. Iyer', 'procurement_head', 8, true, 'Minor calibration drift after 200 scans.', true
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'PHIL-DET-FD20'
UNION ALL
SELECT id, '2026-06-15'::date, 'Dr. Bose', 'radiologist', 4, false, 'Image quality noticeably degraded on T2 sequences.', true
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'SIE-GRAD-AMP'
UNION ALL
SELECT id, '2026-06-15'::date, 'Mr. Khanna', 'operations_director', 10, true, 'Excellent. Cost savings without compromise.', false
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'GE-XRAY-TUBE'
UNION ALL
SELECT id, '2026-06-15'::date, 'Dr. Mehta', 'radiologist', 2, false, 'SNR collapsed. Reverted within 48 hours.', true
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'PHIL-RF-COIL'
UNION ALL
SELECT id, '2026-06-15'::date, 'Ms. Shetty', 'biomed_engineer', 7, true, 'Acceptable but slight resolution loss noted.', false
  FROM spare_part_substitution_events_r2704 WHERE original_part_sku = 'MIN-PROBE-L12';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS r2704_overview_kpis();
CREATE FUNCTION r2704_overview_kpis()
RETURNS TABLE(total_events integer, approved_recurring integer, rejected integer, total_savings_rupees bigint, avg_satisfaction numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM spare_part_substitution_events_r2704),
    (SELECT COUNT(*)::int FROM spare_part_substitution_events_r2704 WHERE verdict = 'approved_recurring'),
    (SELECT COUNT(*)::int FROM spare_part_substitution_events_r2704 WHERE verdict = 'rejected'),
    (SELECT COALESCE(SUM(cost_savings_rupees),0)::bigint FROM spare_part_substitution_events_r2704),
    (SELECT COALESCE(AVG(satisfaction_score),0)::numeric(4,2) FROM spare_part_substitution_feedback_r2704);
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_overview_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_overview_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2704_events_list();
CREATE FUNCTION r2704_events_list()
RETURNS TABLE(id uuid, event_month date, customer_org text, equipment_model text, original_part_name text, substitute_part_name text, substitute_source text, fit_quality text, performance_delta_pct numeric, cost_savings_rupees integer, verdict text, approved_by_engineer text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_month, e.customer_org, e.equipment_model, e.original_part_name, e.substitute_part_name,
         e.substitute_source, e.fit_quality, e.performance_delta_pct, e.cost_savings_rupees, e.verdict, e.approved_by_engineer
  FROM spare_part_substitution_events_r2704 e
  ORDER BY e.cost_savings_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_events_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_events_list() TO authenticated;

DROP FUNCTION IF EXISTS r2704_feedback_list();
CREATE FUNCTION r2704_feedback_list()
RETURNS TABLE(id uuid, customer_org text, equipment_model text, substitute_part_name text, customer_contact text, customer_role text, satisfaction_score integer, would_repeat boolean, reported_issues text, follow_up_required boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, e.customer_org, e.equipment_model, e.substitute_part_name, f.customer_contact, f.customer_role,
         f.satisfaction_score, f.would_repeat, f.reported_issues, f.follow_up_required
  FROM spare_part_substitution_feedback_r2704 f
  JOIN spare_part_substitution_events_r2704 e ON e.id = f.event_id
  ORDER BY f.satisfaction_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_feedback_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_feedback_list() TO authenticated;

DROP FUNCTION IF EXISTS r2704_fit_quality_breakdown();
CREATE FUNCTION r2704_fit_quality_breakdown()
RETURNS TABLE(fit_quality text, count integer, avg_savings_rupees bigint, avg_satisfaction numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.fit_quality, COUNT(*)::int,
         COALESCE(AVG(e.cost_savings_rupees),0)::bigint,
         COALESCE(AVG(f.satisfaction_score),0)::numeric(4,2)
  FROM spare_part_substitution_events_r2704 e
  LEFT JOIN spare_part_substitution_feedback_r2704 f ON f.event_id = e.id
  GROUP BY e.fit_quality
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_fit_quality_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_fit_quality_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2704_source_performance();
CREATE FUNCTION r2704_source_performance()
RETURNS TABLE(substitute_source text, events_count integer, total_savings_rupees bigint, avg_performance_delta numeric, approval_rate_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.substitute_source, COUNT(*)::int,
         COALESCE(SUM(e.cost_savings_rupees),0)::bigint,
         COALESCE(AVG(e.performance_delta_pct),0)::numeric(6,2),
         (COUNT(*) FILTER (WHERE e.verdict IN ('approved_recurring','approved_one_off'))::numeric * 100.0 / NULLIF(COUNT(*),0))::numeric(5,2)
  FROM spare_part_substitution_events_r2704 e
  GROUP BY e.substitute_source
  ORDER BY total_savings_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_source_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_source_performance() TO authenticated;

DROP FUNCTION IF EXISTS r2704_followup_required();
CREATE FUNCTION r2704_followup_required()
RETURNS TABLE(id uuid, customer_org text, equipment_model text, substitute_part_name text, satisfaction_score integer, reported_issues text, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, e.customer_org, e.equipment_model, e.substitute_part_name, f.satisfaction_score, f.reported_issues, e.verdict
  FROM spare_part_substitution_feedback_r2704 f
  JOIN spare_part_substitution_events_r2704 e ON e.id = f.event_id
  WHERE f.follow_up_required = true
  ORDER BY f.satisfaction_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_followup_required() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_followup_required() TO authenticated;

DROP FUNCTION IF EXISTS r2704_top_savings_customers();
CREATE FUNCTION r2704_top_savings_customers()
RETURNS TABLE(customer_org text, events_count integer, total_savings_rupees bigint, avg_satisfaction numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.customer_org, COUNT(*)::int,
         COALESCE(SUM(e.cost_savings_rupees),0)::bigint,
         COALESCE(AVG(f.satisfaction_score),0)::numeric(4,2)
  FROM spare_part_substitution_events_r2704 e
  LEFT JOIN spare_part_substitution_feedback_r2704 f ON f.event_id = e.id
  GROUP BY e.customer_org
  ORDER BY total_savings_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_top_savings_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_top_savings_customers() TO authenticated;

DROP FUNCTION IF EXISTS r2704_verdict_distribution();
CREATE FUNCTION r2704_verdict_distribution()
RETURNS TABLE(verdict text, count integer, total_savings_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.verdict, COUNT(*)::int, COALESCE(SUM(e.cost_savings_rupees),0)::bigint
  FROM spare_part_substitution_events_r2704 e
  GROUP BY e.verdict
  ORDER BY count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2704_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2704_verdict_distribution() TO authenticated;

COMMIT;
