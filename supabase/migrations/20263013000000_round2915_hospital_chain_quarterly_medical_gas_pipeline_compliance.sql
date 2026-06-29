-- Round 2915: Hospital Chain Quarterly Medical-Gas Pipeline System Compliance
-- HEAVY founder ops round

BEGIN;

-- =====================================================================
-- TABLE 1: gas_pipeline_audits_r2915
-- Quarterly audit records for medical-gas pipeline systems across chains
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.gas_pipeline_audits_r2915 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  city text NOT NULL,
  quarter text NOT NULL,
  audit_date date NOT NULL,
  gas_type text NOT NULL CHECK (gas_type IN ('oxygen','nitrous_oxide','medical_air','vacuum','co2','nitrogen')),
  pipeline_length_meters numeric(10,2) NOT NULL,
  outlets_inspected int NOT NULL,
  outlets_failed int NOT NULL DEFAULT 0,
  pressure_kpa numeric(8,2) NOT NULL,
  leak_rate_ppm numeric(8,2) NOT NULL DEFAULT 0,
  purity_percent numeric(5,2) NOT NULL,
  compliance_status text NOT NULL CHECK (compliance_status IN ('compliant','minor_gap','major_gap','critical')),
  nabh_certified boolean NOT NULL DEFAULT false,
  hcfi_compliant boolean NOT NULL DEFAULT false,
  remediation_cost_rupees bigint NOT NULL DEFAULT 0,
  auditor_name text NOT NULL,
  next_audit_due date NOT NULL
);

ALTER TABLE public.gas_pipeline_audits_r2915 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- TABLE 2: gas_pipeline_incidents_r2915
-- Incidents, near-misses, and remediation tracking
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.gas_pipeline_incidents_r2915 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_id uuid REFERENCES public.gas_pipeline_audits_r2915(id) ON DELETE SET NULL,
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  incident_date date NOT NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  incident_type text NOT NULL CHECK (incident_type IN ('leak','pressure_drop','contamination','outlet_failure','alarm_failure','cross_contamination','reserve_low')),
  gas_type text NOT NULL,
  affected_wards text NOT NULL,
  patients_at_risk int NOT NULL DEFAULT 0,
  downtime_minutes int NOT NULL DEFAULT 0,
  root_cause text NOT NULL,
  remediation_status text NOT NULL CHECK (remediation_status IN ('open','in_progress','resolved','escalated')),
  cost_rupees bigint NOT NULL DEFAULT 0,
  closed_at timestamptz
);

