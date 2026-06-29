-- Round 2895: Hospital Chain Quarterly Critical-Care Equipment Redundancy Coverage
-- HEAVY founder-ops round. Multi-branch rollup of redundancy posture for critical-care gear.

CREATE TABLE IF NOT EXISTS hospital_chain_critical_care_redundancy_coverage_r2895 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  branch_code text NOT NULL,
  city text NOT NULL,
  equipment_category text NOT NULL,
  primary_units int NOT NULL,
  backup_units int NOT NULL,
  required_redundancy_units int NOT NULL,
  quarter text NOT NULL,
  redundancy_ratio numeric(5,2) NOT NULL,
  coverage_status text NOT NULL,
  last_audit_date date NOT NULL,
  beds_served int NOT NULL,
  monthly_critical_hours int NOT NULL,
  failure_events_last_quarter int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hospital_chain_critical_care_redundancy_coverage_r2895 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS hospital_chain_redundancy_gap_remediations_r2895 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  branch_code text NOT NULL,
  equipment_category text NOT NULL,
  gap_units int NOT NULL,
  remediation_plan text NOT NULL,
  est_cost_rupees bigint NOT NULL,
  committed_close_date date NOT NULL,
  owner_email text NOT NULL,
  status text NOT NULL,
  risk_score int NOT NULL,
  amc_upsell_rupees bigint NOT NULL,
  procurement_lead_days int NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hospital_chain_redundancy_gap_remediations_r2895 ENABLE ROW LEVEL SECURITY;

INSERT INTO hospital_chain_critical_care_redundancy_coverage_r2895
(chain_name, branch_code, city, equipment_category, primary_units, backup_units, required_redundancy_units, quarter, redundancy_ratio, coverage_status, last_audit_date, beds_served, monthly_critical_hours, failure_events_last_quarter) VALUES
('Apollo','APL-HYD-JUB','Hyderabad','Ventilator',24,8,10,'Q2-2026',0.33,'gap',DATE '2026-06-12',420,8400,3),
('Apollo','APL-HYD-SEC','Hyderabad','Ventilator',18,7,8,'Q2-2026',0.39,'gap',DATE '2026-06-10',310,5800,2),
('Apollo','APL-CHN-GRM','Chennai','Defibrillator',32,16,14,'Q2-2026',0.50,'compliant',DATE '2026-06-14',560,4200,1),
('Apollo','APL-BLR-BAN','Bengaluru','Dialysis Machine',22,10,12,'Q2-2026',0.45,'gap',DATE '2026-06-08',380,6300,4),
('Manipal','MNP-BLR-OLD','Bengaluru','Ventilator',20,9,9,'Q2-2026',0.45,'compliant',DATE '2026-06-15',340,7100,2),
('Manipal','MNP-BLR-WHF','Bengaluru','Patient Monitor',60,28,24,'Q2-2026',0.47,'compliant',DATE '2026-06-13',520,9200,1),
('Manipal','MNP-MAA-VLR','Vellore','Ventilator',12,4,6,'Q2-2026',0.33,'critical_gap',DATE '2026-06-09',210,4400,5),
('Fortis','FRT-DEL-SHL','Delhi','Ventilator',26,12,12,'Q2-2026',0.46,'compliant',DATE '2026-06-11',480,8100,2),
('Fortis','FRT-MUM-MUL','Mumbai','Infusion Pump',80,32,30,'Q2-2026',0.40,'compliant',DATE '2026-06-12',610,11200,1),
('Fortis','FRT-DEL-VAS','Delhi','Defibrillator',18,6,8,'Q2-2026',0.33,'gap',DATE '2026-06-07',290,3400,3),
('Max','MAX-DEL-SAK','Delhi','Ventilator',22,10,10,'Q2-2026',0.45,'compliant',DATE '2026-06-14',410,7600,1),
('Max','MAX-DEL-PAT','Delhi','Dialysis Machine',16,5,8,'Q2-2026',0.31,'critical_gap',DATE '2026-06-09',280,5100,4),
('Narayana','NRY-BLR-HSR','Bengaluru','Ventilator',28,14,12,'Q2-2026',0.50,'compliant',DATE '2026-06-15',520,8800,1),
('Narayana','NRY-KOL-HWH','Kolkata','Patient Monitor',45,18,18,'Q2-2026',0.40,'gap',DATE '2026-06-10',430,7200,2),
('AIIMS','AIIMS-DEL-MN','Delhi','Ventilator',60,22,24,'Q2-2026',0.37,'gap',DATE '2026-06-13',1200,18400,3),
('AIIMS','AIIMS-JDP','Jodhpur','Defibrillator',24,8,10,'Q2-2026',0.33,'gap',DATE '2026-06-11',640,5600,2),
('KIMS','KIMS-HYD-SEC','Hyderabad','Ventilator',16,6,7,'Q2-2026',0.38,'gap',DATE '2026-06-08',280,4900,2),
('KIMS','KIMS-HYD-KON','Hyderabad','Infusion Pump',40,14,16,'Q2-2026',0.35,'gap',DATE '2026-06-12',310,6100,1),
('Yashoda','YSH-HYD-SOM','Hyderabad','Ventilator',20,11,9,'Q2-2026',0.55,'compliant',DATE '2026-06-14',360,6700,1),
('Yashoda','YSH-HYD-MAL','Hyderabad','Dialysis Machine',14,4,7,'Q2-2026',0.29,'critical_gap',DATE '2026-06-09',240,4200,4);

