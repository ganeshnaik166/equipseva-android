-- Round 2911: Hospital Chain Quarterly Endoscope Reprocessing Compliance Tracker
-- Heavy founder ops round: 2 tables (_r2911) + 7 RPCs (is_founder gated) + seeds

BEGIN;

-- =========================================================================
-- TABLE 1: endoscope_reprocessing_cycles_r2911
-- Tracks individual reprocessing cycles per hospital chain per scope per quarter
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.endoscope_reprocessing_cycles_r2911 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_chain_name text NOT NULL,
  hospital_branch_city text NOT NULL,
  scope_model text NOT NULL,
  scope_serial text NOT NULL,
  quarter_label text NOT NULL,
  cycle_date timestamptz NOT NULL,
  reprocessing_stage text NOT NULL CHECK (reprocessing_stage IN ('precleaning','leak_test','manual_clean','high_level_disinfection','sterilization','drying','storage')),
  cycle_duration_minutes int NOT NULL,
  chemical_used text NOT NULL,
  chemical_concentration_ppm int NOT NULL,
  temperature_celsius numeric(5,2) NOT NULL,
  technician_initials text NOT NULL,
  passed_protocol boolean NOT NULL,
  deviation_notes text,
  audit_photo_count int NOT NULL DEFAULT 0,
  cost_per_cycle_rupees int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.endoscope_reprocessing_cycles_r2911 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE 2: endoscope_compliance_incidents_r2911
