BEGIN;

-- ============================================================================
-- Round r2803 — Hospital Chain Quarterly Clinical Workflow Bottleneck
-- HEAVY ★★★★ founder console: chain × workflow × bottleneck × impact × fix × outcome
-- ============================================================================

-- Table 1: workflow bottleneck inventory per chain per quarter
CREATE TABLE IF NOT EXISTS chain_clinical_workflow_bottlenecks_r2803 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter text NOT NULL,
  workflow_area text NOT NULL CHECK (workflow_area IN ('emergency','surgery','imaging','dialysis','icu','obstetrics','outpatient','sterilization')),
  bottleneck_summary text NOT NULL,
  patient_throughput_drop_pct numeric(5,2) NOT NULL,
  avg_extra_wait_minutes integer NOT NULL,
  monthly_revenue_at_risk_rupees bigint NOT NULL,
  root_cause text NOT NULL CHECK (root_cause IN ('equipment_aging','spare_unavailable','calibration_lag','technician_skill','vendor_sla','power_quality','consumable_supply')),
  our_equipment_fix text NOT NULL,
  fix_status text NOT NULL CHECK (fix_status IN ('proposed','accepted','in_install','operational','expanded')),
  outcome_throughput_recovery_pct numeric(5,2),
  noted_on date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_clinical_workflow_bottlenecks_r2803 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON chain_clinical_workflow_bottlenecks_r2803;
CREATE POLICY founder_all ON chain_clinical_workflow_bottlenecks_r2803 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_clinical_workflow_bottlenecks_r2803
  (chain_name, quarter, workflow_area, bottleneck_summary, patient_throughput_drop_pct, avg_extra_wait_minutes, monthly_revenue_at_risk_rupees, root_cause, our_equipment_fix, fix_status, outcome_throughput_recovery_pct, noted_on)
VALUES
  ('Apollo Hospitals', 'Q1-2026', 'emergency', 'defib unit fails self-test 3x per week, ER trauma cases delayed', 18.5, 22, 4200000, 'equipment_aging', 'replace 8 defib units with refurb-A grade + AMC tier-2', 'operational', 16.0, '2026-01-12'::date),
  ('Fortis Healthcare', 'Q1-2026', 'imaging', 'CT scanner downtime 14h/week, oncology workflow stalled', 24.0, 95, 7800000, 'spare_unavailable', 'bonded spare tube + 4h response AMC tier-1', 'in_install', NULL, '2026-01-18'::date),
  ('Manipal Hospitals', 'Q1-2026', 'surgery', 'OT lights flicker mid-procedure, surgeons abort 6 cases/month', 12.5, 45, 3600000, 'power_quality', 'install LED OT lights with UPS + monthly PM', 'accepted', NULL, '2026-01-22'::date),
  ('Max Healthcare', 'Q4-2025', 'dialysis', 'dialysis machines fail mid-session, 3 patients hospitalized', 30.0, 0, 5400000, 'calibration_lag', 'quarterly calibration contract + RO water QA', 'expanded', 28.0, '2025-12-08'::date),
  ('Narayana Health', 'Q1-2026', 'icu', 'ventilator alarm desensitization, near-miss incidents up 40%', 8.0, 0, 2900000, 'technician_skill', 'vendor-led ventilator training + alarm protocol overhaul', 'operational', 7.5, '2026-02-02'::date),
  ('AIIMS Regional', 'Q1-2026', 'obstetrics', 'fetal monitor accuracy drift, 2 missed distress calls', 6.0, 0, 1800000, 'calibration_lag', 'replace 12 fetal monitors + 6-month calibration cycle', 'proposed', NULL, '2026-02-14'::date),
  ('Yashoda Hospitals', 'Q1-2026', 'sterilization', 'autoclave cycle failures, surgery scheduling chaos', 15.0, 60, 3300000, 'equipment_aging', 'swap 4 autoclaves + spore-test compliance package', 'in_install', NULL, '2026-02-20'::date);

CREATE INDEX IF NOT EXISTS idx_chain_workflow_bottleneck_r2803_chain
  ON chain_clinical_workflow_bottlenecks_r2803(chain_name, quarter);

