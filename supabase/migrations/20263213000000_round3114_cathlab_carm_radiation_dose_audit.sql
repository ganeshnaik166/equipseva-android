-- Round 3114 — Customer Hospital Cath-Lab C-Arm Image Intensifier Radiation-Dose Patient-Skin-Dose Audit
-- Quarterly cath-lab C-arm / image-intensifier audit covering dose-area-product (DAP),
-- peak skin dose (PSD), fluoro time, kV/mA, II resolution, AERB compliance, CAPA actions.

BEGIN;

-- ===========================================================================
-- TABLE 1: per-audit header row (one row per cath-lab C-arm per quarter)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS cathlab_carm_dose_audits_r3114 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id             uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  hospital_name               text NOT NULL,
  city                        text NOT NULL,
  state                       text NOT NULL,
  asset_tag                   text NOT NULL,
  carm_make                   text NOT NULL,
  carm_model                  text NOT NULL,
  carm_install_year           integer NOT NULL CHECK (carm_install_year BETWEEN 2000 AND 2030),
  ii_size_inches              numeric(4,1) NOT NULL CHECK (ii_size_inches IN (9.0, 12.0, 16.0)),
  ii_type                     text NOT NULL CHECK (ii_type IN ('analog_ii','digital_flat_panel','hybrid_ii')),
  ii_resolution_lp_mm         numeric(4,2) NOT NULL CHECK (ii_resolution_lp_mm BETWEEN 0.5 AND 6.0),
  audit_quarter               text NOT NULL CHECK (audit_quarter IN ('Q1','Q2','Q3','Q4')),
  audit_year                  integer NOT NULL CHECK (audit_year BETWEEN 2024 AND 2030),
  audit_date                  date NOT NULL,
  audited_by_engineer_id      uuid REFERENCES engineers(id) ON DELETE SET NULL,
  aerb_licence_number         text NOT NULL,
  aerb_licence_expiry         date NOT NULL,
  rso_name                    text NOT NULL,
  rso_certification_valid     boolean NOT NULL DEFAULT true,
  total_procedures_in_quarter integer NOT NULL CHECK (total_procedures_in_quarter >= 0),
  cumulative_dap_gy_cm2       numeric(12,2) NOT NULL CHECK (cumulative_dap_gy_cm2 >= 0),
  peak_skin_dose_gy           numeric(8,3) NOT NULL CHECK (peak_skin_dose_gy >= 0),
  cumulative_fluoro_minutes   numeric(10,2) NOT NULL CHECK (cumulative_fluoro_minutes >= 0),
  max_kv_recorded             numeric(5,1) NOT NULL CHECK (max_kv_recorded BETWEEN 40 AND 150),
  max_ma_recorded             numeric(6,2) NOT NULL CHECK (max_ma_recorded BETWEEN 0 AND 1500),
  half_value_layer_mm_al      numeric(4,2) NOT NULL CHECK (half_value_layer_mm_al BETWEEN 1.0 AND 8.0),
  dose_rate_mgy_min_iso       numeric(8,3) NOT NULL,
  exceeds_aerb_limit          boolean NOT NULL DEFAULT false,
  overall_audit_status        text NOT NULL CHECK (overall_audit_status IN ('pass','pass_with_observations','conditional_pass','fail','critical_fail')),
  capa_required               boolean NOT NULL DEFAULT false,
  capa_deadline               date,
  capa_owner_profile_id       uuid REFERENCES profiles(id) ON DELETE SET NULL,
  next_audit_due              date NOT NULL,
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, asset_tag, audit_quarter, audit_year)
);

CREATE INDEX IF NOT EXISTS idx_cathlab_audit_r3114_org    ON cathlab_carm_dose_audits_r3114(organization_id);
CREATE INDEX IF NOT EXISTS idx_cathlab_audit_r3114_status ON cathlab_carm_dose_audits_r3114(overall_audit_status);
CREATE INDEX IF NOT EXISTS idx_cathlab_audit_r3114_capa   ON cathlab_carm_dose_audits_r3114(capa_required) WHERE capa_required = true;

ALTER TABLE cathlab_carm_dose_audits_r3114 ENABLE ROW LEVEL SECURITY;

