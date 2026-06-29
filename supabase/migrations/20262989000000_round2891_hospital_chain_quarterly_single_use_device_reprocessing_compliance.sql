-- Round 2891 — Hospital Chain Quarterly Single-Use-Device Reprocessing Compliance
-- Founder ops: multi-branch rollup of SUD reprocessing violations across hospital chains

BEGIN;

-- =========================================================================
-- TABLE 1: chain_sud_reprocessing_audits_r2891
-- Quarterly audit of single-use-device reprocessing per chain branch
-- =========================================================================
CREATE TABLE IF NOT EXISTS chain_sud_reprocessing_audits_r2891 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  branch_name text NOT NULL,
  branch_city text NOT NULL,
  audit_quarter text NOT NULL,  -- e.g. '2026-Q1'
  audit_date date NOT NULL,
  device_category text NOT NULL,  -- 'cardiac_catheter','endoscope_accessory','laparoscopy_trocar','biopsy_forceps','ablation_electrode'
  total_sud_units_received int NOT NULL,
  units_reprocessed_count int NOT NULL,
  max_reprocessing_cycles_allowed int NOT NULL,
  actual_reuse_cycles_max int NOT NULL,
  fda_510k_clearance_present boolean NOT NULL DEFAULT false,
  sterilization_method text NOT NULL,  -- 'eto','steam','plasma','peracetic_acid'
  bioburden_test_pass_rate_pct numeric(5,2) NOT NULL,
  endotoxin_test_pass_rate_pct numeric(5,2) NOT NULL,
  patient_adverse_events_count int NOT NULL DEFAULT 0,
  compliance_score_pct numeric(5,2) NOT NULL,
  violation_severity text NOT NULL,  -- 'none','minor','major','critical'
  auditor_name text NOT NULL,
  corrective_action_due_date date,
  estimated_liability_rupees bigint NOT NULL DEFAULT 0
);

ALTER TABLE chain_sud_reprocessing_audits_r2891 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: chain_sud_corrective_actions_r2891
-- Corrective action plans tracked per violation
-- =========================================================================
CREATE TABLE IF NOT EXISTS chain_sud_corrective_actions_r2891 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_id uuid REFERENCES chain_sud_reprocessing_audits_r2891(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  branch_name text NOT NULL,
  action_type text NOT NULL,  -- 'training','equipment_upgrade','process_redesign','staff_replacement','vendor_change','quarantine'
  action_priority text NOT NULL,  -- 'p0','p1','p2','p3'
  action_owner_role text NOT NULL,  -- 'infection_control_head','biomedical_lead','quality_director','cmo'
  capex_required_rupees bigint NOT NULL DEFAULT 0,
  opex_required_rupees bigint NOT NULL DEFAULT 0,
  target_closure_date date NOT NULL,
  current_status text NOT NULL,  -- 'open','in_progress','completed','overdue','escalated'
  completion_pct numeric(5,2) NOT NULL DEFAULT 0,
  equipseva_engineer_assigned boolean NOT NULL DEFAULT false,
  amc_upsell_opportunity_rupees bigint NOT NULL DEFAULT 0,
  notes text
);

ALTER TABLE chain_sud_corrective_actions_r2891 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEED: 18 audits across 6 chains
-- =========================================================================
INSERT INTO chain_sud_reprocessing_audits_r2891
(chain_name, branch_name, branch_city, audit_quarter, audit_date, device_category,
 total_sud_units_received, units_reprocessed_count, max_reprocessing_cycles_allowed,
 actual_reuse_cycles_max, fda_510k_clearance_present, sterilization_method,
 bioburden_test_pass_rate_pct, endotoxin_test_pass_rate_pct, patient_adverse_events_count,
 compliance_score_pct, violation_severity, auditor_name, corrective_action_due_date,
 estimated_liability_rupees) VALUES