-- Tracks compliance incidents flagged from cycle audits
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.endoscope_compliance_incidents_r2911 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_chain_name text NOT NULL,
  hospital_branch_city text NOT NULL,
  quarter_label text NOT NULL,
  incident_opened_at timestamptz NOT NULL,
  incident_category text NOT NULL CHECK (incident_category IN ('chemical_underdose','time_shortcut','missed_leak_test','temperature_excursion','drying_skipped','storage_breach','documentation_gap','technician_uncertified')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  scope_serial text NOT NULL,
  patients_exposed_count int NOT NULL DEFAULT 0,
  root_cause text NOT NULL,
  corrective_action text NOT NULL,
  resolved boolean NOT NULL DEFAULT false,
  resolution_days int,
  regulatory_reported boolean NOT NULL DEFAULT false,
  fine_imposed_rupees int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.endoscope_compliance_incidents_r2911 ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- SEEDS: reprocessing cycles (24 rows)
-- =========================================================================
INSERT INTO public.endoscope_reprocessing_cycles_r2911
  (hospital_chain_name, hospital_branch_city, scope_model, scope_serial, quarter_label, cycle_date, reprocessing_stage, cycle_duration_minutes, chemical_used, chemical_concentration_ppm, temperature_celsius, technician_initials, passed_protocol, deviation_notes, audit_photo_count, cost_per_cycle_rupees)
VALUES
  ('Apollo Group','Hyderabad','Olympus CF-HQ190L','OLY-HQ-44120','Q1-2026','2026-01-08T09:15:00+05:30'::timestamptz,'high_level_disinfection',12,'OPA 0.55%',5500,21.50,'RKM',true,NULL,4,420),
  ('Apollo Group','Hyderabad','Olympus GIF-H190','OLY-GIF-77821','Q1-2026','2026-01-09T11:00:00+05:30'::timestamptz,'manual_clean',9,'Enzymatic detergent',8000,32.00,'SVK',true,NULL,3,260),
  ('Apollo Group','Chennai','Pentax EG29-i10','PEN-EG-23104','Q1-2026','2026-01-12T08:30:00+05:30'::timestamptz,'leak_test',4,'N/A',0,22.00,'AMR',true,NULL,2,90),
  ('Apollo Group','Chennai','Olympus CF-HQ190L','OLY-HQ-44128','Q1-2026','2026-01-14T15:45:00+05:30'::timestamptz,'sterilization',55,'Hydrogen peroxide vapor',9500,55.00,'DKR',true,NULL,5,820),
  ('Fortis Healthcare','Bengaluru','Pentax EC38-i10F','PEN-EC-50991','Q1-2026','2026-01-16T10:20:00+05:30'::timestamptz,'high_level_disinfection',10,'OPA 0.55%',4900,20.80,'NRS',false,'Concentration below 5000 ppm minimum',6,420),
  ('Fortis Healthcare','Bengaluru','Olympus GIF-H190','OLY-GIF-77845','Q1-2026','2026-01-18T13:10:00+05:30'::timestamptz,'drying',18,'Forced air HEPA',0,38.00,'NRS',true,NULL,2,140),
  ('Fortis Healthcare','Mumbai','Fujifilm EG-760R','FUJ-EG-12044','Q1-2026','2026-01-20T09:00:00+05:30'::timestamptz,'precleaning',5,'Enzymatic wipe',6500,23.00,'PSM',true,NULL,2,80),
  ('Fortis Healthcare','Mumbai','Olympus CF-HQ190L','OLY-HQ-44131','Q2-2026','2026-04-02T10:30:00+05:30'::timestamptz,'high_level_disinfection',11,'OPA 0.55%',5400,21.00,'PSM',true,NULL,4,420),
  ('Manipal Hospitals','Bengaluru','Pentax EG29-i10','PEN-EG-23115','Q2-2026','2026-04-05T08:00:00+05:30'::timestamptz,'manual_clean',7,'Enzymatic detergent',7200,30.00,'KVL',false,'Cycle shortened by 3 minutes',5,260),
  ('Manipal Hospitals','Bengaluru','Olympus GIF-H190','OLY-GIF-77855','Q2-2026','2026-04-06T11:30:00+05:30'::timestamptz,'storage',1440,'N/A',0,24.00,'KVL',true,NULL,1,30),
  ('Manipal Hospitals','Pune','Fujifilm EG-760R','FUJ-EG-12055','Q2-2026','2026-04-08T14:15:00+05:30'::timestamptz,'leak_test',3,'N/A',0,22.50,'ABG',true,NULL,2,90),
  ('Manipal Hospitals','Pune','Pentax EC38-i10F','PEN-EC-51002','Q2-2026','2026-04-10T16:00:00+05:30'::timestamptz,'high_level_disinfection',12,'OPA 0.55%',5600,21.20,'ABG',true,NULL,4,420),
  ('Max Healthcare','Delhi','Olympus CF-HQ190L','OLY-HQ-44144','Q2-2026','2026-04-14T09:45:00+05:30'::timestamptz,'sterilization',58,'Hydrogen peroxide vapor',9800,56.00,'JHN',true,NULL,5,820),
  ('Max Healthcare','Delhi','Pentax EG29-i10','PEN-EG-23128','Q2-2026','2026-04-15T10:30:00+05:30'::timestamptz,'high_level_disinfection',8,'OPA 0.55%',5100,20.50,'JHN',false,'Contact time below 12 minute minimum',6,420),
  ('Max Healthcare','Gurugram','Olympus GIF-H190','OLY-GIF-77866','Q2-2026','2026-04-17T13:20:00+05:30'::timestamptz,'manual_clean',10,'Enzymatic detergent',8100,31.50,'TPN',true,NULL,3,260),
  ('Narayana Health','Bengaluru','Fujifilm EG-760R','FUJ-EG-12068','Q3-2026','2026-07-03T09:00:00+05:30'::timestamptz,'precleaning',6,'Enzymatic wipe',6800,23.50,'CHK',true,NULL,2,80),
  ('Narayana Health','Bengaluru','Olympus CF-HQ190L','OLY-HQ-44158','Q3-2026','2026-07-05T11:15:00+05:30'::timestamptz,'high_level_disinfection',13,'OPA 0.55%',5700,21.80,'CHK',true,NULL,4,420),
  ('Narayana Health','Kolkata','Pentax EC38-i10F','PEN-EC-51020','Q3-2026','2026-07-08T14:40:00+05:30'::timestamptz,'drying',16,'Forced air HEPA',0,37.00,'BRA',false,'Drying time below 18 minute standard',2,140),
  ('Medanta','Gurugram','Olympus GIF-H190','OLY-GIF-77881','Q3-2026','2026-07-12T10:00:00+05:30'::timestamptz,'sterilization',60,'Hydrogen peroxide vapor',10000,55.50,'VSH',true,NULL,5,820),
  ('Medanta','Gurugram','Pentax EG29-i10','PEN-EG-23140','Q3-2026','2026-07-14T15:30:00+05:30'::timestamptz,'leak_test',4,'N/A',0,22.20,'VSH',true,NULL,2,90),
  ('Medanta','Lucknow','Olympus CF-HQ190L','OLY-HQ-44170','Q3-2026','2026-07-18T08:45:00+05:30'::timestamptz,'high_level_disinfection',11,'OPA 0.55%',5500,21.00,'MGT',true,NULL,4,420),
  ('AIG Hospitals','Hyderabad','Fujifilm EG-760R','FUJ-EG-12080','Q3-2026','2026-07-22T12:00:00+05:30'::timestamptz,'manual_clean',9,'Enzymatic detergent',7800,32.50,'RVN',true,NULL,3,260),
  ('AIG Hospitals','Hyderabad','Olympus GIF-H190','OLY-GIF-77895','Q3-2026','2026-07-25T14:00:00+05:30'::timestamptz,'storage',1380,'N/A',0,23.50,'RVN',false,'Storage cabinet humidity above 65 percent',1,30),
  ('AIG Hospitals','Visakhapatnam','Pentax EC38-i10F','PEN-EC-51035','Q3-2026','2026-07-28T09:30:00+05:30'::timestamptz,'high_level_disinfection',12,'OPA 0.55%',5600,21.30,'GPL',true,NULL,4,420);

-- =========================================================================
-- SEEDS: compliance incidents (15 rows)
-- =========================================================================
INSERT INTO public.endoscope_compliance_incidents_r2911
  (hospital_chain_name, hospital_branch_city, quarter_label, incident_opened_at, incident_category, severity, scope_serial, patients_exposed_count, root_cause, corrective_action, resolved, resolution_days, regulatory_reported, fine_imposed_rupees)
VALUES
  ('Apollo Group','Hyderabad','Q1-2026','2026-01-22T14:00:00+05:30'::timestamptz,'documentation_gap','p3','OLY-HQ-44120',0,'Technician failed to log chemical lot number','Retraining session conducted',true,3,false,0),
  ('Fortis Healthcare','Bengaluru','Q1-2026','2026-01-18T09:30:00+05:30'::timestamptz,'chemical_underdose','p1','PEN-EC-50991',12,'OPA solution past replacement cycle','Solution replaced; 12 patients flagged for follow-up',true,7,true,250000),
  ('Fortis Healthcare','Mumbai','Q1-2026','2026-02-05T11:00:00+05:30'::timestamptz,'missed_leak_test','p2','OLY-GIF-77845',4,'Workflow checklist skipped during shift handover','SOP updated; mandatory dual-sign added',true,5,false,0),
  ('Manipal Hospitals','Bengaluru','Q2-2026','2026-04-07T16:00:00+05:30'::timestamptz,'time_shortcut','p1','PEN-EG-23115',8,'Volume pressure led to 3-minute shortcut','Throughput cap imposed; second AER procured',true,11,true,180000),
  ('Manipal Hospitals','Pune','Q2-2026','2026-04-25T10:15:00+05:30'::timestamptz,'technician_uncertified','p2','PEN-EC-51002',0,'New hire used scope before CSSD certification','Hire suspended; certification fast-track started',true,4,false,0),
  ('Max Healthcare','Delhi','Q2-2026','2026-04-16T08:00:00+05:30'::timestamptz,'chemical_underdose','p0','PEN-EG-23128',23,'Concentration drift undetected for 6 cycles','Patient lookback initiated; CDSCO informed',false,NULL,true,750000),
  ('Max Healthcare','Gurugram','Q2-2026','2026-05-03T13:30:00+05:30'::timestamptz,'documentation_gap','p3','OLY-GIF-77866',0,'Photo audit count below threshold','Camera workflow upgraded',true,2,false,0),
  ('Narayana Health','Kolkata','Q3-2026','2026-07-09T15:00:00+05:30'::timestamptz,'drying_skipped','p1','PEN-EC-51020',5,'Drying station offline; manual hang used','Backup drying station installed',true,6,true,120000),
  ('Narayana Health','Bengaluru','Q3-2026','2026-07-20T10:00:00+05:30'::timestamptz,'temperature_excursion','p2','OLY-HQ-44158',0,'AER thermostat drift','Vendor calibration completed',true,8,false,0),
  ('Medanta','Gurugram','Q3-2026','2026-07-15T11:30:00+05:30'::timestamptz,'documentation_gap','p3','OLY-GIF-77881',0,'Cycle log not synced to central LIMS','LIMS integration patch deployed',true,3,false,0),
  ('Medanta','Lucknow','Q3-2026','2026-08-02T09:00:00+05:30'::timestamptz,'missed_leak_test','p2','OLY-HQ-44170',2,'Tech assumed prior shift completed test','Mandatory pre-procedure leak test enforced',true,5,false,0),
  ('AIG Hospitals','Hyderabad','Q3-2026','2026-07-26T14:00:00+05:30'::timestamptz,'storage_breach','p2','OLY-GIF-77895',0,'Cabinet HVAC failure overnight','HVAC replaced; humidity sensors added',true,4,false,0),
  ('AIG Hospitals','Visakhapatnam','Q3-2026','2026-08-10T08:30:00+05:30'::timestamptz,'time_shortcut','p1','PEN-EC-51035',6,'Emergency case bumped reprocessing queue','Triage SOP rewritten',true,9,true,150000),
  ('Apollo Group','Chennai','Q1-2026','2026-02-12T12:00:00+05:30'::timestamptz,'technician_uncertified','p2','PEN-EG-23104',0,'Float tech used without CSSD sign-off','Float pool credentials audited',true,6,false,0),
  ('Fortis Healthcare','Bengaluru','Q2-2026','2026-05-18T11:00:00+05:30'::timestamptz,'temperature_excursion','p1','PEN-EC-50991',3,'AER heater coil burned out mid-cycle','Coil replaced; quarterly PM added',true,7,true,90000);

-- =========================================================================
-- HELPER: is_founder check (assumed to exist as public.is_founder())
-- =========================================================================

-- =========================================================================
-- RPC 1: chain compliance summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_chain_compliance_summary()
RETURNS TABLE (
  hospital_chain_name text,
  total_cycles bigint,
  failed_cycles bigint,
  pass_rate_pct numeric,
  total_incidents bigint,
  unresolved_incidents bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.hospital_chain_name,
    COUNT(*)::bigint AS total_cycles,
    COUNT(*) FILTER (WHERE NOT c.passed_protocol)::bigint AS failed_cycles,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.passed_protocol) / NULLIF(COUNT(*),0), 1) AS pass_rate_pct,
    (SELECT COUNT(*) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.hospital_chain_name = c.hospital_chain_name)::bigint AS total_incidents,
    (SELECT COUNT(*) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.hospital_chain_name = c.hospital_chain_name AND NOT i.resolved)::bigint AS unresolved_incidents
  FROM public.endoscope_reprocessing_cycles_r2911 c
  GROUP BY c.hospital_chain_name
  ORDER BY pass_rate_pct ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_chain_compliance_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_chain_compliance_summary() TO authenticated;

