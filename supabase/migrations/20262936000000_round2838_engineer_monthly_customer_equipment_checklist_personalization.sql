BEGIN;

-- ============================================================================
-- Round 2838 — Engineer × Monthly × Customer × Equipment Checklist Personalization
-- HEAVY ★★★★ founder console
-- Tracks per-engineer, per-customer, per-equipment custom checklists with
-- monthly variance and outcome scoring.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: engineer_customer_equipment_checklist_r2838
-- One row per engineer × customer × equipment × month × custom-checklist
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_customer_equipment_checklist_r2838 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  engineer_name text NOT NULL,
  customer_name text NOT NULL,
  equipment_label text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','life_support','lab','dental','sterilization','monitoring')),
  baseline_checklist_items integer NOT NULL CHECK (baseline_checklist_items >= 0),
  customized_checklist_items integer NOT NULL CHECK (customized_checklist_items >= 0),
  items_added integer NOT NULL CHECK (items_added >= 0),
  items_removed integer NOT NULL CHECK (items_removed >= 0),
  items_modified integer NOT NULL CHECK (items_modified >= 0),
  personalization_reason text NOT NULL CHECK (personalization_reason IN ('customer_request','equipment_age','site_constraint','past_incident','warranty_clause','engineer_judgement')),
  variance_score numeric(5,2) NOT NULL CHECK (variance_score >= 0 AND variance_score <= 100),
  outcome_quality text NOT NULL CHECK (outcome_quality IN ('excellent','good','acceptable','poor','failed')),
  customer_csat numeric(3,2) NOT NULL CHECK (customer_csat >= 0 AND customer_csat <= 5),
  rework_required boolean NOT NULL DEFAULT false,
  approved_by_supervisor boolean NOT NULL DEFAULT false,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_customer_equipment_checklist_r2838 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_customer_equipment_checklist_r2838;
CREATE POLICY founder_all ON engineer_customer_equipment_checklist_r2838 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_customer_equipment_checklist_r2838
  (cycle_month, engineer_name, customer_name, equipment_label, equipment_category, baseline_checklist_items, customized_checklist_items, items_added, items_removed, items_modified, personalization_reason, variance_score, outcome_quality, customer_csat, rework_required, approved_by_supervisor, notes)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 'Apollo Hyd', 'GE Vivid E95 Echo', 'imaging', 24, 31, 9, 2, 4, 'customer_request', 47.50, 'excellent', 4.80, false, true, 'Hospital added probe disinfection extra steps'),
  ('2026-06-01'::date, 'Priya Sharma', 'KIMS Secunderabad', 'Philips IntelliVue MX800', 'monitoring', 18, 22, 5, 1, 2, 'past_incident', 31.25, 'good', 4.50, false, true, 'Added battery swap drill after Apr outage'),
  ('2026-06-01'::date, 'Anand Reddy', 'Yashoda Somajiguda', 'Drager Fabius Tiro Anesthesia', 'life_support', 32, 29, 1, 4, 3, 'engineer_judgement', 25.00, 'acceptable', 4.10, true, false, 'Engineer dropped 4 obsolete checks — needs supervisor sign-off'),
  ('2026-06-01'::date, 'Suresh Babu', 'Continental Hospitals', 'Sysmex XN-1000 Hematology', 'lab', 21, 26, 6, 1, 3, 'warranty_clause', 38.10, 'excellent', 4.90, false, true, 'Warranty mandates calibration log capture'),
  ('2026-06-01'::date, 'Lakshmi Devi', 'Sunshine Hospital', 'Planmeca Promax Dental CBCT', 'dental', 19, 24, 6, 2, 3, 'site_constraint', 42.10, 'good', 4.40, false, true, 'Tight room — repositioning checks added'),
  ('2026-06-01'::date, 'Karthik Iyer', 'Care Hospitals Banjara', 'Steris Amsco V-Pro Sterilizer', 'sterilization', 28, 35, 8, 1, 4, 'customer_request', 46.43, 'excellent', 4.85, false, true, 'NABH audit driving extra biological indicator checks'),
  ('2026-06-01'::date, 'Meena Joshi', 'AIG Hospitals', 'GE Healthcare CT Revolution', 'imaging', 36, 31, 2, 6, 5, 'equipment_age', 36.11, 'poor', 3.20, true, false, 'Aged unit — engineer skipped checks that no longer apply; needs review'),
  ('2026-06-01'::date, 'Vijay Sharma', 'Rainbow Children Hyd', 'Mindray BeneVision N22', 'monitoring', 17, 21, 4, 1, 2, 'customer_request', 35.29, 'good', 4.60, false, true, 'Pediatric thresholds personalized per ward')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Table 2: engineer_checklist_outcome_audit_r2838