ALTER TABLE public.gas_pipeline_incidents_r2915 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- SEED DATA: 18 audits
-- =====================================================================
INSERT INTO public.gas_pipeline_audits_r2915 (chain_name, hospital_site, city, quarter, audit_date, gas_type, pipeline_length_meters, outlets_inspected, outlets_failed, pressure_kpa, leak_rate_ppm, purity_percent, compliance_status, nabh_certified, hcfi_compliant, remediation_cost_rupees, auditor_name, next_audit_due) VALUES
('Apollo Hospitals','Apollo Jubilee Hills','Hyderabad','Q1-2026','2026-01-12'::date,'oxygen',1840.50,420,3,412.5,8.2,99.50,'compliant',true,true,45000,'Dr. R. Iyer','2026-04-12'::date),
('Apollo Hospitals','Apollo Secunderabad','Hyderabad','Q1-2026','2026-01-18'::date,'medical_air',1240.00,310,7,408.0,12.4,99.20,'minor_gap',true,true,180000,'Dr. R. Iyer','2026-04-18'::date),
('Apollo Hospitals','Apollo Chennai Greams','Chennai','Q1-2026','2026-02-02'::date,'nitrous_oxide',680.75,180,1,348.0,4.8,99.80,'compliant',true,true,22000,'Dr. M. Krishnan','2026-05-02'::date),
('Fortis Healthcare','Fortis Bannerghatta','Bangalore','Q1-2026','2026-01-22'::date,'oxygen',2150.00,520,14,398.5,18.6,98.60,'major_gap',true,false,820000,'Eng. P. Bhat','2026-04-22'::date),
('Fortis Healthcare','Fortis Mulund','Mumbai','Q1-2026','2026-02-08'::date,'vacuum',1620.50,380,2,-78.0,0.0,0.00,'compliant',true,true,55000,'Eng. P. Bhat','2026-05-08'::date),
('Manipal Hospitals','Manipal Whitefield','Bangalore','Q1-2026','2026-01-15'::date,'oxygen',1480.00,360,5,415.0,9.8,99.40,'minor_gap',true,true,240000,'Dr. S. Rao','2026-04-15'::date),
('Manipal Hospitals','Manipal Old Airport Rd','Bangalore','Q1-2026','2026-02-12'::date,'medical_air',1320.25,290,1,406.0,5.6,99.65,'compliant',true,true,38000,'Dr. S. Rao','2026-05-12'::date),
('Max Healthcare','Max Saket','Delhi','Q1-2026','2026-01-26'::date,'oxygen',2840.00,640,22,389.0,24.8,97.80,'critical',false,false,2150000,'Dr. A. Verma','2026-03-26'::date),
('Max Healthcare','Max Patparganj','Delhi','Q1-2026','2026-02-04'::date,'nitrous_oxide',780.00,210,0,352.0,3.2,99.90,'compliant',true,true,18000,'Dr. A. Verma','2026-05-04'::date),
('Narayana Health','NH Bommasandra','Bangalore','Q1-2026','2026-01-29'::date,'oxygen',3120.50,780,11,402.5,14.2,99.10,'minor_gap',true,true,420000,'Eng. V. Reddy','2026-04-29'::date),
('Narayana Health','NH Howrah','Kolkata','Q1-2026','2026-02-10'::date,'co2',420.00,95,3,608.0,6.4,99.95,'minor_gap',true,true,72000,'Eng. V. Reddy','2026-05-10'::date),
('Medanta','Medanta Gurugram','Gurugram','Q1-2026','2026-01-20'::date,'oxygen',2380.00,580,8,410.0,11.6,99.30,'minor_gap',true,true,310000,'Dr. K. Sharma','2026-04-20'::date),
('AIIMS Network','AIIMS Rishikesh','Rishikesh','Q1-2026','2026-02-14'::date,'oxygen',1980.00,460,18,378.5,22.4,98.20,'major_gap',true,false,940000,'Dr. P. Gupta','2026-03-14'::date),
('KIMS Hospitals','KIMS Begumpet','Hyderabad','Q1-2026','2026-01-16'::date,'medical_air',1180.50,280,2,409.5,7.8,99.50,'compliant',true,true,48000,'Dr. N. Reddy','2026-04-16'::date),
('Yashoda Hospitals','Yashoda Somajiguda','Hyderabad','Q1-2026','2026-02-06'::date,'oxygen',1620.00,400,6,405.0,13.4,99.20,'minor_gap',true,true,265000,'Dr. T. Naidu','2026-05-06'::date),
('Rainbow Children','Rainbow Banjara Hills','Hyderabad','Q1-2026','2026-01-24'::date,'oxygen',880.00,220,0,418.0,2.8,99.95,'compliant',true,true,12000,'Dr. L. Menon','2026-04-24'::date),
('Columbia Asia','Columbia Whitefield','Bangalore','Q1-2026','2026-02-11'::date,'nitrogen',340.00,72,1,820.0,9.6,99.70,'compliant',true,true,28000,'Eng. B. Joshi','2026-05-11'::date),
('Aster DM','Aster Medcity','Kochi','Q1-2026','2026-02-15'::date,'oxygen',2240.50,540,9,408.0,15.8,99.05,'minor_gap',true,true,380000,'Dr. F. Thomas','2026-05-15'::date);

