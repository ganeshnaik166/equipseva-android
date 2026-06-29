-- Round 2934: Engineer Monthly Customer-Site First-Aid Kit & Emergency Eyewash Audit

-- =========================
-- Table 1: first-aid kit audits
-- =========================
CREATE TABLE IF NOT EXISTS first_aid_kit_audits_r2934 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  site_code text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  engineer_code text NOT NULL,
  kit_location text NOT NULL,
  total_items_required int NOT NULL,
  items_present int NOT NULL,
  items_expired int NOT NULL,
  items_missing int NOT NULL,
  compliance_score numeric(5,2) NOT NULL,
  status text NOT NULL CHECK (status IN ('compliant','minor_gap','major_gap','critical_gap')),
  replenishment_cost_rupees int NOT NULL,
  replenished boolean NOT NULL DEFAULT false,
  notes text
);

ALTER TABLE first_aid_kit_audits_r2934 ENABLE ROW LEVEL SECURITY;

-- =========================
-- Table 2: eyewash station audits
-- =========================
CREATE TABLE IF NOT EXISTS eyewash_station_audits_r2934 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  site_code text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  engineer_code text NOT NULL,
  station_location text NOT NULL,
  flow_rate_lpm numeric(5,2) NOT NULL,
  water_temp_celsius numeric(5,2) NOT NULL,
  activation_time_seconds numeric(5,2) NOT NULL,
  signage_ok boolean NOT NULL,
  clear_access boolean NOT NULL,
  last_flushed_days_ago int NOT NULL,
  ansi_z358_compliant boolean NOT NULL,
  status text NOT NULL CHECK (status IN ('pass','warning','fail','out_of_service')),
  remediation_needed boolean NOT NULL DEFAULT false,
  remediation_cost_rupees int NOT NULL DEFAULT 0
);

ALTER TABLE eyewash_station_audits_r2934 ENABLE ROW LEVEL SECURITY;

-- =========================
-- Seeds: first_aid_kit_audits_r2934 (18 rows)
-- =========================
INSERT INTO first_aid_kit_audits_r2934 (audit_month, site_code, hospital_name, city, engineer_code, kit_location, total_items_required, items_present, items_expired, items_missing, compliance_score, status, replenishment_cost_rupees, replenished, notes) VALUES
('2026-06-01'::date, 'HYD-APO-01', 'Apollo Jubilee Hills', 'Hyderabad', 'ENG-014', 'Cath Lab Workshop', 42, 41, 1, 0, 97.62, 'compliant', 850, true, 'Replaced expired Betadine'),
('2026-06-01'::date, 'BLR-MAN-02', 'Manipal Old Airport', 'Bangalore', 'ENG-007', 'Biomed Bay 3', 42, 38, 2, 2, 85.71, 'minor_gap', 1450, true, 'Burnshield and saline expired'),
('2026-06-01'::date, 'CHE-FOR-01', 'Fortis Vadapalani', 'Chennai', 'ENG-021', 'Service Room G2', 42, 33, 3, 6, 71.43, 'major_gap', 3200, true, 'Major restock, 6 gauze packs missing'),
('2026-06-01'::date, 'MUM-KOK-03', 'Kokilaben Mumbai', 'Mumbai', 'ENG-009', 'Workshop B1', 42, 42, 0, 0, 100.00, 'compliant', 0, false, 'Perfect inventory'),
('2026-06-01'::date, 'DEL-MAX-01', 'Max Saket', 'Delhi', 'ENG-018', 'Radiology Workshop', 42, 28, 5, 9, 57.14, 'critical_gap', 5800, true, 'Adrenaline auto-injector expired'),
('2026-06-01'::date, 'PUN-RUB-02', 'Ruby Hall Clinic', 'Pune', 'ENG-012', 'Engineering Annex', 42, 40, 1, 1, 92.86, 'compliant', 620, true, 'Replaced eye-patch + iodine'),
('2026-06-01'::date, 'KOL-AMR-01', 'AMRI Salt Lake', 'Kolkata', 'ENG-025', 'OT Service Corridor', 42, 36, 3, 3, 80.95, 'minor_gap', 1850, true, 'Bandages restocked'),
('2026-06-01'::date, 'HYD-YAS-04', 'Yashoda Secunderabad', 'Hyderabad', 'ENG-014', 'CSSD Workshop', 42, 39, 2, 1, 88.10, 'minor_gap', 950, true, 'Antiseptic wipes replaced'),
('2026-05-01'::date, 'HYD-APO-01', 'Apollo Jubilee Hills', 'Hyderabad', 'ENG-014', 'Cath Lab Workshop', 42, 40, 1, 1, 92.86, 'compliant', 720, true, 'May audit'),
('2026-05-01'::date, 'BLR-MAN-02', 'Manipal Old Airport', 'Bangalore', 'ENG-007', 'Biomed Bay 3', 42, 35, 3, 4, 78.57, 'minor_gap', 2100, true, 'May audit'),
('2026-05-01'::date, 'CHE-FOR-01', 'Fortis Vadapalani', 'Chennai', 'ENG-021', 'Service Room G2', 42, 30, 4, 8, 65.08, 'major_gap', 4100, true, 'Recurring critical gap pattern'),
('2026-06-01'::date, 'AHM-STE-01', 'Sterling Ahmedabad', 'Ahmedabad', 'ENG-031', 'Tech Bay', 42, 41, 0, 1, 97.62, 'compliant', 280, true, 'Single gauze missing'),
('2026-06-01'::date, 'JAI-FOR-02', 'Fortis Escorts Jaipur', 'Jaipur', 'ENG-019', 'OT Workshop', 42, 37, 2, 3, 82.54, 'minor_gap', 1680, false, 'Pending replenishment from supplier'),
('2026-06-01'::date, 'LUC-MED-01', 'Medanta Lucknow', 'Lucknow', 'ENG-027', 'Biomed Floor 2', 42, 25, 6, 11, 47.62, 'critical_gap', 6900, false, 'Site flagged for re-audit in 7 days'),
('2026-06-01'::date, 'COI-KMC-01', 'KMCH Coimbatore', 'Coimbatore', 'ENG-033', 'Workshop A', 42, 42, 0, 0, 100.00, 'compliant', 0, false, 'Reference site'),
('2026-06-01'::date, 'BHU-AIM-01', 'AIIMS Bhubaneswar', 'Bhubaneswar', 'ENG-035', 'BME Lab', 42, 38, 1, 3, 88.10, 'minor_gap', 1320, true, 'Govt hospital, slow procurement'),
('2026-06-01'::date, 'CHA-PGI-01', 'PGIMER Chandigarh', 'Chandigarh', 'ENG-040', 'Engineering Workshop', 42, 34, 4, 4, 76.19, 'major_gap', 2750, true, 'Multiple expiry concerns'),
('2026-06-01'::date, 'IND-CHL-01', 'CHL Indore', 'Indore', 'ENG-044', 'Service Bay', 42, 40, 1, 1, 92.86, 'compliant', 540, true, 'Routine top-up');