-- Table 2: chain × workflow outcome scorecard
CREATE TABLE IF NOT EXISTS chain_workflow_outcome_scorecard_r2803 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  workflow_area text NOT NULL CHECK (workflow_area IN ('emergency','surgery','imaging','dialysis','icu','obstetrics','outpatient','sterilization')),
  quarter text NOT NULL,
  pre_fix_throughput_per_day integer NOT NULL,
  post_fix_throughput_per_day integer,
  pre_fix_downtime_hours_month numeric(6,2) NOT NULL,
  post_fix_downtime_hours_month numeric(6,2),
  patient_satisfaction_pre numeric(4,2) NOT NULL,
  patient_satisfaction_post numeric(4,2),
  clinical_incident_count_pre integer NOT NULL,
  clinical_incident_count_post integer,
  estimated_revenue_recovery_rupees bigint,
  expansion_signal text NOT NULL CHECK (expansion_signal IN ('cold','warm','hot','expanded','reference_account')),
  recorded_on date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_workflow_outcome_scorecard_r2803 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON chain_workflow_outcome_scorecard_r2803;
CREATE POLICY founder_all ON chain_workflow_outcome_scorecard_r2803 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_workflow_outcome_scorecard_r2803
  (chain_name, workflow_area, quarter, pre_fix_throughput_per_day, post_fix_throughput_per_day, pre_fix_downtime_hours_month, post_fix_downtime_hours_month, patient_satisfaction_pre, patient_satisfaction_post, clinical_incident_count_pre, clinical_incident_count_post, estimated_revenue_recovery_rupees, expansion_signal, recorded_on)
VALUES
  ('Apollo Hospitals', 'emergency', 'Q1-2026', 120, 145, 38.5, 6.2, 3.40, 4.30, 8, 2, 3800000, 'expanded', '2026-03-15'::date),
  ('Max Healthcare', 'dialysis', 'Q4-2025', 48, 64, 22.0, 3.5, 3.60, 4.50, 5, 0, 5100000, 'reference_account', '2026-01-20'::date),
  ('Narayana Health', 'icu', 'Q1-2026', 24, 26, 12.0, 4.0, 3.80, 4.40, 6, 1, 2700000, 'hot', '2026-03-08'::date),
  ('Fortis Healthcare', 'imaging', 'Q1-2026', 36, NULL, 56.0, NULL, 3.20, NULL, 4, NULL, NULL, 'warm', '2026-03-18'::date),
  ('Manipal Hospitals', 'surgery', 'Q1-2026', 18, NULL, 18.0, NULL, 3.70, NULL, 6, NULL, NULL, 'warm', '2026-03-12'::date),
  ('AIIMS Regional', 'obstetrics', 'Q1-2026', 22, NULL, 8.0, NULL, 3.90, NULL, 2, NULL, NULL, 'cold', '2026-03-20'::date),
  ('Yashoda Hospitals', 'sterilization', 'Q1-2026', 32, NULL, 24.0, NULL, 3.50, NULL, 4, NULL, NULL, 'warm', '2026-03-22'::date);

CREATE INDEX IF NOT EXISTS idx_chain_scorecard_r2803_chain
  ON chain_workflow_outcome_scorecard_r2803(chain_name, workflow_area);

-- ============================================================================
-- RPCs (all SECURITY DEFINER, founder-gated)
-- ============================================================================

-- RPC 1: bottleneck inventory ordered by revenue at risk
DROP FUNCTION IF EXISTS rpc_r2803_bottleneck_inventory();
CREATE OR REPLACE FUNCTION rpc_r2803_bottleneck_inventory()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter text,
  workflow_area text,
  bottleneck_summary text,
  patient_throughput_drop_pct numeric,
  avg_extra_wait_minutes integer,
  monthly_revenue_at_risk_rupees bigint,
  root_cause text,
  our_equipment_fix text,
  fix_status text,
  outcome_throughput_recovery_pct numeric,
  noted_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.chain_name, b.quarter, b.workflow_area, b.bottleneck_summary,
           b.patient_throughput_drop_pct, b.avg_extra_wait_minutes,
           b.monthly_revenue_at_risk_rupees, b.root_cause, b.our_equipment_fix,
           b.fix_status, b.outcome_throughput_recovery_pct, b.noted_on
    FROM chain_clinical_workflow_bottlenecks_r2803 b
    ORDER BY b.monthly_revenue_at_risk_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_bottleneck_inventory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_bottleneck_inventory() TO authenticated;