-- =========================================================================
-- RPC 2: stage-level failure breakdown
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_stage_failure_breakdown()
RETURNS TABLE (
  reprocessing_stage text,
  total_cycles bigint,
  failures bigint,
  failure_rate_pct numeric,
  avg_duration_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.reprocessing_stage,
    COUNT(*)::bigint AS total_cycles,
    COUNT(*) FILTER (WHERE NOT c.passed_protocol)::bigint AS failures,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT c.passed_protocol) / NULLIF(COUNT(*),0), 1) AS failure_rate_pct,
    ROUND(AVG(c.cycle_duration_minutes)::numeric, 1) AS avg_duration_minutes
  FROM public.endoscope_reprocessing_cycles_r2911 c
  GROUP BY c.reprocessing_stage
  ORDER BY failure_rate_pct DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_stage_failure_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_stage_failure_breakdown() TO authenticated;

-- =========================================================================
-- RPC 3: quarterly trend
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_quarterly_trend()
RETURNS TABLE (
  quarter_label text,
  cycles_count bigint,
  failed_count bigint,
  incidents_count bigint,
  total_fines_rupees bigint,
  patients_exposed bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    q.quarter_label,
    (SELECT COUNT(*) FROM public.endoscope_reprocessing_cycles_r2911 c WHERE c.quarter_label = q.quarter_label)::bigint,
    (SELECT COUNT(*) FROM public.endoscope_reprocessing_cycles_r2911 c WHERE c.quarter_label = q.quarter_label AND NOT c.passed_protocol)::bigint,
    (SELECT COUNT(*) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.quarter_label = q.quarter_label)::bigint,
    COALESCE((SELECT SUM(i.fine_imposed_rupees) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.quarter_label = q.quarter_label),0)::bigint,
    COALESCE((SELECT SUM(i.patients_exposed_count) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.quarter_label = q.quarter_label),0)::bigint
  FROM (SELECT DISTINCT quarter_label FROM public.endoscope_reprocessing_cycles_r2911) q
  ORDER BY q.quarter_label;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_quarterly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_quarterly_trend() TO authenticated;

-- =========================================================================
-- RPC 4: top-risk scopes (most failed cycles per serial)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_top_risk_scopes()
RETURNS TABLE (
  scope_serial text,
  scope_model text,
  hospital_chain_name text,
  hospital_branch_city text,
  total_cycles bigint,
  failed_cycles bigint,
  fail_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.scope_serial,
    MAX(c.scope_model) AS scope_model,
    MAX(c.hospital_chain_name) AS hospital_chain_name,
    MAX(c.hospital_branch_city) AS hospital_branch_city,
    COUNT(*)::bigint AS total_cycles,
    COUNT(*) FILTER (WHERE NOT c.passed_protocol)::bigint AS failed_cycles,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT c.passed_protocol) / NULLIF(COUNT(*),0), 1) AS fail_pct
  FROM public.endoscope_reprocessing_cycles_r2911 c
  GROUP BY c.scope_serial
  ORDER BY failed_cycles DESC, fail_pct DESC NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_top_risk_scopes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_top_risk_scopes() TO authenticated;