-- Variance-to-outcome correlation audit; founder-level oversight rows
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_checklist_outcome_audit_r2838 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_month date NOT NULL,
  engineer_name text NOT NULL,
  total_personalizations integer NOT NULL CHECK (total_personalizations >= 0),
  avg_variance numeric(5,2) NOT NULL CHECK (avg_variance >= 0 AND avg_variance <= 100),
  avg_csat numeric(3,2) NOT NULL CHECK (avg_csat >= 0 AND avg_csat <= 5),
  rework_rate_pct numeric(5,2) NOT NULL CHECK (rework_rate_pct >= 0 AND rework_rate_pct <= 100),
  supervisor_override_count integer NOT NULL CHECK (supervisor_override_count >= 0),
  founder_disposition text NOT NULL CHECK (founder_disposition IN ('approved','watch','retrain','escalate','reward')),
  recommended_action text NOT NULL,
  reviewer text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_checklist_outcome_audit_r2838 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_checklist_outcome_audit_r2838;
CREATE POLICY founder_all ON engineer_checklist_outcome_audit_r2838 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_checklist_outcome_audit_r2838
  (audit_month, engineer_name, total_personalizations, avg_variance, avg_csat, rework_rate_pct, supervisor_override_count, founder_disposition, recommended_action, reviewer)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 14, 44.20, 4.78, 0.00, 0, 'reward', 'Promote to senior tier — exemplary personalization with zero rework', 'Founder'),
  ('2026-06-01'::date, 'Priya Sharma', 11, 33.40, 4.55, 9.10, 1, 'approved', 'Maintain current portfolio; share past-incident playbook with peers', 'Founder'),
  ('2026-06-01'::date, 'Anand Reddy', 9, 28.50, 4.05, 22.20, 3, 'retrain', 'Mandatory supervisor co-sign on all life-support personalizations next month', 'Founder'),
  ('2026-06-01'::date, 'Suresh Babu', 12, 39.80, 4.88, 0.00, 0, 'reward', 'Lead the warranty-clause SOP writeup for engineer training', 'Founder'),
  ('2026-06-01'::date, 'Lakshmi Devi', 10, 41.60, 4.42, 10.00, 1, 'approved', 'Continue; document site-constraint patterns in shared playbook', 'Founder'),
  ('2026-06-01'::date, 'Karthik Iyer', 13, 45.10, 4.82, 0.00, 0, 'reward', 'Add to NABH expert reviewer pool', 'Founder'),
  ('2026-06-01'::date, 'Meena Joshi', 8, 37.50, 3.35, 37.50, 4, 'escalate', 'PIP — three rework events on aged-imaging fleet this month', 'Founder'),
  ('2026-06-01'::date, 'Vijay Sharma', 9, 34.80, 4.58, 11.10, 1, 'watch', 'Audit pediatric thresholds with clinical lead before next cycle', 'Founder')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- RPCs (7+, all SECURITY DEFINER, gated by is_founder())
-- ============================================================================