-- =========================
-- Seeds: eyewash_station_audits_r2934 (18 rows)
-- =========================
INSERT INTO eyewash_station_audits_r2934 (audit_month, site_code, hospital_name, city, engineer_code, station_location, flow_rate_lpm, water_temp_celsius, activation_time_seconds, signage_ok, clear_access, last_flushed_days_ago, ansi_z358_compliant, status, remediation_needed, remediation_cost_rupees) VALUES
('2026-06-01'::date, 'HYD-APO-01', 'Apollo Jubilee Hills', 'Hyderabad', 'ENG-014', 'Sterilization Room', 11.50, 22.50, 0.80, true, true, 5, true, 'pass', false, 0),
('2026-06-01'::date, 'BLR-MAN-02', 'Manipal Old Airport', 'Bangalore', 'ENG-007', 'Lab Chemistry', 9.20, 24.10, 1.20, true, true, 12, false, 'warning', true, 4500),
('2026-06-01'::date, 'CHE-FOR-01', 'Fortis Vadapalani', 'Chennai', 'ENG-021', 'Pathology Wet Lab', 6.80, 28.30, 2.10, false, false, 35, false, 'fail', true, 12000),
('2026-06-01'::date, 'MUM-KOK-03', 'Kokilaben Mumbai', 'Mumbai', 'ENG-009', 'CSSD Decontamination', 12.30, 21.80, 0.60, true, true, 3, true, 'pass', false, 0),
('2026-06-01'::date, 'DEL-MAX-01', 'Max Saket', 'Delhi', 'ENG-018', 'Endoscopy Reprocessing', 4.20, 32.10, 3.50, false, false, 90, false, 'out_of_service', true, 28000),
('2026-06-01'::date, 'PUN-RUB-02', 'Ruby Hall Clinic', 'Pune', 'ENG-012', 'Histopath Lab', 11.10, 23.40, 0.90, true, true, 7, true, 'pass', false, 0),
('2026-06-01'::date, 'KOL-AMR-01', 'AMRI Salt Lake', 'Kolkata', 'ENG-025', 'CSSD Wash Bay', 8.60, 25.80, 1.40, true, false, 18, false, 'warning', true, 3200),
('2026-06-01'::date, 'HYD-YAS-04', 'Yashoda Secunderabad', 'Hyderabad', 'ENG-014', 'Lab Microbiology', 11.90, 22.10, 0.70, true, true, 4, true, 'pass', false, 0),
('2026-05-01'::date, 'HYD-APO-01', 'Apollo Jubilee Hills', 'Hyderabad', 'ENG-014', 'Sterilization Room', 11.30, 22.80, 0.85, true, true, 6, true, 'pass', false, 0),
('2026-05-01'::date, 'CHE-FOR-01', 'Fortis Vadapalani', 'Chennai', 'ENG-021', 'Pathology Wet Lab', 7.10, 27.90, 1.95, false, true, 28, false, 'fail', true, 10500),
('2026-05-01'::date, 'DEL-MAX-01', 'Max Saket', 'Delhi', 'ENG-018', 'Endoscopy Reprocessing', 5.80, 30.20, 2.80, false, false, 60, false, 'fail', true, 18500),
('2026-06-01'::date, 'AHM-STE-01', 'Sterling Ahmedabad', 'Ahmedabad', 'ENG-031', 'Lab Hematology', 11.70, 23.10, 0.75, true, true, 4, true, 'pass', false, 0),
('2026-06-01'::date, 'JAI-FOR-02', 'Fortis Escorts Jaipur', 'Jaipur', 'ENG-019', 'CSSD Area', 9.50, 24.60, 1.30, true, true, 14, false, 'warning', true, 2800),
('2026-06-01'::date, 'LUC-MED-01', 'Medanta Lucknow', 'Lucknow', 'ENG-027', 'Endo Reprocessing', 3.80, 33.50, 4.20, false, false, 120, false, 'out_of_service', true, 32000),
('2026-06-01'::date, 'COI-KMC-01', 'KMCH Coimbatore', 'Coimbatore', 'ENG-033', 'Sterile Processing', 12.00, 22.00, 0.65, true, true, 2, true, 'pass', false, 0),
('2026-06-01'::date, 'BHU-AIM-01', 'AIIMS Bhubaneswar', 'Bhubaneswar', 'ENG-035', 'Lab Block', 8.90, 25.20, 1.50, true, false, 22, false, 'warning', true, 3900),
('2026-06-01'::date, 'CHA-PGI-01', 'PGIMER Chandigarh', 'Chandigarh', 'ENG-040', 'Histopath Wet Area', 7.40, 27.10, 1.85, false, false, 32, false, 'fail', true, 9200),
('2026-06-01'::date, 'IND-CHL-01', 'CHL Indore', 'Indore', 'ENG-044', 'CSSD Decontam', 11.40, 23.30, 0.80, true, true, 6, true, 'pass', false, 0);