-- =========================================================================
-- RPC 5: incident severity matrix
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_incident_severity_matrix()
RETURNS TABLE (
  severity text,
  incident_count bigint,
  patients_exposed bigint,
  total_fines_rupees bigint,
  avg_resolution_days numeric,
  regulatory_reports bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    i.severity,
    COUNT(*)::bigint,
    COALESCE(SUM(i.patients_exposed_count),0)::bigint,
    COALESCE(SUM(i.fine_imposed_rupees),0)::bigint,
    ROUND(AVG(i.resolution_days)::numeric, 1),
    COUNT(*) FILTER (WHERE i.regulatory_reported)::bigint
  FROM public.endoscope_compliance_incidents_r2911 i
  GROUP BY i.severity
  ORDER BY i.severity;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_incident_severity_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_incident_severity_matrix() TO authenticated;

-- =========================================================================
-- RPC 6: chemical efficacy audit
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_chemical_efficacy_audit()
RETURNS TABLE (
  chemical_used text,
  cycles_run bigint,
  avg_concentration_ppm numeric,
  avg_temperature_c numeric,
  pass_rate_pct numeric,
  avg_cost_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.chemical_used,
    COUNT(*)::bigint,
    ROUND(AVG(c.chemical_concentration_ppm)::numeric, 0),
    ROUND(AVG(c.temperature_celsius)::numeric, 1),
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.passed_protocol) / NULLIF(COUNT(*),0), 1),
    ROUND(AVG(c.cost_per_cycle_rupees)::numeric, 0)
  FROM public.endoscope_reprocessing_cycles_r2911 c
  GROUP BY c.chemical_used
  ORDER BY pass_rate_pct ASC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_chemical_efficacy_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_chemical_efficacy_audit() TO authenticated;

