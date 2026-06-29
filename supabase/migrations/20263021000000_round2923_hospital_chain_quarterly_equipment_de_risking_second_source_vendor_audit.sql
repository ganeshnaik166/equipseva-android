-- Round r2923 — Hospital Chain Quarterly Equipment De-Risking via 2nd-Source Vendor Audit
-- HEAVY founder ops surface.

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_equipment_vendor_risk_r2923 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  equipment_category text NOT NULL,
  primary_vendor text NOT NULL,
  units_deployed int NOT NULL DEFAULT 0,
  annual_spend_rupees bigint NOT NULL DEFAULT 0,
  single_source_flag boolean NOT NULL DEFAULT false,
  vendor_concentration_pct numeric(5,2) NOT NULL DEFAULT 0,
  oem_kyc_status text NOT NULL DEFAULT 'verified',
  risk_tier text NOT NULL DEFAULT 'medium',
  last_audited_at timestamptz NOT NULL DEFAULT (now() - interval '30 days'),
  notes text
);

ALTER TABLE hospital_chain_equipment_vendor_risk_r2923 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS hospital_chain_second_source_audits_r2923 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  equipment_category text NOT NULL,
  alternate_vendor text NOT NULL,
  audit_quarter text NOT NULL,
  qualification_score int NOT NULL DEFAULT 0,
  price_delta_pct numeric(6,2) NOT NULL DEFAULT 0,
  lead_time_days int NOT NULL DEFAULT 0,
  field_trial_units int NOT NULL DEFAULT 0,
  recommended_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  audit_status text NOT NULL DEFAULT 'pending',
  audit_owner_email text NOT NULL,
  signoff_at timestamptz,
  audit_cost_rupees bigint NOT NULL DEFAULT 0
);

ALTER TABLE hospital_chain_second_source_audits_r2923 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEED DATA
-- ============================================================================

INSERT INTO hospital_chain_equipment_vendor_risk_r2923
  (chain_name, equipment_category, primary_vendor, units_deployed, annual_spend_rupees, single_source_flag, vendor_concentration_pct, oem_kyc_status, risk_tier, last_audited_at, notes)
VALUES
  ('Apollo North','Ventilators','Hamilton',48, 18400000, true, 92.50, 'verified',  'high',   (now() - interval '95 days')::timestamptz, 'Single vendor; 14d lead time'),
  ('Apollo North','Patient Monitors','Philips', 220, 9200000, false, 64.10, 'verified', 'medium', (now() - interval '40 days')::timestamptz, 'Mindray pilot underway'),
  ('Manipal South','MRI 1.5T','GE Healthcare', 6, 42000000, true, 100.00, 'verified', 'critical',(now() - interval '180 days')::timestamptz, 'No 2nd source qualified'),
  ('Manipal South','C-Arm','Siemens', 18, 6700000, false, 71.30, 'verified', 'medium', (now() - interval '60 days')::timestamptz, 'Allengers being trialed'),
  ('Fortis West','Anesthesia','Drager', 32, 11200000, true, 88.00, 'pending',  'high',   (now() - interval '120 days')::timestamptz, 'KYC re-verify needed'),
  ('Fortis West','Defibrillators','Zoll', 95, 4100000, false, 55.40, 'verified', 'low',    (now() - interval '20 days')::timestamptz, 'Philips already qualified'),
  ('Max East','CT 128-slice','Siemens', 4, 38000000, true, 100.00, 'verified', 'critical',(now() - interval '210 days')::timestamptz, 'GE quote pending'),
  ('Max East','Ultrasound','Mindray', 60, 5400000, false, 48.20, 'verified', 'low',    (now() - interval '15 days')::timestamptz, 'Samsung backup live'),
  ('AIIMS Pan','Dialysis','Fresenius', 140, 16800000, true, 91.00, 'verified', 'high',   (now() - interval '85 days')::timestamptz, 'Nipro audit in flight'),
  ('AIIMS Pan','Infusion Pumps','BD', 880, 7200000, false, 62.50, 'verified', 'medium', (now() - interval '35 days')::timestamptz, 'Mindray secondary'),
  ('Narayana Chain','Cath Lab','Philips', 8, 28000000, true, 100.00, 'flagged', 'critical',(now() - interval '240 days')::timestamptz, 'KYC flagged — escalate'),
  ('Narayana Chain','ECG','GE Healthcare', 310, 3100000, false, 51.20, 'verified', 'low',    (now() - interval '10 days')::timestamptz, 'BPL qualified'),
  ('Medanta Trust','Linear Accelerator','Varian', 3, 64000000, true, 100.00, 'verified', 'critical',(now() - interval '300 days')::timestamptz, 'Elekta engagement opened'),
  ('Medanta Trust','Surgical Diathermy','Olympus', 42, 5600000, false, 58.40, 'verified', 'medium', (now() - interval '50 days')::timestamptz, 'Erbe quote received'),
  ('KIMS Hyderabad','Endoscopy','Olympus', 28, 8900000, true, 89.50, 'pending',  'high',   (now() - interval '140 days')::timestamptz, 'Pentax audit Q3'),
  ('KIMS Hyderabad','Autoclaves','Getinge', 22, 2400000, false, 44.00, 'verified', 'low',    (now() - interval '25 days')::timestamptz, 'Steelco qualified');