-- =====================================================================
-- SEED DATA: 20 incidents
-- =====================================================================
INSERT INTO public.gas_pipeline_incidents_r2915 (chain_name, hospital_site, incident_date, severity, incident_type, gas_type, affected_wards, patients_at_risk, downtime_minutes, root_cause, remediation_status, cost_rupees, closed_at) VALUES
('Max Healthcare','Max Saket','2026-01-08'::date,'p0','leak','oxygen','ICU-3, ICU-4, NICU',42,180,'Corroded copper joint at riser-4; chloride contamination','escalated',1850000,NULL),
('Fortis Healthcare','Fortis Bannerghatta','2026-01-14'::date,'p1','pressure_drop','oxygen','OT-1 through OT-6',18,95,'Manifold regulator failure; reserve auto-switch delayed','resolved',620000,'2026-01-22 14:30:00+05:30'::timestamptz),
('AIIMS Network','AIIMS Rishikesh','2026-01-22'::date,'p1','contamination','medical_air','Burn unit, Trauma ICU',12,240,'Compressor moisture trap saturated; particulates above HCFI','in_progress',780000,NULL),
('Apollo Hospitals','Apollo Secunderabad','2026-02-01'::date,'p2','outlet_failure','oxygen','Ward-7B',4,45,'Quick-connect coupling worn beyond service interval','resolved',45000,'2026-02-03 11:00:00+05:30'::timestamptz),
('Manipal Hospitals','Manipal Whitefield','2026-01-19'::date,'p2','alarm_failure','vacuum','OT-block A',0,0,'Area alarm panel battery dead; not on UPS','resolved',32000,'2026-01-20 09:15:00+05:30'::timestamptz),
('Narayana Health','NH Bommasandra','2026-01-31'::date,'p1','cross_contamination','oxygen','Pediatric ICU',8,120,'Cross-piping between medical-air and oxygen during retrofit','resolved',420000,'2026-02-14 18:00:00+05:30'::timestamptz),
('Medanta','Medanta Gurugram','2026-01-25'::date,'p2','reserve_low','nitrous_oxide','OT-2, OT-3',0,30,'Vendor delivery delayed 36 hours past PAR','resolved',18000,'2026-01-25 22:00:00+05:30'::timestamptz),
('Max Healthcare','Max Saket','2026-01-12'::date,'p1','leak','medical_air','General ward Block-C',0,60,'Brazed joint failure; thermal cycling','resolved',95000,'2026-01-14 10:00:00+05:30'::timestamptz),
('Fortis Healthcare','Fortis Mulund','2026-02-06'::date,'p3','alarm_failure','oxygen','Master alarm panel',0,0,'False low-pressure alarm; calibration drift','resolved',8500,'2026-02-07 09:00:00+05:30'::timestamptz),
('Apollo Hospitals','Apollo Jubilee Hills','2026-01-15'::date,'p3','pressure_drop','medical_air','Day-care surgery',2,15,'Filter clogged; preventive interval missed','resolved',12000,'2026-01-15 16:00:00+05:30'::timestamptz),
('Yashoda Hospitals','Yashoda Somajiguda','2026-02-09'::date,'p2','leak','oxygen','Cardiology ward',6,75,'Cracked solenoid valve at zone-3','in_progress',180000,NULL),
('Aster DM','Aster Medcity','2026-02-16'::date,'p1','contamination','oxygen','NICU',15,90,'Cryogenic tank dewar valve gasket contamination','open',540000,NULL),
('AIIMS Network','AIIMS Rishikesh','2026-02-03'::date,'p0','pressure_drop','oxygen','ICU-1, ICU-2',38,210,'Primary manifold + reserve both depleted; alarm masked','escalated',2400000,NULL),
('Manipal Hospitals','Manipal Old Airport Rd','2026-02-13'::date,'p3','outlet_failure','vacuum','Endoscopy suite',0,20,'Outlet sealing ring perished','resolved',6500,'2026-02-13 14:00:00+05:30'::timestamptz),
('KIMS Hospitals','KIMS Begumpet','2026-01-17'::date,'p2','reserve_low','oxygen','OT block',0,0,'Tank gauge transmitter fault; reserve actually full','resolved',42000,'2026-01-18 12:00:00+05:30'::timestamptz),
('Columbia Asia','Columbia Whitefield','2026-02-12'::date,'p3','alarm_failure','nitrogen','Lab block',0,0,'Sensor cable damaged during civil work','resolved',15000,'2026-02-13 17:00:00+05:30'::timestamptz),
('Narayana Health','NH Howrah','2026-02-11'::date,'p2','leak','co2',' Endoscopy, OT-4',3,55,'Regulator outlet O-ring failure','resolved',38000,'2026-02-13 13:00:00+05:30'::timestamptz),
('Rainbow Children','Rainbow Banjara Hills','2026-01-25'::date,'p3','pressure_drop','medical_air','Pediatric ward',1,10,'Brief delivery interruption from vendor','resolved',4500,'2026-01-25 18:30:00+05:30'::timestamptz),
('Apollo Hospitals','Apollo Chennai Greams','2026-02-04'::date,'p2','outlet_failure','nitrous_oxide','OT-7',2,40,'DISS outlet thread wear','resolved',28000,'2026-02-05 11:30:00+05:30'::timestamptz),
('Medanta','Medanta Gurugram','2026-01-28'::date,'p1','cross_contamination','medical_air','Cath lab',5,140,'Air-vacuum cross-connect at zone valve','in_progress',680000,NULL);