('Apollo Hospitals','Apollo Jubilee Hills','Hyderabad','2026-Q1','2026-03-12','cardiac_catheter',420,180,2,5,true,'eto',94.5,97.2,0,88.40,'minor','Dr. Rakesh Menon','2026-06-30',1200000),
('Apollo Hospitals','Apollo Chennai Greams','Chennai','2026-Q1','2026-03-15','endoscope_accessory',780,510,3,3,true,'plasma',98.10,99.50,0,96.20,'none','Dr. Rakesh Menon','2026-06-30',0),
('Apollo Hospitals','Apollo Bangalore Bannerghatta','Bangalore','2026-Q1','2026-03-18','laparoscopy_trocar',340,210,2,4,false,'steam',82.30,85.10,2,68.50,'critical','Dr. Rakesh Menon','2026-05-15',8500000),
('Fortis Healthcare','Fortis Gurgaon Memorial','Gurgaon','2026-Q1','2026-03-08','ablation_electrode',280,140,1,3,true,'eto',91.20,93.80,1,79.40,'major','Dr. Suman Iyer','2026-06-15',4200000),
('Fortis Healthcare','Fortis Mulund','Mumbai','2026-Q1','2026-03-10','biopsy_forceps',610,420,3,3,true,'peracetic_acid',97.50,98.90,0,94.80,'none','Dr. Suman Iyer','2026-06-30',0),
('Fortis Healthcare','Fortis Noida','Noida','2026-Q1','2026-03-14','cardiac_catheter',390,260,2,6,false,'eto',76.40,79.20,3,58.30,'critical','Dr. Suman Iyer','2026-04-30',12500000),
('Manipal Hospitals','Manipal Old Airport Road','Bangalore','2026-Q1','2026-03-05','endoscope_accessory',520,340,3,4,true,'plasma',93.80,96.10,0,87.50,'minor','Dr. Anita Krishnan','2026-06-30',900000),
('Manipal Hospitals','Manipal Whitefield','Bangalore','2026-Q1','2026-03-07','laparoscopy_trocar',290,180,2,2,true,'steam',96.20,97.80,0,93.10,'none','Dr. Anita Krishnan','2026-06-30',0),
('Manipal Hospitals','Manipal Jayanagar','Bangalore','2026-Q1','2026-03-09','ablation_electrode',210,150,1,4,false,'eto',81.50,84.20,1,65.40,'major','Dr. Anita Krishnan','2026-05-30',3800000),
('Max Healthcare','Max Saket','Delhi','2026-Q1','2026-03-11','cardiac_catheter',540,320,2,3,true,'eto',95.20,96.80,0,91.30,'minor','Dr. Vikram Bhalla','2026-06-30',750000),
('Max Healthcare','Max Patparganj','Delhi','2026-Q1','2026-03-13','biopsy_forceps',480,310,3,5,true,'peracetic_acid',88.60,91.40,1,77.20,'major','Dr. Vikram Bhalla','2026-06-15',2900000),
('Max Healthcare','Max Shalimar Bagh','Delhi','2026-Q1','2026-03-16','endoscope_accessory',360,240,3,3,true,'plasma',98.80,99.20,0,97.10,'none','Dr. Vikram Bhalla','2026-06-30',0),
('Narayana Health','NH Bommasandra','Bangalore','2026-Q1','2026-03-04','laparoscopy_trocar',310,190,2,2,true,'steam',95.50,97.30,0,92.40,'none','Dr. Pradeep Rao','2026-06-30',0),
('Narayana Health','NH Howrah','Kolkata','2026-Q1','2026-03-06','cardiac_catheter',380,250,2,7,false,'eto',71.20,74.80,4,52.10,'critical','Dr. Pradeep Rao','2026-04-15',18500000),
('Narayana Health','NH Ahmedabad','Ahmedabad','2026-Q1','2026-03-19','ablation_electrode',220,140,1,2,true,'eto',93.40,95.10,0,89.60,'minor','Dr. Pradeep Rao','2026-06-30',680000),
('AIIMS Network','AIIMS Delhi','Delhi','2026-Q1','2026-03-20','endoscope_accessory',920,640,3,4,true,'plasma',92.10,94.50,1,85.40,'minor','Dr. Sanjay Pandit','2026-06-30',1500000),
('AIIMS Network','AIIMS Bhopal','Bhopal','2026-Q1','2026-03-22','biopsy_forceps',410,290,3,5,false,'peracetic_acid',79.30,82.60,2,61.20,'critical','Dr. Sanjay Pandit','2026-05-10',9200000),
('AIIMS Network','AIIMS Rishikesh','Rishikesh','2026-Q1','2026-03-25','laparoscopy_trocar',260,170,2,3,true,'steam',90.40,92.80,1,80.50,'major','Dr. Sanjay Pandit','2026-06-15',2400000);