INSERT INTO hospital_chain_redundancy_gap_remediations_r2895
(chain_name, branch_code, equipment_category, gap_units, remediation_plan, est_cost_rupees, committed_close_date, owner_email, status, risk_score, amc_upsell_rupees, procurement_lead_days, notes) VALUES
('Apollo','APL-HYD-JUB','Ventilator',2,'lease + AMC bundle',2800000,DATE '2026-08-15','ops@apollo.in','in_progress',74,640000,42,'Mindray bundle'),
('Apollo','APL-HYD-SEC','Ventilator',1,'CAPEX purchase',1500000,DATE '2026-09-01','ops@apollo.in','approved',62,320000,38,'split PO'),
('Apollo','APL-BLR-BAN','Dialysis Machine',2,'refurbished + AMC',1800000,DATE '2026-08-22','biomed@apollo.in','in_progress',71,520000,30,NULL),
('Manipal','MNP-MAA-VLR','Ventilator',2,'inter-branch transfer + lease',1100000,DATE '2026-07-28','cmo@manipal.in','escalated',88,480000,21,'critical_gap escalated'),
('Fortis','FRT-DEL-VAS','Defibrillator',2,'CAPEX + training',900000,DATE '2026-08-10','ops@fortis.in','approved',58,180000,28,NULL),
('Max','MAX-DEL-PAT','Dialysis Machine',3,'lease 3-yr + onsite engineer',3600000,DATE '2026-07-31','cto@max.in','escalated',91,720000,18,'failure x4 last Q'),
('Narayana','NRY-KOL-HWH','Patient Monitor',0,'rebalance from HSR branch',0,DATE '2026-07-15','ops@narayana.in','in_progress',45,0,7,'no_capex needed'),
('AIIMS','AIIMS-DEL-MN','Ventilator',2,'tender batch 7',5200000,DATE '2026-10-30','dme@aiims.edu','planning',68,0,90,'GeM tender'),
('AIIMS','AIIMS-JDP','Defibrillator',2,'tender batch 7',640000,DATE '2026-10-30','dme@aiims.edu','planning',55,0,90,NULL),
('KIMS','KIMS-HYD-SEC','Ventilator',1,'CAPEX + AMC',1450000,DATE '2026-08-20','biomed@kims.in','approved',61,340000,35,NULL),
('KIMS','KIMS-HYD-KON','Infusion Pump',2,'bulk PO',520000,DATE '2026-08-05','biomed@kims.in','in_progress',49,160000,21,'BPL bulk'),
('Yashoda','YSH-HYD-MAL','Dialysis Machine',3,'urgent lease',2700000,DATE '2026-07-20','ops@yashoda.in','escalated',86,640000,14,'critical_gap');