-- ===========================================================================
-- TABLE 2: per-procedure / per-finding line item
-- ===========================================================================
CREATE TABLE IF NOT EXISTS cathlab_carm_dose_findings_r3114 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id                    uuid NOT NULL REFERENCES cathlab_carm_dose_audits_r3114(id) ON DELETE CASCADE,
  procedure_category          text NOT NULL CHECK (procedure_category IN (
                                'diagnostic_angio','pci_single_vessel','pci_multi_vessel','cto_pci',
                                'tavr','structural_heart','ep_ablation','pacemaker_implant',
                                'peripheral_intervention','dialysis_access','pediatric_cath','other'
                              )),
  finding_type                text NOT NULL CHECK (finding_type IN (
                                'dap_exceedance','psd_exceedance','fluoro_time_exceedance',
                                'kv_drift','ma_drift','ii_resolution_drop','hvl_failure',
                                'collimation_failure','dose_display_inaccuracy','shielding_gap',
                                'badge_compliance','aerb_documentation_gap','phantom_image_quality',
                                'observation_only','pass_no_deviation'
                              )),
  measured_dap_gy_cm2         numeric(10,2),
  measured_psd_gy             numeric(8,3),
  measured_fluoro_minutes     numeric(8,2),
  measured_kv                 numeric(5,1),
  measured_ma                 numeric(6,2),
  aerb_limit_value            numeric(10,3),
  deviation_percent           numeric(6,2),
  severity                    text NOT NULL CHECK (severity IN ('info','minor','major','critical')),
  capa_action_code            text NOT NULL CHECK (capa_action_code IN (
                                'NONE','RECAL_DOSE','REPLACE_II_TUBE','REPLACE_XRAY_TUBE',
                                'COLLIMATOR_REPAIR','HVL_FILTER_REPLACE','SHIELDING_UPGRADE',
                                'OPERATOR_RETRAIN','SOP_REVISION','AERB_NOTIFY','DECOMMISSION'
                              )),
  capa_target_date            date,
  capa_closed_at              date,
  capa_status                 text NOT NULL CHECK (capa_status IN ('open','in_progress','verified','overdue','closed','waived')),
  estimated_repair_cost_rupees integer NOT NULL DEFAULT 0 CHECK (estimated_repair_cost_rupees >= 0),
  responsible_engineer_id     uuid REFERENCES engineers(id) ON DELETE SET NULL,
  finding_notes               text,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cathlab_finding_r3114_audit    ON cathlab_carm_dose_findings_r3114(audit_id);
CREATE INDEX IF NOT EXISTS idx_cathlab_finding_r3114_severity ON cathlab_carm_dose_findings_r3114(severity);
CREATE INDEX IF NOT EXISTS idx_cathlab_finding_r3114_capa     ON cathlab_carm_dose_findings_r3114(capa_status);

ALTER TABLE cathlab_carm_dose_findings_r3114 ENABLE ROW LEVEL SECURITY;

-- ===========================================================================
-- SEED — 12 audit rows + 14 finding rows
-- ===========================================================================
DO $seed$
DECLARE
  v_org_id  uuid;
  v_eng_id  uuid;
  v_pro_id  uuid;