-- =========================
-- is_founder helper assumed present in public schema
-- =========================

-- RPC 1: monthly compliance overview
CREATE OR REPLACE FUNCTION rpc_r2934_monthly_compliance_overview()
RETURNS TABLE(audit_month date, sites_audited int, compliant_sites int, critical_sites int, avg_compliance numeric, total_replenish_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.audit_month,
         count(*)::int AS sites_audited,
         (count(*) filter (where k.status='compliant'))::int AS compliant_sites,
         (count(*) filter (where k.status='critical_gap'))::int AS critical_sites,
         round(avg(k.compliance_score), 2) AS avg_compliance,
         sum(k.replenishment_cost_rupees)::bigint AS total_replenish_rupees
  FROM first_aid_kit_audits_r2934 k
  GROUP BY k.audit_month
  ORDER BY k.audit_month DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_monthly_compliance_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_monthly_compliance_overview() TO authenticated;

-- RPC 2: critical sites list
CREATE OR REPLACE FUNCTION rpc_r2934_critical_sites()
RETURNS TABLE(site_code text, hospital_name text, city text, compliance_score numeric, items_missing int, items_expired int, replenished boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.site_code, k.hospital_name, k.city, k.compliance_score, k.items_missing, k.items_expired, k.replenished
  FROM first_aid_kit_audits_r2934 k
  WHERE k.status IN ('major_gap','critical_gap')
    AND k.audit_month = (SELECT max(audit_month) FROM first_aid_kit_audits_r2934)
  ORDER BY k.compliance_score ASC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_critical_sites() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_critical_sites() TO authenticated;

-- RPC 3: engineer leaderboard
CREATE OR REPLACE FUNCTION rpc_r2934_engineer_leaderboard()
RETURNS TABLE(engineer_code text, audits_completed int, avg_compliance numeric, critical_findings int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.engineer_code,
         count(*)::int AS audits_completed,
         round(avg(k.compliance_score), 2) AS avg_compliance,
         (count(*) filter (where k.status='critical_gap'))::int AS critical_findings
  FROM first_aid_kit_audits_r2934 k
  GROUP BY k.engineer_code
  ORDER BY avg_compliance DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_engineer_leaderboard() TO authenticated;

-- RPC 4: eyewash status snapshot
CREATE OR REPLACE FUNCTION rpc_r2934_eyewash_status_snapshot()
RETURNS TABLE(status text, station_count int, total_remediation_rupees bigint, avg_flow_lpm numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.status,
         count(*)::int AS station_count,
         sum(e.remediation_cost_rupees)::bigint AS total_remediation_rupees,
         round(avg(e.flow_rate_lpm), 2) AS avg_flow_lpm
  FROM eyewash_station_audits_r2934 e
  WHERE e.audit_month = (SELECT max(audit_month) FROM eyewash_station_audits_r2934)
  GROUP BY e.status
  ORDER BY station_count DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_eyewash_status_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_eyewash_status_snapshot() TO authenticated;

-- RPC 5: ANSI Z358 non-compliant stations
CREATE OR REPLACE FUNCTION rpc_r2934_ansi_z358_failures()
RETURNS TABLE(site_code text, hospital_name text, station_location text, flow_rate_lpm numeric, water_temp_celsius numeric, activation_time_seconds numeric, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.site_code, e.hospital_name, e.station_location, e.flow_rate_lpm, e.water_temp_celsius, e.activation_time_seconds, e.status
  FROM eyewash_station_audits_r2934 e
  WHERE e.ansi_z358_compliant = false
    AND e.audit_month = (SELECT max(audit_month) FROM eyewash_station_audits_r2934)
  ORDER BY e.flow_rate_lpm ASC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_ansi_z358_failures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_ansi_z358_failures() TO authenticated;

-- RPC 6: city rollup
CREATE OR REPLACE FUNCTION rpc_r2934_city_rollup()
RETURNS TABLE(city text, kit_avg_compliance numeric, eyewash_pass_rate numeric, total_sites int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH kit AS (
    SELECT k.city, round(avg(k.compliance_score),2) AS kavg, count(distinct k.site_code) AS sites
    FROM first_aid_kit_audits_r2934 k
    WHERE k.audit_month = (SELECT max(audit_month) FROM first_aid_kit_audits_r2934)
    GROUP BY k.city
  ), ew AS (
    SELECT e.city,
           round(100.0 * (count(*) filter (where e.status='pass'))::numeric / nullif(count(*),0), 2) AS pass_rate
    FROM eyewash_station_audits_r2934 e
    WHERE e.audit_month = (SELECT max(audit_month) FROM eyewash_station_audits_r2934)
    GROUP BY e.city
  )
  SELECT kit.city, kit.kavg, coalesce(ew.pass_rate, 0), kit.sites::int
  FROM kit LEFT JOIN ew ON ew.city = kit.city
  ORDER BY kit.kavg DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_city_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_city_rollup() TO authenticated;

-- RPC 7: replenishment backlog
CREATE OR REPLACE FUNCTION rpc_r2934_replenishment_backlog()
RETURNS TABLE(site_code text, hospital_name text, city text, replenishment_cost_rupees int, status text, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.site_code, k.hospital_name, k.city, k.replenishment_cost_rupees, k.status, k.notes
  FROM first_aid_kit_audits_r2934 k
  WHERE k.replenished = false
    AND k.audit_month = (SELECT max(audit_month) FROM first_aid_kit_audits_r2934)
  ORDER BY k.replenishment_cost_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_replenishment_backlog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_replenishment_backlog() TO authenticated;

-- RPC 8: month-over-month trend per site
CREATE OR REPLACE FUNCTION rpc_r2934_mom_trend()
RETURNS TABLE(site_code text, hospital_name text, current_score numeric, previous_score numeric, delta numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT k.site_code, k.hospital_name, k.audit_month, k.compliance_score,
           row_number() OVER (PARTITION BY k.site_code ORDER BY k.audit_month DESC) AS rn
    FROM first_aid_kit_audits_r2934 k
  )
  SELECT cur.site_code, cur.hospital_name, cur.compliance_score, prev.compliance_score,
         (cur.compliance_score - prev.compliance_score)
  FROM ranked cur
  JOIN ranked prev ON prev.site_code = cur.site_code AND prev.rn = 2
  WHERE cur.rn = 1
  ORDER BY (cur.compliance_score - prev.compliance_score) ASC;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_r2934_mom_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2934_mom_trend() TO authenticated;