-- RPC 1: KPI roll-up
DROP FUNCTION IF EXISTS r2838_kpi_summary();
CREATE OR REPLACE FUNCTION r2838_kpi_summary()
RETURNS TABLE (
  total_personalizations bigint,
  avg_variance numeric,
  avg_csat numeric,
  rework_rate_pct numeric,
  supervisor_overrides bigint,
  excellent_outcomes bigint,
  failed_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    round(coalesce(avg(variance_score),0)::numeric, 2),
    round(coalesce(avg(customer_csat),0)::numeric, 2),
    round((count(*) FILTER (WHERE rework_required)::numeric * 100.0 / nullif(count(*),0))::numeric, 2),
    count(*) FILTER (WHERE NOT approved_by_supervisor)::bigint,
    count(*) FILTER (WHERE outcome_quality = 'excellent')::bigint,
    count(*) FILTER (WHERE outcome_quality = 'failed')::bigint
  FROM engineer_customer_equipment_checklist_r2838;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_kpi_summary() TO authenticated;

-- RPC 2: per-engineer breakdown
DROP FUNCTION IF EXISTS r2838_per_engineer_breakdown();
CREATE OR REPLACE FUNCTION r2838_per_engineer_breakdown()
RETURNS TABLE (
  engineer_name text,
  total_rows bigint,
  avg_variance numeric,
  avg_csat numeric,
  rework_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.engineer_name,
    count(*)::bigint,
    round(avg(c.variance_score)::numeric, 2),
    round(avg(c.customer_csat)::numeric, 2),
    count(*) FILTER (WHERE c.rework_required)::bigint
  FROM engineer_customer_equipment_checklist_r2838 c
  GROUP BY c.engineer_name
  ORDER BY avg(c.variance_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_per_engineer_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_per_engineer_breakdown() TO authenticated;

-- RPC 3: outcome distribution by reason
DROP FUNCTION IF EXISTS r2838_reason_outcome_matrix();
CREATE OR REPLACE FUNCTION r2838_reason_outcome_matrix()
RETURNS TABLE (
  personalization_reason text,
  total bigint,
  avg_variance numeric,
  excellent_pct numeric,
  poor_or_failed_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.personalization_reason,
    count(*)::bigint,
    round(avg(c.variance_score)::numeric, 2),
    round((count(*) FILTER (WHERE c.outcome_quality = 'excellent')::numeric * 100.0 / nullif(count(*),0))::numeric, 2),
    round((count(*) FILTER (WHERE c.outcome_quality IN ('poor','failed'))::numeric * 100.0 / nullif(count(*),0))::numeric, 2)
  FROM engineer_customer_equipment_checklist_r2838 c
  GROUP BY c.personalization_reason
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_reason_outcome_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_reason_outcome_matrix() TO authenticated;

-- RPC 4: equipment category drill
DROP FUNCTION IF EXISTS r2838_equipment_category_drill();
CREATE OR REPLACE FUNCTION r2838_equipment_category_drill()
RETURNS TABLE (
  equipment_category text,
  total bigint,
  avg_variance numeric,
  avg_csat numeric,
  rework_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.equipment_category,
    count(*)::bigint,
    round(avg(c.variance_score)::numeric, 2),
    round(avg(c.customer_csat)::numeric, 2),
    count(*) FILTER (WHERE c.rework_required)::bigint
  FROM engineer_customer_equipment_checklist_r2838 c
  GROUP BY c.equipment_category
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_equipment_category_drill() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_equipment_category_drill() TO authenticated;

-- RPC 5: recent personalizations list
DROP FUNCTION IF EXISTS r2838_recent_personalizations(integer);
CREATE OR REPLACE FUNCTION r2838_recent_personalizations(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  cycle_month date,
  engineer_name text,
  customer_name text,
  equipment_label text,
  equipment_category text,
  baseline_checklist_items integer,
  customized_checklist_items integer,
  variance_score numeric,
  outcome_quality text,
  customer_csat numeric,
  rework_required boolean,
  approved_by_supervisor boolean,
  personalization_reason text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id, c.cycle_month, c.engineer_name, c.customer_name, c.equipment_label,
    c.equipment_category, c.baseline_checklist_items, c.customized_checklist_items,
    c.variance_score, c.outcome_quality, c.customer_csat, c.rework_required,
    c.approved_by_supervisor, c.personalization_reason, c.notes
  FROM engineer_customer_equipment_checklist_r2838 c
  ORDER BY c.created_at DESC
  LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_recent_personalizations(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_recent_personalizations(integer) TO authenticated;

-- RPC 6: outcome audit rollup
DROP FUNCTION IF EXISTS r2838_outcome_audit_rollup();
CREATE OR REPLACE FUNCTION r2838_outcome_audit_rollup()
RETURNS TABLE (
  audit_month date,
  engineer_name text,
  total_personalizations integer,
  avg_variance numeric,
  avg_csat numeric,
  rework_rate_pct numeric,
  supervisor_override_count integer,
  founder_disposition text,
  recommended_action text,
  reviewer text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.audit_month, a.engineer_name, a.total_personalizations, a.avg_variance,
    a.avg_csat, a.rework_rate_pct, a.supervisor_override_count, a.founder_disposition,
    a.recommended_action, a.reviewer
  FROM engineer_checklist_outcome_audit_r2838 a
  ORDER BY a.avg_variance DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_outcome_audit_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_outcome_audit_rollup() TO authenticated;

-- RPC 7: founder disposition counts
DROP FUNCTION IF EXISTS r2838_disposition_counts();
CREATE OR REPLACE FUNCTION r2838_disposition_counts()
RETURNS TABLE (
  founder_disposition text,
  engineers bigint,
  avg_variance numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    a.founder_disposition,
    count(*)::bigint,
    round(avg(a.avg_variance)::numeric, 2),
    round(avg(a.avg_csat)::numeric, 2)
  FROM engineer_checklist_outcome_audit_r2838 a
  GROUP BY a.founder_disposition
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_disposition_counts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_disposition_counts() TO authenticated;

-- RPC 8: rework hotspots
DROP FUNCTION IF EXISTS r2838_rework_hotspots();
CREATE OR REPLACE FUNCTION r2838_rework_hotspots()
RETURNS TABLE (
  engineer_name text,
  customer_name text,
  equipment_label text,
  variance_score numeric,
  outcome_quality text,
  customer_csat numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.engineer_name, c.customer_name, c.equipment_label, c.variance_score,
    c.outcome_quality, c.customer_csat, c.notes
  FROM engineer_customer_equipment_checklist_r2838 c
  WHERE c.rework_required OR c.outcome_quality IN ('poor','failed')
  ORDER BY c.variance_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2838_rework_hotspots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2838_rework_hotspots() TO authenticated;

COMMIT;