INSERT INTO hospital_chain_second_source_audits_r2923
  (chain_name, equipment_category, alternate_vendor, audit_quarter, qualification_score, price_delta_pct, lead_time_days, field_trial_units, recommended_share_pct, audit_status, audit_owner_email, signoff_at, audit_cost_rupees)
VALUES
  ('Apollo North','Ventilators','Mindray','Q2-2026', 82, -18.50, 21, 4, 30.00, 'qualified',   'biomed.lead@apollo.in', (now() - interval '12 days')::timestamptz, 240000),
  ('Apollo North','Patient Monitors','Mindray','Q2-2026', 88, -22.10, 18, 12, 40.00, 'qualified',   'biomed.lead@apollo.in', (now() - interval '8 days')::timestamptz, 180000),
  ('Manipal South','MRI 1.5T','Siemens','Q3-2026', 71, -8.20, 90, 1, 25.00, 'in_trial',    'cto@manipal.in',        NULL,                                       1100000),
  ('Manipal South','C-Arm','Allengers','Q2-2026', 76, -35.40, 28, 3, 35.00, 'qualified',   'cto@manipal.in',        (now() - interval '20 days')::timestamptz, 150000),
  ('Fortis West','Anesthesia','Mindray','Q3-2026', 79, -16.30, 24, 2, 30.00, 'in_trial',    'procure@fortis.in',     NULL,                                       320000),
  ('Fortis West','Defibrillators','Philips','Q1-2026', 91, -5.10, 14, 8, 45.00, 'qualified',   'procure@fortis.in',     (now() - interval '60 days')::timestamptz,  90000),
  ('Max East','CT 128-slice','GE Healthcare','Q3-2026', 84, -12.80, 75, 1, 35.00, 'in_trial',    'biomed@max.in',         NULL,                                       980000),
  ('Max East','Ultrasound','Samsung','Q1-2026', 86, -19.40, 16, 6, 40.00, 'qualified',   'biomed@max.in',         (now() - interval '70 days')::timestamptz, 110000),
  ('AIIMS Pan','Dialysis','Nipro','Q2-2026', 80, -14.20, 30, 5, 30.00, 'qualified',   'central.proc@aiims.in', (now() - interval '5 days')::timestamptz,  420000),
  ('AIIMS Pan','Infusion Pumps','Mindray','Q2-2026', 83, -21.00, 20, 30, 35.00, 'qualified',   'central.proc@aiims.in', (now() - interval '15 days')::timestamptz, 160000),
  ('Narayana Chain','Cath Lab','Siemens','Q3-2026', 68, -6.50, 120,1, 20.00, 'pending',     'cmo@narayana.in',       NULL,                                       1500000),
  ('Narayana Chain','ECG','BPL','Q1-2026', 89, -28.40, 12, 20, 45.00, 'qualified',   'cmo@narayana.in',       (now() - interval '90 days')::timestamptz,  60000),
  ('Medanta Trust','Linear Accelerator','Elekta','Q3-2026', 62, -4.20, 180,0, 15.00, 'pending',     'rad.head@medanta.in',   NULL,                                       2200000),
  ('Medanta Trust','Surgical Diathermy','Erbe','Q2-2026', 81, -7.40, 22, 4, 30.00, 'qualified',   'rad.head@medanta.in',   (now() - interval '18 days')::timestamptz, 140000),
  ('KIMS Hyderabad','Endoscopy','Pentax','Q3-2026', 74, -11.10, 35, 2, 25.00, 'in_trial',    'biomed@kims.in',        NULL,                                       380000),
  ('KIMS Hyderabad','Autoclaves','Steelco','Q1-2026', 87, -17.80, 18, 5, 45.00, 'qualified',   'biomed@kims.in',        (now() - interval '110 days')::timestamptz, 95000),
  ('Apollo North','MRI 1.5T','Siemens','Q3-2026', 72, -9.30, 95, 1, 25.00, 'in_trial',    'biomed.lead@apollo.in', NULL,                                       1200000),
  ('Fortis West','Patient Monitors','Mindray','Q3-2026', 85, -23.50, 17, 10, 40.00, 'qualified',   'procure@fortis.in',     (now() - interval '3 days')::timestamptz,  170000);