-- =====================================================================
-- RPC 1: Quarterly compliance KPIs
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_compliance_kpis()
RETURNS TABLE (
  total_audits bigint,
  chains_covered bigint,
  sites_covered bigint,
  critical_count bigint,
  major_gap_count bigint,
  compliant_pct numeric,
  total_remediation_rupees bigint
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
    COUNT(*)::bigint,
    COUNT(DISTINCT chain_name)::bigint,
    COUNT(DISTINCT hospital_site)::bigint,
    COUNT(*) FILTER (WHERE compliance_status = 'critical')::bigint,
    COUNT(*) FILTER (WHERE compliance_status = 'major_gap')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE compliance_status = 'compliant') / NULLIF(COUNT(*),0), 2),
    COALESCE(SUM(remediation_cost_rupees),0)::bigint
  FROM public.gas_pipeline_audits_r2915;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_compliance_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_compliance_kpis() TO authenticated;

-- =====================================================================
-- RPC 2: Critical and major gap audits
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_critical_audits()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_site text,
  city text,
  gas_type text,
  compliance_status text,
  outlets_failed int,
  leak_rate_ppm numeric,
  remediation_cost_rupees bigint,
  audit_date date
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
  SELECT a.id, a.chain_name, a.hospital_site, a.city, a.gas_type,
         a.compliance_status, a.outlets_failed, a.leak_rate_ppm,
         a.remediation_cost_rupees, a.audit_date
  FROM public.gas_pipeline_audits_r2915 a
  WHERE a.compliance_status IN ('critical','major_gap')
  ORDER BY
    CASE a.compliance_status WHEN 'critical' THEN 1 WHEN 'major_gap' THEN 2 ELSE 3 END,
    a.remediation_cost_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_critical_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_critical_audits() TO authenticated;