-- RPCs
CREATE OR REPLACE FUNCTION founder_r2895_chain_rollup()
RETURNS TABLE (chain_name text, branches int, total_primary bigint, total_backup bigint, avg_ratio numeric, gap_branches int, critical_branches int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name,
         COUNT(DISTINCT c.branch_code)::int,
         SUM(c.primary_units)::bigint,
         SUM(c.backup_units)::bigint,
         ROUND(AVG(c.redundancy_ratio),2),
         COUNT(*) FILTER (WHERE c.coverage_status='gap')::int,
         COUNT(*) FILTER (WHERE c.coverage_status='critical_gap')::int
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.chain_name
  ORDER BY critical_branches DESC, gap_branches DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_critical_branches()
RETURNS TABLE (chain_name text, branch_code text, city text, equipment_category text, redundancy_ratio numeric, beds_served int, failure_events_last_quarter int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.branch_code, c.city, c.equipment_category, c.redundancy_ratio, c.beds_served, c.failure_events_last_quarter
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  WHERE c.coverage_status='critical_gap'
  ORDER BY c.failure_events_last_quarter DESC, c.beds_served DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_category_posture()
RETURNS TABLE (equipment_category text, branches int, avg_ratio numeric, total_required int, total_backup bigint, coverage_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.equipment_category,
         COUNT(*)::int,
         ROUND(AVG(c.redundancy_ratio),2),
         SUM(c.required_redundancy_units)::int,
         SUM(c.backup_units)::bigint,
         ROUND(100.0 * SUM(c.backup_units)::numeric / NULLIF(SUM(c.required_redundancy_units),0), 1)
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.equipment_category
  ORDER BY coverage_pct ASC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_remediation_pipeline()
RETURNS TABLE (chain_name text, branch_code text, equipment_category text, gap_units int, est_cost_rupees bigint, committed_close_date date, status text, risk_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.branch_code, r.equipment_category, r.gap_units, r.est_cost_rupees, r.committed_close_date, r.status, r.risk_score
  FROM hospital_chain_redundancy_gap_remediations_r2895 r
  ORDER BY r.risk_score DESC, r.committed_close_date ASC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_amc_upsell_pipeline()
RETURNS TABLE (chain_name text, branches int, total_amc_upsell_rupees bigint, total_capex_rupees bigint, avg_lead_days numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name,
         COUNT(DISTINCT r.branch_code)::int,
         SUM(r.amc_upsell_rupees)::bigint,
         SUM(r.est_cost_rupees)::bigint,
         ROUND(AVG(r.procurement_lead_days),1)
  FROM hospital_chain_redundancy_gap_remediations_r2895 r
  GROUP BY r.chain_name
  ORDER BY total_amc_upsell_rupees DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_city_heatmap()
RETURNS TABLE (city text, branches int, total_beds bigint, avg_ratio numeric, critical_count int, total_failures bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.city,
         COUNT(*)::int,
         SUM(c.beds_served)::bigint,
         ROUND(AVG(c.redundancy_ratio),2),
         COUNT(*) FILTER (WHERE c.coverage_status='critical_gap')::int,
         SUM(c.failure_events_last_quarter)::bigint
  FROM hospital_chain_critical_care_redundancy_coverage_r2895 c
  GROUP BY c.city
  ORDER BY critical_count DESC, total_failures DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2895_kpi_summary()
RETURNS TABLE (total_branches int, total_chains int, compliant_branches int, gap_branches int, critical_branches int, total_remediation_capex_rupees bigint, total_amc_upsell_rupees bigint, avg_redundancy_ratio numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT branch_code)::int FROM hospital_chain_critical_care_redundancy_coverage_r2895),
    (SELECT COUNT(DISTINCT chain_name)::int FROM hospital_chain_critical_care_redundancy_coverage_r2895),
    (SELECT COUNT(*)::int FROM hospital_chain_critical_care_redundancy_coverage_r2895 WHERE coverage_status='compliant'),
    (SELECT COUNT(*)::int FROM hospital_chain_critical_care_redundancy_coverage_r2895 WHERE coverage_status='gap'),
    (SELECT COUNT(*)::int FROM hospital_chain_critical_care_redundancy_coverage_r2895 WHERE coverage_status='critical_gap'),
    (SELECT COALESCE(SUM(est_cost_rupees),0)::bigint FROM hospital_chain_redundancy_gap_remediations_r2895),
    (SELECT COALESCE(SUM(amc_upsell_rupees),0)::bigint FROM hospital_chain_redundancy_gap_remediations_r2895),
    (SELECT ROUND(AVG(redundancy_ratio),2) FROM hospital_chain_critical_care_redundancy_coverage_r2895);
END;$$;

REVOKE EXECUTE ON FUNCTION founder_r2895_chain_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_critical_branches() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_category_posture() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_remediation_pipeline() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_amc_upsell_pipeline() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_city_heatmap() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2895_kpi_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2895_chain_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_critical_branches() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_category_posture() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_remediation_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_amc_upsell_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_city_heatmap() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2895_kpi_summary() TO authenticated;