-- =========================================================================
-- RPC 7: open incidents log
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_open_incidents_log()
RETURNS TABLE (
  id uuid,
  hospital_chain_name text,
  hospital_branch_city text,
  quarter_label text,
  incident_opened_at timestamptz,
  incident_category text,
  severity text,
  scope_serial text,
  patients_exposed_count int,
  root_cause text,
  fine_imposed_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.hospital_chain_name, i.hospital_branch_city, i.quarter_label,
         i.incident_opened_at, i.incident_category, i.severity, i.scope_serial,
         i.patients_exposed_count, i.root_cause, i.fine_imposed_rupees
  FROM public.endoscope_compliance_incidents_r2911 i
  ORDER BY
    CASE i.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    i.incident_opened_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_open_incidents_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_open_incidents_log() TO authenticated;

-- =========================================================================
-- RPC 8: branch-level heatmap
-- =========================================================================
CREATE OR REPLACE FUNCTION public.r2911_branch_heatmap()
RETURNS TABLE (
  hospital_chain_name text,
  hospital_branch_city text,
  cycles bigint,
  failures bigint,
  incidents bigint,
  patients_exposed bigint,
  total_fines_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    b.hospital_chain_name,
    b.hospital_branch_city,
    (SELECT COUNT(*) FROM public.endoscope_reprocessing_cycles_r2911 c WHERE c.hospital_chain_name = b.hospital_chain_name AND c.hospital_branch_city = b.hospital_branch_city)::bigint,
    (SELECT COUNT(*) FROM public.endoscope_reprocessing_cycles_r2911 c WHERE c.hospital_chain_name = b.hospital_chain_name AND c.hospital_branch_city = b.hospital_branch_city AND NOT c.passed_protocol)::bigint,
    (SELECT COUNT(*) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.hospital_chain_name = b.hospital_chain_name AND i.hospital_branch_city = b.hospital_branch_city)::bigint,
    COALESCE((SELECT SUM(i.patients_exposed_count) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.hospital_chain_name = b.hospital_chain_name AND i.hospital_branch_city = b.hospital_branch_city),0)::bigint,
    COALESCE((SELECT SUM(i.fine_imposed_rupees) FROM public.endoscope_compliance_incidents_r2911 i WHERE i.hospital_chain_name = b.hospital_chain_name AND i.hospital_branch_city = b.hospital_branch_city),0)::bigint
  FROM (SELECT DISTINCT hospital_chain_name, hospital_branch_city FROM public.endoscope_reprocessing_cycles_r2911) b
  ORDER BY b.hospital_chain_name, b.hospital_branch_city;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2911_branch_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2911_branch_heatmap() TO authenticated;

COMMIT;