-- =====================================================================
-- RPC 3: Chain-level rollup
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_chain_rollup()
RETURNS TABLE (
  chain_name text,
  sites_audited bigint,
  total_outlets bigint,
  failed_outlets bigint,
  avg_leak_rate_ppm numeric,
  avg_purity_percent numeric,
  total_remediation_rupees bigint,
  nabh_pct numeric
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
    a.chain_name,
    COUNT(DISTINCT a.hospital_site)::bigint,
    SUM(a.outlets_inspected)::bigint,
    SUM(a.outlets_failed)::bigint,
    ROUND(AVG(a.leak_rate_ppm),2),
    ROUND(AVG(a.purity_percent),2),
    SUM(a.remediation_cost_rupees)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.nabh_certified) / NULLIF(COUNT(*),0), 2)
  FROM public.gas_pipeline_audits_r2915 a
  GROUP BY a.chain_name
  ORDER BY SUM(a.remediation_cost_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_chain_rollup() TO authenticated;

-- =====================================================================
-- RPC 4: Gas-type risk profile
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_gas_type_risk()
RETURNS TABLE (
  gas_type text,
  audits_count bigint,
  avg_outlets_failed numeric,
  avg_leak_ppm numeric,
  incidents_count bigint,
  p0_p1_incidents bigint,
  total_patients_at_risk bigint
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
    a.gas_type,
    COUNT(DISTINCT a.id)::bigint,
    ROUND(AVG(a.outlets_failed),2),
    ROUND(AVG(a.leak_rate_ppm),2),
    COALESCE((SELECT COUNT(*) FROM public.gas_pipeline_incidents_r2915 i WHERE i.gas_type = a.gas_type),0)::bigint,
    COALESCE((SELECT COUNT(*) FROM public.gas_pipeline_incidents_r2915 i WHERE i.gas_type = a.gas_type AND i.severity IN ('p0','p1')),0)::bigint,
    COALESCE((SELECT SUM(i.patients_at_risk) FROM public.gas_pipeline_incidents_r2915 i WHERE i.gas_type = a.gas_type),0)::bigint
  FROM public.gas_pipeline_audits_r2915 a
  GROUP BY a.gas_type
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_gas_type_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_gas_type_risk() TO authenticated;

-- =====================================================================
-- RPC 5: Open and escalated incidents
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_open_incidents()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_site text,
  severity text,
  incident_type text,
  gas_type text,
  affected_wards text,
  patients_at_risk int,
  downtime_minutes int,
  cost_rupees bigint,
  incident_date date,
  remediation_status text
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
  SELECT i.id, i.chain_name, i.hospital_site, i.severity, i.incident_type,
         i.gas_type, i.affected_wards, i.patients_at_risk, i.downtime_minutes,
         i.cost_rupees, i.incident_date, i.remediation_status
  FROM public.gas_pipeline_incidents_r2915 i
  WHERE i.remediation_status IN ('open','in_progress','escalated')
  ORDER BY
    CASE i.severity WHEN 'p0' THEN 1 WHEN 'p1' THEN 2 WHEN 'p2' THEN 3 ELSE 4 END,
    i.patients_at_risk DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_open_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_open_incidents() TO authenticated;

-- =====================================================================
-- RPC 6: City-level exposure
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_city_exposure()
RETURNS TABLE (
  city text,
  sites_count bigint,
  audits_count bigint,
  critical_sites bigint,
  total_failed_outlets bigint,
  remediation_rupees bigint
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
    a.city,
    COUNT(DISTINCT a.hospital_site)::bigint,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE a.compliance_status = 'critical')::bigint,
    SUM(a.outlets_failed)::bigint,
    SUM(a.remediation_cost_rupees)::bigint
  FROM public.gas_pipeline_audits_r2915 a
  GROUP BY a.city
  ORDER BY SUM(a.remediation_cost_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_city_exposure() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_city_exposure() TO authenticated;

-- =====================================================================
-- RPC 7: Upcoming audits (next 60 days)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_upcoming_audits()
RETURNS TABLE (
  chain_name text,
  hospital_site text,
  city text,
  gas_type text,
  next_audit_due date,
  days_until int,
  last_status text
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
    a.chain_name,
    a.hospital_site,
    a.city,
    a.gas_type,
    a.next_audit_due,
    (a.next_audit_due - CURRENT_DATE)::int,
    a.compliance_status
  FROM public.gas_pipeline_audits_r2915 a
  WHERE a.next_audit_due <= (CURRENT_DATE + INTERVAL '90 days')::date
  ORDER BY a.next_audit_due ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_upcoming_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_upcoming_audits() TO authenticated;

-- =====================================================================
-- RPC 8: Incident severity summary
-- =====================================================================
CREATE OR REPLACE FUNCTION public.r2915_incident_severity_summary()
RETURNS TABLE (
  severity text,
  incidents_count bigint,
  open_count bigint,
  total_downtime_minutes bigint,
  total_patients_at_risk bigint,
  total_cost_rupees bigint
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
    COUNT(*) FILTER (WHERE i.remediation_status IN ('open','in_progress','escalated'))::bigint,
    SUM(i.downtime_minutes)::bigint,
    SUM(i.patients_at_risk)::bigint,
    SUM(i.cost_rupees)::bigint
  FROM public.gas_pipeline_incidents_r2915 i
  GROUP BY i.severity
  ORDER BY CASE i.severity WHEN 'p0' THEN 1 WHEN 'p1' THEN 2 WHEN 'p2' THEN 3 ELSE 4 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2915_incident_severity_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2915_incident_severity_summary() TO authenticated;

COMMIT;