-- ============================================================================
-- RPCs (7+, all is_founder gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION r2923_chain_risk_overview()
RETURNS TABLE (chain_name text, units int, spend_rupees bigint, critical_lines int, high_lines int, single_source_lines int, last_audit_age_days int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_name,
           SUM(r.units_deployed)::int,
           SUM(r.annual_spend_rupees)::bigint,
           SUM(CASE WHEN r.risk_tier='critical' THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN r.risk_tier='high'     THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN r.single_source_flag    THEN 1 ELSE 0 END)::int,
           EXTRACT(DAY FROM (now() - MIN(r.last_audited_at)))::int
      FROM hospital_chain_equipment_vendor_risk_r2923 r
     GROUP BY r.chain_name
     ORDER BY SUM(r.annual_spend_rupees) DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_critical_single_source_lines()
RETURNS TABLE (chain_name text, equipment_category text, primary_vendor text, units int, spend_rupees bigint, concentration_pct numeric, risk_tier text, last_audited_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_name, r.equipment_category, r.primary_vendor,
           r.units_deployed, r.annual_spend_rupees, r.vendor_concentration_pct,
           r.risk_tier, r.last_audited_at
      FROM hospital_chain_equipment_vendor_risk_r2923 r
     WHERE r.single_source_flag = true
        OR r.risk_tier IN ('critical','high')
     ORDER BY r.annual_spend_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_quarterly_audit_pipeline()
RETURNS TABLE (audit_quarter text, total_audits int, qualified int, in_trial int, pending int, avg_score numeric, total_audit_cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.audit_quarter,
           COUNT(*)::int,
           SUM(CASE WHEN a.audit_status='qualified' THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN a.audit_status='in_trial'  THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN a.audit_status='pending'   THEN 1 ELSE 0 END)::int,
           ROUND(AVG(a.qualification_score)::numeric, 1),
           SUM(a.audit_cost_rupees)::bigint
      FROM hospital_chain_second_source_audits_r2923 a
     GROUP BY a.audit_quarter
     ORDER BY a.audit_quarter;
END $$;

CREATE OR REPLACE FUNCTION r2923_alternate_vendor_savings()
RETURNS TABLE (chain_name text, equipment_category text, alternate_vendor text, projected_savings_rupees bigint, recommended_share_pct numeric, qualification_score int, audit_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_name, r.equipment_category, a.alternate_vendor,
           ROUND(r.annual_spend_rupees * (a.recommended_share_pct/100.0) * (ABS(a.price_delta_pct)/100.0))::bigint AS projected_savings_rupees,
           a.recommended_share_pct, a.qualification_score, a.audit_status
      FROM hospital_chain_second_source_audits_r2923 a
      JOIN hospital_chain_equipment_vendor_risk_r2923 r
        ON r.chain_name = a.chain_name AND r.equipment_category = a.equipment_category
     ORDER BY projected_savings_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_lead_time_risk_lines()
RETURNS TABLE (chain_name text, equipment_category text, alternate_vendor text, lead_time_days int, audit_status text, qualification_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.chain_name, a.equipment_category, a.alternate_vendor, a.lead_time_days, a.audit_status, a.qualification_score
      FROM hospital_chain_second_source_audits_r2923 a
     WHERE a.lead_time_days >= 30
     ORDER BY a.lead_time_days DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_oem_kyc_attention()
RETURNS TABLE (chain_name text, equipment_category text, primary_vendor text, oem_kyc_status text, annual_spend_rupees bigint, last_audited_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_name, r.equipment_category, r.primary_vendor, r.oem_kyc_status, r.annual_spend_rupees, r.last_audited_at
      FROM hospital_chain_equipment_vendor_risk_r2923 r
     WHERE r.oem_kyc_status IN ('pending','flagged')
     ORDER BY r.annual_spend_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_audit_owner_workload()
RETURNS TABLE (audit_owner_email text, active_audits int, qualified int, in_trial int, pending int, avg_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.audit_owner_email,
           COUNT(*)::int,
           SUM(CASE WHEN a.audit_status='qualified' THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN a.audit_status='in_trial'  THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN a.audit_status='pending'   THEN 1 ELSE 0 END)::int,
           ROUND(AVG(a.qualification_score)::numeric, 1)
      FROM hospital_chain_second_source_audits_r2923 a
     GROUP BY a.audit_owner_email
     ORDER BY COUNT(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION r2923_top_savings_recommendations()
RETURNS TABLE (chain_name text, equipment_category text, alternate_vendor text, qualification_score int, price_delta_pct numeric, recommended_share_pct numeric, projected_savings_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.chain_name, a.equipment_category, a.alternate_vendor,
           a.qualification_score, a.price_delta_pct, a.recommended_share_pct,
           ROUND(r.annual_spend_rupees * (a.recommended_share_pct/100.0) * (ABS(a.price_delta_pct)/100.0))::bigint AS projected_savings_rupees
      FROM hospital_chain_second_source_audits_r2923 a
      JOIN hospital_chain_equipment_vendor_risk_r2923 r
        ON r.chain_name = a.chain_name AND r.equipment_category = a.equipment_category
     WHERE a.audit_status = 'qualified'
       AND a.qualification_score >= 80
     ORDER BY projected_savings_rupees DESC
     LIMIT 10;
END $$;

CREATE OR REPLACE FUNCTION r2923_chain_concentration_summary()
RETURNS TABLE (chain_name text, equipment_lines int, avg_concentration_pct numeric, max_concentration_pct numeric, single_source_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.chain_name,
           COUNT(*)::int,
           ROUND(AVG(r.vendor_concentration_pct)::numeric, 1),
           MAX(r.vendor_concentration_pct),
           SUM(CASE WHEN r.single_source_flag THEN 1 ELSE 0 END)::int
      FROM hospital_chain_equipment_vendor_risk_r2923 r
     GROUP BY r.chain_name
     ORDER BY MAX(r.vendor_concentration_pct) DESC;
END $$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION r2923_chain_risk_overview()            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_critical_single_source_lines()   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_quarterly_audit_pipeline()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_alternate_vendor_savings()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_lead_time_risk_lines()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_oem_kyc_attention()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_audit_owner_workload()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_top_savings_recommendations()    FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2923_chain_concentration_summary()    FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION r2923_chain_risk_overview()            TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_critical_single_source_lines()   TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_quarterly_audit_pipeline()       TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_alternate_vendor_savings()       TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_lead_time_risk_lines()           TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_oem_kyc_attention()              TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_audit_owner_workload()           TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_top_savings_recommendations()    TO authenticated;
GRANT EXECUTE ON FUNCTION r2923_chain_concentration_summary()    TO authenticated;

COMMIT;