-- Corrective actions seed: 20 rows linked to violations
INSERT INTO chain_sud_corrective_actions_r2891
(audit_id, chain_name, branch_name, action_type, action_priority, action_owner_role,
 capex_required_rupees, opex_required_rupees, target_closure_date,
 current_status, completion_pct, equipseva_engineer_assigned, amc_upsell_opportunity_rupees, notes)
SELECT a.id, a.chain_name, a.branch_name, t.action_type, t.action_priority, t.action_owner_role,
       t.capex, t.opex, t.target, t.status, t.pct, t.eng, t.amc, t.notes
FROM chain_sud_reprocessing_audits_r2891 a
CROSS JOIN LATERAL (VALUES
  ('equipment_upgrade','p0','biomedical_lead',4500000,250000,DATE '2026-05-15','in_progress',45.00,true,1800000,'New plasma sterilizer install'),
  ('training','p1','infection_control_head',0,180000,DATE '2026-06-30','open',10.00,false,0,'40-hour CSSD recertification batch')
) AS t(action_type, action_priority, action_owner_role, capex, opex, target, status, pct, eng, amc, notes)
WHERE a.violation_severity IN ('critical','major')
LIMIT 20;

-- =========================================================================
-- is_founder() helper (idempotent guard)
-- =========================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='is_founder') THEN
    CREATE OR REPLACE FUNCTION is_founder() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public, pg_temp AS $f$
    BEGIN
      RETURN EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid() AND role='founder');
    END;
    $f$;
  END IF;
END$$;