BEGIN
  SELECT id INTO v_org_id FROM organizations ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng_id FROM engineers     ORDER BY created_at LIMIT 1;
  SELECT id INTO v_pro_id FROM profiles      ORDER BY created_at LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE NOTICE 'r3114: no organizations row found; skipping seed';
    RETURN;
  END IF;

  INSERT INTO cathlab_carm_dose_audits_r3114 (
    organization_id, hospital_name, city, state, asset_tag,
    carm_make, carm_model, carm_install_year, ii_size_inches, ii_type, ii_resolution_lp_mm,
    audit_quarter, audit_year, audit_date, audited_by_engineer_id,
    aerb_licence_number, aerb_licence_expiry, rso_name, rso_certification_valid,
    total_procedures_in_quarter, cumulative_dap_gy_cm2, peak_skin_dose_gy,
    cumulative_fluoro_minutes, max_kv_recorded, max_ma_recorded, half_value_layer_mm_al,
    dose_rate_mgy_min_iso, exceeds_aerb_limit, overall_audit_status,
    capa_required, capa_deadline, capa_owner_profile_id, next_audit_due, notes
  )
  SELECT
    v_org_id, q.hospital_name, q.city, q.state, q.asset_tag,
    q.carm_make, q.carm_model, q.carm_install_year, q.ii_size_inches, q.ii_type, q.ii_resolution_lp_mm,
    q.audit_quarter, q.audit_year, q.audit_date::date, v_eng_id,
    q.aerb_licence_number, q.aerb_licence_expiry::date, q.rso_name, q.rso_certification_valid,
    q.total_procedures_in_quarter, q.cumulative_dap_gy_cm2, q.peak_skin_dose_gy,
    q.cumulative_fluoro_minutes, q.max_kv_recorded, q.max_ma_recorded, q.half_value_layer_mm_al,
    q.dose_rate_mgy_min_iso, q.exceeds_aerb_limit, q.overall_audit_status,
    q.capa_required, q.capa_deadline::date, v_pro_id, q.next_audit_due::date, q.notes
  FROM (VALUES
    ('Apollo Hospitals Jubilee Hills','Hyderabad','Telangana','APOLLO-CATH-01',
      'Philips','Azurion 7 M20',2022,12.0,'digital_flat_panel',3.20,
      'Q1',2026,'2026-03-15','AERB/CL/TS/2024/00451','2027-03-31','Dr. Ravi Kumar',true,
      842,4521.30,2.150,3120.50,110.5,820.00,3.20,
      32.500,false,'pass',false,NULL,'2026-06-15',
      'All parameters within AERB DRR-2018 limits. Routine quarterly audit.'),
    ('Fortis Escorts Heart Institute','New Delhi','Delhi','FORTIS-CATH-02',
      'Siemens','Artis Q ceiling',2021,12.0,'digital_flat_panel',3.10,
      'Q1',2026,'2026-03-18','AERB/CL/DL/2023/00128','2026-12-31','Dr. Anjali Sharma',true,
      1124,6892.50,3.420,4250.75,115.0,950.00,3.05,
      38.200,true,'pass_with_observations',true,'2026-05-31','2026-06-18',
      'PSD exceedance in 2 CTO PCI cases; operator retraining scheduled.'),
    ('Medanta The Medicity','Gurgaon','Haryana','MEDANTA-CATH-03',
      'GE Healthcare','Innova IGS 530',2020,12.0,'digital_flat_panel',2.95,
      'Q1',2026,'2026-03-22','AERB/CL/HR/2022/00089','2027-09-30','Dr. Sunil Verma',true,
      963,5234.80,2.880,3890.20,113.5,890.00,3.15,
      35.800,false,'pass',false,NULL,'2026-06-22',
      'Image intensifier resolution slight degradation noted (2.95 lp/mm vs OEM 3.20); monitor next quarter.'),
    ('Narayana Health City','Bengaluru','Karnataka','NARAYANA-CATH-04',
      'Philips','Allura Xper FD10',2018,9.0,'analog_ii',1.85,
      'Q1',2026,'2026-03-25','AERB/CL/KA/2020/00234','2026-08-15','Dr. Mahesh Reddy',true,
      1542,8920.40,4.510,5680.30,118.0,1020.00,2.85,
      45.300,true,'conditional_pass',true,'2026-04-30','2026-06-25',
      'II resolution drop to 1.85 lp/mm; tube replacement quoted. PSD over 4 Gy threshold flagged.'),
    ('AIIMS Cath Lab 2','New Delhi','Delhi','AIIMS-CATH-05',
      'Siemens','Artis zee biplane',2019,12.0,'digital_flat_panel',3.05,
      'Q1',2026,'2026-03-28','AERB/CL/DL/2021/00056','2027-01-31','Dr. Priya Nair',true,
      1789,9842.10,3.250,6120.80,116.5,980.00,3.10,
      41.200,false,'pass_with_observations',true,'2026-05-15','2026-06-28',
      'Biplane geometry — recommend separate badge tracking for left lateral RSO assistant.'),
    ('Kokilaben Dhirubhai Ambani Hospital','Mumbai','Maharashtra','KOKILABEN-CATH-06',
      'Philips','Azurion 3 M12',2023,12.0,'digital_flat_panel',3.40,
      'Q1',2026,'2026-04-02','AERB/CL/MH/2024/00312','2027-06-30','Dr. Vikram Joshi',true,
      721,3984.20,1.920,2750.40,108.0,780.00,3.25,
      29.800,false,'pass',false,NULL,'2026-07-02',
      'Newest install in cohort; performing 12% below average DAP. Excellent.'),
    ('CMC Vellore Cardiology','Vellore','Tamil Nadu','CMC-CATH-07',
      'GE Healthcare','Innova 2000',2016,12.0,'analog_ii',2.20,
      'Q1',2026,'2026-04-05','AERB/CL/TN/2019/00078','2026-05-31','Dr. Joseph Mathew',true,
      1320,9520.80,5.120,6890.50,120.0,1100.00,2.65,
      52.400,true,'fail',true,'2026-04-25','2026-04-25',
      'AERB licence expires in 30 days; PSD over 5 Gy; II tube end-of-life. Urgent CAPA.'),
    ('Manipal Hospital HAL Airport Road','Bengaluru','Karnataka','MANIPAL-CATH-08',
      'Siemens','Artis pheno',2024,12.0,'digital_flat_panel',3.50,
      'Q1',2026,'2026-04-08','AERB/CL/KA/2024/00445','2027-12-31','Dr. Lakshmi Iyer',true,
      598,3120.40,1.580,2340.20,105.0,720.00,3.30,
      26.500,false,'pass',false,NULL,'2026-07-08',
      'Newest in fleet; benchmark unit for KPI dashboards.'),
    ('St John''s Medical College Hospital','Bengaluru','Karnataka','STJOHN-CATH-09',
      'Philips','Allura Xper FD20',2017,12.0,'digital_flat_panel',2.80,
      'Q1',2026,'2026-04-10','AERB/CL/KA/2019/00112','2026-11-30','Dr. Robert D''Souza',true,
      1056,6420.30,3.780,4520.60,115.5,920.00,2.95,
      39.700,true,'pass_with_observations',true,'2026-05-20','2026-07-10',
      'HVL marginally low (2.95 vs spec 3.0); filter inspection scheduled.'),
    ('Asian Heart Institute','Mumbai','Maharashtra','ASIAN-CATH-10',
      'Toshiba','Infinix-i 4D',2019,12.0,'digital_flat_panel',2.90,
      'Q1',2026,'2026-04-12','AERB/CL/MH/2020/00198','2027-04-30','Dr. Ramesh Kale',true,
      1432,7820.50,3.920,5240.30,117.0,960.00,3.00,
      42.100,false,'pass_with_observations',false,NULL,'2026-07-12',
      'High volume centre; suggest additional Pb apron audit for staff.'),
    ('Sri Ramachandra Medical Centre','Chennai','Tamil Nadu','SRMC-CATH-11',
      'GE Healthcare','Innova IGS 520',2020,12.0,'digital_flat_panel',3.00,
      'Q1',2026,'2026-04-14','AERB/CL/TN/2021/00167','2027-02-28','Dr. Arun Kumar',true,
      887,4980.20,2.640,3450.80,112.0,860.00,3.15,
      33.900,false,'pass',false,NULL,'2026-07-14',
      'Stable performance; no deviations.'),
    ('PGIMER Chandigarh Cardiology','Chandigarh','Chandigarh','PGIMER-CATH-12',
      'Siemens','Artis Q.zen',2015,12.0,'analog_ii',2.10,
      'Q1',2026,'2026-04-16','AERB/CL/CH/2018/00041','2026-07-31','Dr. Harpreet Singh',true,
      1678,11250.40,5.840,7820.50,122.0,1180.00,2.55,
      58.700,true,'critical_fail',true,'2026-04-20','2026-04-20',
      'Decommission recommended. PSD over 5 Gy in 4 procedures; AERB notification mandatory.')
  ) AS q(
    hospital_name, city, state, asset_tag,
    carm_make, carm_model, carm_install_year, ii_size_inches, ii_type, ii_resolution_lp_mm,
    audit_quarter, audit_year, audit_date, aerb_licence_number, aerb_licence_expiry,
    rso_name, rso_certification_valid, total_procedures_in_quarter, cumulative_dap_gy_cm2,
    peak_skin_dose_gy, cumulative_fluoro_minutes, max_kv_recorded, max_ma_recorded,
    half_value_layer_mm_al, dose_rate_mgy_min_iso, exceeds_aerb_limit, overall_audit_status,
    capa_required, capa_deadline, next_audit_due, notes
  );

  -- 14 findings linked to the audits above (deterministic via asset_tag lookup)
  INSERT INTO cathlab_carm_dose_findings_r3114 (
    audit_id, procedure_category, finding_type,
    measured_dap_gy_cm2, measured_psd_gy, measured_fluoro_minutes,
    measured_kv, measured_ma, aerb_limit_value, deviation_percent,
    severity, capa_action_code, capa_target_date, capa_closed_at, capa_status,
    estimated_repair_cost_rupees, responsible_engineer_id, finding_notes
  )
  SELECT a.id, f.procedure_category, f.finding_type,
         f.measured_dap_gy_cm2, f.measured_psd_gy, f.measured_fluoro_minutes,
         f.measured_kv, f.measured_ma, f.aerb_limit_value, f.deviation_percent,
         f.severity, f.capa_action_code, f.capa_target_date::date, f.capa_closed_at::date, f.capa_status,
         f.estimated_repair_cost_rupees, v_eng_id, f.finding_notes
  FROM cathlab_carm_dose_audits_r3114 a
  JOIN (VALUES
    ('FORTIS-CATH-02','cto_pci','psd_exceedance',
      820.50,3.420,68.20,115.0,950.00,3.000,14.00,'major','OPERATOR_RETRAIN','2026-05-31',NULL,'in_progress',45000,'CTO PCI case 412; operator overhead time 68 min.'),
    ('FORTIS-CATH-02','pci_multi_vessel','dap_exceedance',
      612.80,2.940,42.50,113.0,910.00,500.000,22.56,'major','SOP_REVISION','2026-05-15',NULL,'open',12000,'Multi-vessel PCI; review angulation protocol.'),
    ('MEDANTA-CATH-03','diagnostic_angio','observation_only',
      85.40,0.380,8.20,108.0,720.00,100.000,-14.60,'info','NONE',NULL,NULL,'closed',0,'Routine angio within limits; logged for trend.'),
    ('NARAYANA-CATH-04','cto_pci','psd_exceedance',
      980.20,4.510,82.30,118.0,1020.00,3.000,50.33,'critical','OPERATOR_RETRAIN','2026-04-30','2026-04-28','verified',60000,'CTO retrograde approach 82 min; skin reaction risk.'),
    ('NARAYANA-CATH-04','pci_single_vessel','ii_resolution_drop',
      NULL,NULL,NULL,NULL,NULL,3.000,-38.33,'major','REPLACE_II_TUBE','2026-04-30',NULL,'in_progress',1850000,'II resolution 1.85 lp/mm vs OEM spec 3.0 lp/mm; tube quoted.'),
    ('AIIMS-CATH-05','ep_ablation','fluoro_time_exceedance',
      420.30,1.820,118.50,116.0,920.00,60.000,97.50,'major','OPERATOR_RETRAIN','2026-05-15',NULL,'in_progress',35000,'Complex AF ablation; fluoro 118 min vs target 60.'),
    ('AIIMS-CATH-05','tavr','observation_only',
      540.80,2.150,42.30,114.0,890.00,600.000,-9.87,'info','NONE',NULL,NULL,'closed',0,'TAVR within expected envelope; documented.'),
    ('CMC-CATH-07','cto_pci','psd_exceedance',
      1120.50,5.120,95.40,120.0,1100.00,3.000,70.67,'critical','REPLACE_XRAY_TUBE','2026-04-25',NULL,'overdue',2400000,'PSD over 5 Gy; AERB §11.3 notification required.'),
    ('CMC-CATH-07','diagnostic_angio','aerb_documentation_gap',
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,'critical','AERB_NOTIFY','2026-04-25','2026-04-24','closed',5000,'AERB licence renewal lapsing in 30 days; renewal filed.'),
    ('STJOHN-CATH-09','peripheral_intervention','hvl_failure',
      320.80,1.620,38.50,114.0,880.00,3.000,-1.67,'minor','HVL_FILTER_REPLACE','2026-05-20',NULL,'open',85000,'HVL 2.95 mm Al vs spec 3.0; filter inspection.'),
    ('ASIAN-CATH-10','pci_multi_vessel','kv_drift',
      420.30,1.920,28.50,117.0,960.00,120.000,-2.50,'minor','RECAL_DOSE','2026-06-30',NULL,'open',18000,'kV display drift +2 kV; recalibration scheduled.'),
    ('PGIMER-CATH-12','cto_pci','psd_exceedance',
      1280.40,5.840,108.20,122.0,1180.00,3.000,94.67,'critical','DECOMMISSION','2026-04-20',NULL,'in_progress',0,'Critical PSD breach; lab decommission recommended.'),
    ('PGIMER-CATH-12','pci_multi_vessel','ii_resolution_drop',
      NULL,NULL,NULL,NULL,NULL,3.000,-30.00,'major','DECOMMISSION','2026-04-20',NULL,'in_progress',0,'II resolution 2.10 lp/mm; end-of-life unit.'),
    ('PGIMER-CATH-12','diagnostic_angio','shielding_gap',
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,'major','SHIELDING_UPGRADE','2026-05-20',NULL,'open',450000,'Lateral shield 1.2 mm Pb vs spec 1.5; quoted.')
  ) AS f(asset_tag, procedure_category, finding_type,
         measured_dap_gy_cm2, measured_psd_gy, measured_fluoro_minutes,
         measured_kv, measured_ma, aerb_limit_value, deviation_percent,
         severity, capa_action_code, capa_target_date, capa_closed_at, capa_status,
         estimated_repair_cost_rupees, finding_notes)
    ON a.asset_tag = f.asset_tag;