-- RPC 2: top-level KPIs
DROP FUNCTION IF EXISTS rpc_r2803_kpi_summary();
CREATE OR REPLACE FUNCTION rpc_r2803_kpi_summary()
RETURNS TABLE (
  total_chains integer,
  total_bottlenecks integer,
  total_revenue_at_risk_rupees bigint,
  operational_fixes integer,
  in_install_fixes integer,
  proposed_fixes integer,
  avg_throughput_drop_pct numeric,
  avg_recovery_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(DISTINCT chain_name)::int FROM chain_clinical_workflow_bottlenecks_r2803),
      (SELECT COUNT(*)::int FROM chain_clinical_workflow_bottlenecks_r2803),
      (SELECT COALESCE(SUM(monthly_revenue_at_risk_rupees),0)::bigint FROM chain_clinical_workflow_bottlenecks_r2803),
      (SELECT COUNT(*)::int FROM chain_clinical_workflow_bottlenecks_r2803 WHERE fix_status IN ('operational','expanded')),
      (SELECT COUNT(*)::int FROM chain_clinical_workflow_bottlenecks_r2803 WHERE fix_status = 'in_install'),
      (SELECT COUNT(*)::int FROM chain_clinical_workflow_bottlenecks_r2803 WHERE fix_status = 'proposed'),
      (SELECT COALESCE(ROUND(AVG(patient_throughput_drop_pct)::numeric, 2), 0) FROM chain_clinical_workflow_bottlenecks_r2803),
      (SELECT COALESCE(ROUND(AVG(outcome_throughput_recovery_pct)::numeric, 2), 0) FROM chain_clinical_workflow_bottlenecks_r2803 WHERE outcome_throughput_recovery_pct IS NOT NULL);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_kpi_summary() TO authenticated;