-- =========================================================================
-- RPC 1: rpc_r2891_chain_compliance_rollup
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_chain_compliance_rollup()
RETURNS TABLE(chain_name text, branches_audited int, avg_compliance_pct numeric,
              critical_violations int, total_liability_rupees bigint, adverse_events int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
         COUNT(*)::int,
         ROUND(AVG(a.compliance_score_pct)::numeric, 2),
         SUM(CASE WHEN a.violation_severity='critical' THEN 1 ELSE 0 END)::int,
         SUM(a.estimated_liability_rupees)::bigint,
         SUM(a.patient_adverse_events_count)::int
  FROM chain_sud_reprocessing_audits_r2891 a
  GROUP BY a.chain_name
  ORDER BY SUM(a.estimated_liability_rupees) DESC;
END;
$$;

-- =========================================================================
-- RPC 2: rpc_r2891_branch_risk_ranking
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_branch_risk_ranking()
RETURNS TABLE(chain_name text, branch_name text, branch_city text, device_category text,
              compliance_score_pct numeric, violation_severity text, liability_rupees bigint,
              adverse_events int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name, a.branch_name, a.branch_city, a.device_category,
         a.compliance_score_pct, a.violation_severity, a.estimated_liability_rupees,
         a.patient_adverse_events_count
  FROM chain_sud_reprocessing_audits_r2891 a
  ORDER BY a.compliance_score_pct ASC
  LIMIT 50;
END;
$$;

-- =========================================================================
-- RPC 3: rpc_r2891_device_category_breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_device_category_breakdown()
RETURNS TABLE(device_category text, audits int, avg_reuse_cycles numeric,
              avg_compliance_pct numeric, total_adverse_events int, total_liability bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.device_category,
         COUNT(*)::int,
         ROUND(AVG(a.actual_reuse_cycles_max)::numeric, 2),
         ROUND(AVG(a.compliance_score_pct)::numeric, 2),
         SUM(a.patient_adverse_events_count)::int,
         SUM(a.estimated_liability_rupees)::bigint
  FROM chain_sud_reprocessing_audits_r2891 a
  GROUP BY a.device_category
  ORDER BY SUM(a.estimated_liability_rupees) DESC;
END;
$$;

-- =========================================================================
-- RPC 4: rpc_r2891_sterilization_method_efficacy
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_sterilization_method_efficacy()
RETURNS TABLE(sterilization_method text, sample_count int,
              avg_bioburden_pass numeric, avg_endotoxin_pass numeric,
              critical_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.sterilization_method,
         COUNT(*)::int,
         ROUND(AVG(a.bioburden_test_pass_rate_pct)::numeric, 2),
         ROUND(AVG(a.endotoxin_test_pass_rate_pct)::numeric, 2),
         SUM(CASE WHEN a.violation_severity='critical' THEN 1 ELSE 0 END)::int
  FROM chain_sud_reprocessing_audits_r2891 a
  GROUP BY a.sterilization_method
  ORDER BY AVG(a.bioburden_test_pass_rate_pct) ASC;
END;
$$;

-- =========================================================================
-- RPC 5: rpc_r2891_corrective_action_backlog
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_corrective_action_backlog()
RETURNS TABLE(chain_name text, branch_name text, action_type text, action_priority text,
              current_status text, completion_pct numeric, target_closure_date date,
              capex_rupees bigint, opex_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.branch_name, c.action_type, c.action_priority,
         c.current_status, c.completion_pct, c.target_closure_date,
         c.capex_required_rupees, c.opex_required_rupees
  FROM chain_sud_corrective_actions_r2891 c
  ORDER BY CASE c.action_priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
           c.target_closure_date ASC
  LIMIT 50;
END;
$$;

-- =========================================================================
-- RPC 6: rpc_r2891_amc_upsell_opportunities
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_amc_upsell_opportunities()
RETURNS TABLE(chain_name text, total_amc_opportunity_rupees bigint,
              engineer_assigned_count int, open_actions int,
              capex_total_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name,
         SUM(c.amc_upsell_opportunity_rupees)::bigint,
         SUM(CASE WHEN c.equipseva_engineer_assigned THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN c.current_status='open' THEN 1 ELSE 0 END)::int,
         SUM(c.capex_required_rupees)::bigint
  FROM chain_sud_corrective_actions_r2891 c
  GROUP BY c.chain_name
  ORDER BY SUM(c.amc_upsell_opportunity_rupees) DESC;
END;
$$;

-- =========================================================================
-- RPC 7: rpc_r2891_quarterly_kpis
-- =========================================================================
CREATE OR REPLACE FUNCTION rpc_r2891_quarterly_kpis()
RETURNS TABLE(total_audits int, total_branches int, total_chains int,
              avg_compliance_pct numeric, critical_branches int,
              total_liability_rupees bigint, total_adverse_events int,
              total_amc_pipeline_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT COUNT(*)::int FROM chain_sud_reprocessing_audits_r2891),
         (SELECT COUNT(DISTINCT branch_name)::int FROM chain_sud_reprocessing_audits_r2891),
         (SELECT COUNT(DISTINCT chain_name)::int FROM chain_sud_reprocessing_audits_r2891),
         (SELECT ROUND(AVG(compliance_score_pct)::numeric, 2) FROM chain_sud_reprocessing_audits_r2891),
         (SELECT COUNT(*)::int FROM chain_sud_reprocessing_audits_r2891 WHERE violation_severity='critical'),
         (SELECT COALESCE(SUM(estimated_liability_rupees),0)::bigint FROM chain_sud_reprocessing_audits_r2891),
         (SELECT COALESCE(SUM(patient_adverse_events_count),0)::int FROM chain_sud_reprocessing_audits_r2891),
         (SELECT COALESCE(SUM(amc_upsell_opportunity_rupees),0)::bigint FROM chain_sud_corrective_actions_r2891);
END;
$$;

-- =========================================================================
-- GRANTS
-- =========================================================================
REVOKE EXECUTE ON FUNCTION rpc_r2891_chain_compliance_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_branch_risk_ranking() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_device_category_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_sterilization_method_efficacy() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_corrective_action_backlog() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_amc_upsell_opportunities() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2891_quarterly_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_r2891_chain_compliance_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_branch_risk_ranking() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_device_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_sterilization_method_efficacy() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_corrective_action_backlog() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_amc_upsell_opportunities() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2891_quarterly_kpis() TO authenticated;

COMMIT;