END
$seed$;

-- ===========================================================================
-- RPCs — 8 founder-gated SECURITY DEFINER plpgsql functions
-- ===========================================================================

CREATE OR REPLACE FUNCTION founder_r3114_fleet_overview()
RETURNS TABLE (
  asset_tag text, hospital_name text, city text, carm_make text, carm_model text,
  install_year integer, ii_type text, ii_resolution_lp_mm numeric,
  audit_quarter text, audit_year integer, overall_audit_status text,
  total_procedures integer, cumulative_dap_gy_cm2 numeric, peak_skin_dose_gy numeric,
  exceeds_aerb_limit boolean, capa_required boolean, next_audit_due date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.hospital_name, a.city, a.carm_make, a.carm_model,
         a.carm_install_year, a.ii_type, a.ii_resolution_lp_mm,
         a.audit_quarter, a.audit_year, a.overall_audit_status,
         a.total_procedures_in_quarter, a.cumulative_dap_gy_cm2, a.peak_skin_dose_gy,
         a.exceeds_aerb_limit, a.capa_required, a.next_audit_due
  FROM cathlab_carm_dose_audits_r3114 a
  ORDER BY a.exceeds_aerb_limit DESC, a.peak_skin_dose_gy DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_fleet_overview() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_fleet_overview() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_dose_exceedances()
RETURNS TABLE (
  asset_tag text, hospital_name text, city text, finding_type text, severity text,
  measured_psd_gy numeric, measured_dap_gy_cm2 numeric, deviation_percent numeric,
  capa_action_code text, capa_status text, capa_target_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.hospital_name, a.city, f.finding_type, f.severity,
         f.measured_psd_gy, f.measured_dap_gy_cm2, f.deviation_percent,
         f.capa_action_code, f.capa_status, f.capa_target_date
  FROM cathlab_carm_dose_findings_r3114 f
  JOIN cathlab_carm_dose_audits_r3114 a ON a.id = f.audit_id
  WHERE f.finding_type IN ('psd_exceedance','dap_exceedance','fluoro_time_exceedance')
  ORDER BY f.severity DESC, f.deviation_percent DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_dose_exceedances() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_dose_exceedances() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_capa_pipeline()
RETURNS TABLE (
  asset_tag text, hospital_name text, finding_type text, capa_action_code text,
  capa_status text, capa_target_date date, capa_closed_at date,
  severity text, estimated_repair_cost_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.hospital_name, f.finding_type, f.capa_action_code,
         f.capa_status, f.capa_target_date, f.capa_closed_at,
         f.severity, f.estimated_repair_cost_rupees
  FROM cathlab_carm_dose_findings_r3114 f
  JOIN cathlab_carm_dose_audits_r3114 a ON a.id = f.audit_id
  WHERE f.capa_status IN ('open','in_progress','overdue')
  ORDER BY (f.capa_status = 'overdue') DESC, f.capa_target_date ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_capa_pipeline() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_capa_pipeline() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_severity_rollup()
RETURNS TABLE (severity text, finding_count bigint, total_capa_cost_rupees bigint, avg_deviation_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.severity,
         COUNT(*)::bigint,
         COALESCE(SUM(f.estimated_repair_cost_rupees),0)::bigint,
         ROUND(AVG(f.deviation_percent)::numeric, 2)
  FROM cathlab_carm_dose_findings_r3114 f
  GROUP BY f.severity
  ORDER BY CASE f.severity WHEN 'critical' THEN 0 WHEN 'major' THEN 1 WHEN 'minor' THEN 2 ELSE 3 END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_severity_rollup() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_severity_rollup() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_ii_resolution_decay()
RETURNS TABLE (
  asset_tag text, hospital_name text, carm_make text, carm_model text,
  install_year integer, ii_type text, ii_resolution_lp_mm numeric, age_years integer,
  resolution_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.hospital_name, a.carm_make, a.carm_model,
         a.carm_install_year, a.ii_type, a.ii_resolution_lp_mm,
         (EXTRACT(YEAR FROM CURRENT_DATE)::int - a.carm_install_year)::int,
         CASE
           WHEN a.ii_resolution_lp_mm < 2.5 THEN 'replace_now'
           WHEN a.ii_resolution_lp_mm < 3.0 THEN 'monitor_quarterly'
           ELSE 'within_spec'
         END
  FROM cathlab_carm_dose_audits_r3114 a
  ORDER BY a.ii_resolution_lp_mm ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_ii_resolution_decay() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_ii_resolution_decay() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_aerb_licence_watch()
RETURNS TABLE (
  asset_tag text, hospital_name text, aerb_licence_number text,
  aerb_licence_expiry date, days_to_expiry integer, rso_name text, rso_certification_valid boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.hospital_name, a.aerb_licence_number,
         a.aerb_licence_expiry,
         (a.aerb_licence_expiry - CURRENT_DATE)::int,
         a.rso_name, a.rso_certification_valid
  FROM cathlab_carm_dose_audits_r3114 a
  ORDER BY a.aerb_licence_expiry ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_aerb_licence_watch() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_aerb_licence_watch() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_procedure_mix()
RETURNS TABLE (procedure_category text, finding_count bigint, avg_psd_gy numeric, avg_fluoro_minutes numeric, critical_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.procedure_category,
         COUNT(*)::bigint,
         ROUND(AVG(f.measured_psd_gy)::numeric, 3),
         ROUND(AVG(f.measured_fluoro_minutes)::numeric, 2),
         SUM(CASE WHEN f.severity = 'critical' THEN 1 ELSE 0 END)::bigint
  FROM cathlab_carm_dose_findings_r3114 f
  GROUP BY f.procedure_category
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_procedure_mix() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_procedure_mix() TO authenticated;

CREATE OR REPLACE FUNCTION founder_r3114_executive_summary()
RETURNS TABLE (
  total_labs_audited bigint, total_procedures bigint, total_dap_gy_cm2 numeric,
  labs_over_aerb bigint, critical_findings bigint, capa_open bigint, capa_overdue bigint,
  capa_cost_outstanding_rupees bigint, decommission_candidates bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM cathlab_carm_dose_audits_r3114)::bigint,
    (SELECT COALESCE(SUM(total_procedures_in_quarter),0) FROM cathlab_carm_dose_audits_r3114)::bigint,
    (SELECT ROUND(COALESCE(SUM(cumulative_dap_gy_cm2),0)::numeric, 2) FROM cathlab_carm_dose_audits_r3114),
    (SELECT COUNT(*) FROM cathlab_carm_dose_audits_r3114 WHERE exceeds_aerb_limit)::bigint,
    (SELECT COUNT(*) FROM cathlab_carm_dose_findings_r3114 WHERE severity = 'critical')::bigint,
    (SELECT COUNT(*) FROM cathlab_carm_dose_findings_r3114 WHERE capa_status IN ('open','in_progress'))::bigint,
    (SELECT COUNT(*) FROM cathlab_carm_dose_findings_r3114 WHERE capa_status = 'overdue')::bigint,
    (SELECT COALESCE(SUM(estimated_repair_cost_rupees),0) FROM cathlab_carm_dose_findings_r3114 WHERE capa_status IN ('open','in_progress','overdue'))::bigint,
    (SELECT COUNT(*) FROM cathlab_carm_dose_findings_r3114 WHERE capa_action_code = 'DECOMMISSION')::bigint;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r3114_executive_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r3114_executive_summary() TO authenticated;

COMMIT;