-- RPC 3: bottleneck rollup by workflow area
DROP FUNCTION IF EXISTS rpc_r2803_workflow_area_rollup();
CREATE OR REPLACE FUNCTION rpc_r2803_workflow_area_rollup()
RETURNS TABLE (
  workflow_area text,
  bottleneck_count integer,
  total_revenue_at_risk_rupees bigint,
  avg_throughput_drop_pct numeric,
  operational_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.workflow_area,
           COUNT(*)::int,
           COALESCE(SUM(b.monthly_revenue_at_risk_rupees),0)::bigint,
           ROUND(AVG(b.patient_throughput_drop_pct)::numeric, 2),
           COUNT(*) FILTER (WHERE b.fix_status IN ('operational','expanded'))::int
    FROM chain_clinical_workflow_bottlenecks_r2803 b
    GROUP BY b.workflow_area
    ORDER BY SUM(b.monthly_revenue_at_risk_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_workflow_area_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_workflow_area_rollup() TO authenticated;

-- RPC 4: chain-level rollup
DROP FUNCTION IF EXISTS rpc_r2803_chain_rollup();
CREATE OR REPLACE FUNCTION rpc_r2803_chain_rollup()
RETURNS TABLE (
  chain_name text,
  bottleneck_count integer,
  total_revenue_at_risk_rupees bigint,
  avg_throughput_drop_pct numeric,
  fixes_operational integer,
  fixes_pending integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.chain_name,
           COUNT(*)::int,
           COALESCE(SUM(b.monthly_revenue_at_risk_rupees),0)::bigint,
           ROUND(AVG(b.patient_throughput_drop_pct)::numeric, 2),
           COUNT(*) FILTER (WHERE b.fix_status IN ('operational','expanded'))::int,
           COUNT(*) FILTER (WHERE b.fix_status IN ('proposed','accepted','in_install'))::int
    FROM chain_clinical_workflow_bottlenecks_r2803 b
    GROUP BY b.chain_name
    ORDER BY SUM(b.monthly_revenue_at_risk_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_chain_rollup() TO authenticated;

-- RPC 5: outcome scorecard
DROP FUNCTION IF EXISTS rpc_r2803_outcome_scorecard();
CREATE OR REPLACE FUNCTION rpc_r2803_outcome_scorecard()
RETURNS TABLE (
  id uuid,
  chain_name text,
  workflow_area text,
  quarter text,
  pre_fix_throughput_per_day integer,
  post_fix_throughput_per_day integer,
  pre_fix_downtime_hours_month numeric,
  post_fix_downtime_hours_month numeric,
  patient_satisfaction_pre numeric,
  patient_satisfaction_post numeric,
  clinical_incident_count_pre integer,
  clinical_incident_count_post integer,
  estimated_revenue_recovery_rupees bigint,
  expansion_signal text,
  recorded_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.workflow_area, s.quarter,
           s.pre_fix_throughput_per_day, s.post_fix_throughput_per_day,
           s.pre_fix_downtime_hours_month, s.post_fix_downtime_hours_month,
           s.patient_satisfaction_pre, s.patient_satisfaction_post,
           s.clinical_incident_count_pre, s.clinical_incident_count_post,
           s.estimated_revenue_recovery_rupees, s.expansion_signal, s.recorded_on
    FROM chain_workflow_outcome_scorecard_r2803 s
    ORDER BY COALESCE(s.estimated_revenue_recovery_rupees, 0) DESC, s.recorded_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_outcome_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_outcome_scorecard() TO authenticated;

-- RPC 6: expansion signal rollup
DROP FUNCTION IF EXISTS rpc_r2803_expansion_signal_rollup();
CREATE OR REPLACE FUNCTION rpc_r2803_expansion_signal_rollup()
RETURNS TABLE (
  expansion_signal text,
  chain_count integer,
  total_revenue_recovery_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.expansion_signal,
           COUNT(DISTINCT s.chain_name)::int,
           COALESCE(SUM(s.estimated_revenue_recovery_rupees), 0)::bigint
    FROM chain_workflow_outcome_scorecard_r2803 s
    GROUP BY s.expansion_signal
    ORDER BY SUM(s.estimated_revenue_recovery_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_expansion_signal_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_expansion_signal_rollup() TO authenticated;

-- RPC 7: root cause rollup
DROP FUNCTION IF EXISTS rpc_r2803_root_cause_rollup();
CREATE OR REPLACE FUNCTION rpc_r2803_root_cause_rollup()
RETURNS TABLE (
  root_cause text,
  occurrences integer,
  total_revenue_at_risk_rupees bigint,
  avg_wait_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.root_cause,
           COUNT(*)::int,
           COALESCE(SUM(b.monthly_revenue_at_risk_rupees), 0)::bigint,
           ROUND(AVG(b.avg_extra_wait_minutes)::numeric, 1)
    FROM chain_clinical_workflow_bottlenecks_r2803 b
    GROUP BY b.root_cause
    ORDER BY SUM(b.monthly_revenue_at_risk_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_root_cause_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_root_cause_rollup() TO authenticated;

-- RPC 8: outcome delta computed view (throughput uplift + downtime reduction)
DROP FUNCTION IF EXISTS rpc_r2803_outcome_delta();
CREATE OR REPLACE FUNCTION rpc_r2803_outcome_delta()
RETURNS TABLE (
  chain_name text,
  workflow_area text,
  throughput_delta_pct numeric,
  downtime_reduction_pct numeric,
  satisfaction_delta numeric,
  incident_reduction integer,
  expansion_signal text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name,
           s.workflow_area,
           CASE WHEN s.post_fix_throughput_per_day IS NULL OR s.pre_fix_throughput_per_day = 0 THEN NULL
                ELSE ROUND(((s.post_fix_throughput_per_day - s.pre_fix_throughput_per_day)::numeric / s.pre_fix_throughput_per_day) * 100, 2)
           END,
           CASE WHEN s.post_fix_downtime_hours_month IS NULL OR s.pre_fix_downtime_hours_month = 0 THEN NULL
                ELSE ROUND(((s.pre_fix_downtime_hours_month - s.post_fix_downtime_hours_month) / s.pre_fix_downtime_hours_month) * 100, 2)
           END,
           CASE WHEN s.patient_satisfaction_post IS NULL THEN NULL
                ELSE ROUND((s.patient_satisfaction_post - s.patient_satisfaction_pre)::numeric, 2)
           END,
           CASE WHEN s.clinical_incident_count_post IS NULL THEN NULL
                ELSE (s.clinical_incident_count_pre - s.clinical_incident_count_post)
           END,
           s.expansion_signal
    FROM chain_workflow_outcome_scorecard_r2803 s
    ORDER BY s.chain_name, s.workflow_area;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2803_outcome_delta() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2803_outcome_delta() TO authenticated;

COMMIT;
