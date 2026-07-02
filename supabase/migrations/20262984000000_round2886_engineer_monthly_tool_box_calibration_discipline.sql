-- Round 2886: Engineer Monthly Tool-Box Maintenance & Calibration Discipline
-- Founder ops surface: track each engineer's monthly tool inspection + calibration cert renewal cadence.
-- Two tables (suffixed _r2886), 7 founder-gated RPCs.

BEGIN;

-- ============================================================
-- TABLE 1: engineer_tool_box_audits_r2886
-- One row per engineer per month: did they submit their tool-box audit?
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_tool_box_audits_r2886 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL,
  engineer_code text NOT NULL,
  audit_month date NOT NULL,
  cached_tier text NOT NULL,
  tools_required int NOT NULL DEFAULT 0,
  tools_present int NOT NULL DEFAULT 0,
  tools_damaged int NOT NULL DEFAULT 0,
  tools_missing int NOT NULL DEFAULT 0,
  photos_submitted int NOT NULL DEFAULT 0,
  photos_required int NOT NULL DEFAULT 6,
  submitted_at timestamptz,
  due_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('submitted_on_time','submitted_late','overdue','waived','partial')),
  discipline_score numeric(5,2) NOT NULL DEFAULT 0,
  replacement_cost_rupees int NOT NULL DEFAULT 0,
  founder_notes text
);
ALTER TABLE engineer_tool_box_audits_r2886 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: engineer_calibration_certs_r2886
-- Calibration certificate tracking per critical instrument per engineer.
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_calibration_certs_r2886 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL,
  engineer_code text NOT NULL,
  instrument_kind text NOT NULL CHECK (instrument_kind IN ('multimeter','torque_wrench','pressure_gauge','infrared_thermometer','tachometer','insulation_tester','oscilloscope','leakage_current_tester')),
  serial_no text NOT NULL,
  lab_name text NOT NULL,
  issued_on date NOT NULL,
  expires_on date NOT NULL,
  cert_number text NOT NULL,
  status text NOT NULL CHECK (status IN ('valid','expiring_soon','expired','suspended','renewal_in_flight')),
  days_to_expiry int NOT NULL DEFAULT 0,
  last_used_in_job uuid,
  renewal_cost_rupees int NOT NULL DEFAULT 0,
  blocker_for_super_specialty boolean NOT NULL DEFAULT false
);
ALTER TABLE engineer_calibration_certs_r2886 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED — 18 tool-box audits, 22 calibration certs
-- ============================================================
INSERT INTO engineer_tool_box_audits_r2886
  (engineer_user_id, engineer_code, audit_month, cached_tier, tools_required, tools_present, tools_damaged, tools_missing, photos_submitted, photos_required, submitted_at, due_at, status, discipline_score, replacement_cost_rupees, founder_notes)
VALUES
  (gen_random_uuid(),'ENG-HYD-001',date_trunc('month',now())::date,'platinum',42,42,0,0,8,6,now()-interval '2 days',now()+interval '5 days','submitted_on_time',98.5,0,'gold standard'),
  (gen_random_uuid(),'ENG-HYD-002',date_trunc('month',now())::date,'gold',38,36,1,1,6,6,now()-interval '4 days',now()+interval '3 days','submitted_on_time',88.2,4200,'minor replacements'),
  (gen_random_uuid(),'ENG-HYD-003',date_trunc('month',now())::date,'silver',32,30,2,0,5,6,now()-interval '1 day',now()+interval '1 day','partial',74.0,8400,'photos short — re-submit'),
  (gen_random_uuid(),'ENG-BLR-004',date_trunc('month',now())::date,'gold',38,34,2,2,6,6,now()+interval '2 days',now()-interval '1 day','submitted_late',65.0,12600,'second late month'),
  (gen_random_uuid(),'ENG-BLR-005',date_trunc('month',now())::date,'platinum',42,41,1,0,7,6,now()-interval '3 days',now()+interval '4 days','submitted_on_time',95.0,2100,'leak tester scratched'),
  (gen_random_uuid(),'ENG-CHN-006',date_trunc('month',now())::date,'silver',32,29,1,2,4,6,NULL,now()-interval '3 days','overdue',45.0,16800,'NO submission — escalate'),
  (gen_random_uuid(),'ENG-CHN-007',date_trunc('month',now())::date,'gold',38,38,0,0,6,6,now()-interval '5 days',now()+interval '2 days','submitted_on_time',100.0,0,'perfect score'),
  (gen_random_uuid(),'ENG-MUM-008',date_trunc('month',now())::date,'bronze',28,25,1,2,3,6,NULL,now()-interval '7 days','overdue',38.0,18200,'third overdue — at-risk'),
  (gen_random_uuid(),'ENG-MUM-009',date_trunc('month',now())::date,'platinum',42,40,2,0,8,6,now()-interval '2 days',now()+interval '5 days','submitted_on_time',92.5,4400,'torque wrench cracked'),
  (gen_random_uuid(),'ENG-DEL-010',date_trunc('month',now())::date,'gold',38,37,1,0,6,6,now()-interval '6 days',now()+interval '1 day','submitted_on_time',96.0,2200,'clean audit'),
  (gen_random_uuid(),'ENG-DEL-011',date_trunc('month',now())::date,'silver',32,28,2,2,5,6,now()+interval '1 day',now()-interval '2 days','submitted_late',58.0,14600,'late + missing items'),
  (gen_random_uuid(),'ENG-PUN-012',date_trunc('month',now())::date,'gold',38,36,2,0,6,6,now()-interval '3 days',now()+interval '3 days','submitted_on_time',89.5,4800,'IR thermometer drift'),
  (gen_random_uuid(),'ENG-KOL-013',date_trunc('month',now())::date,'silver',32,30,1,1,5,6,now()-interval '1 day',now()+interval '4 days','partial',71.0,8000,'photos partial'),
  (gen_random_uuid(),'ENG-AHM-014',date_trunc('month',now())::date,'bronze',28,28,0,0,6,6,now()-interval '4 days',now()+interval '2 days','submitted_on_time',97.0,0,'bronze rising star'),
  (gen_random_uuid(),'ENG-HYD-015',date_trunc('month',now())::date,'platinum',42,38,3,1,7,6,now()+interval '3 days',now()-interval '1 day','submitted_late',62.0,18400,'platinum slipping'),
  (gen_random_uuid(),'ENG-BLR-016',date_trunc('month',now())::date,'silver',32,31,0,1,5,6,now()-interval '2 days',now()+interval '3 days','submitted_on_time',86.0,5200,'one small wrench missing'),
  (gen_random_uuid(),'ENG-CHN-017',date_trunc('month',now())::date,'gold',38,35,2,1,6,6,now()-interval '5 days',now()+interval '1 day','submitted_on_time',82.0,9600,'two damages — coach'),
  (gen_random_uuid(),'ENG-MUM-018',date_trunc('month',now())::date,'platinum',42,42,0,0,9,6,now()-interval '6 days',now()+interval '4 days','submitted_on_time',99.5,0,'perfect platinum');

INSERT INTO engineer_calibration_certs_r2886
  (engineer_user_id, engineer_code, instrument_kind, serial_no, lab_name, issued_on, expires_on, cert_number, status, days_to_expiry, renewal_cost_rupees, blocker_for_super_specialty)
VALUES
  (gen_random_uuid(),'ENG-HYD-001','multimeter','FLK-87V-2188','NPL Bengaluru',(now()-interval '300 days')::date,(now()+interval '65 days')::date,'NPL-MM-9921','valid',65,1800,false),
  (gen_random_uuid(),'ENG-HYD-001','torque_wrench','TQ-50NM-114','SITARC Tirupati',(now()-interval '340 days')::date,(now()+interval '25 days')::date,'STC-TQ-7732','expiring_soon',25,2400,true),
  (gen_random_uuid(),'ENG-HYD-002','pressure_gauge','PG-2000kPa-78','NPL Bengaluru',(now()-interval '370 days')::date,(now()-interval '5 days')::date,'NPL-PG-6601','expired',-5,2200,true),
  (gen_random_uuid(),'ENG-HYD-003','infrared_thermometer','IR-650-21','SITARC Tirupati',(now()-interval '280 days')::date,(now()+interval '85 days')::date,'STC-IR-5519','valid',85,1600,false),
  (gen_random_uuid(),'ENG-BLR-004','insulation_tester','MIT-525-09','NABL-CAL-09',(now()-interval '395 days')::date,(now()-interval '30 days')::date,'NCL-IT-3320','expired',-30,3800,true),
  (gen_random_uuid(),'ENG-BLR-005','oscilloscope','DS-1054Z-44','NPL Bengaluru',(now()-interval '200 days')::date,(now()+interval '165 days')::date,'NPL-OS-8841','valid',165,5400,false),
  (gen_random_uuid(),'ENG-CHN-006','leakage_current_tester','LCT-200-12','SITARC Tirupati',(now()-interval '360 days')::date,(now()+interval '5 days')::date,'STC-LC-2207','expiring_soon',5,4200,true),
  (gen_random_uuid(),'ENG-CHN-007','multimeter','FLK-289-66','NPL Bengaluru',(now()-interval '120 days')::date,(now()+interval '245 days')::date,'NPL-MM-9988','valid',245,1800,false),
  (gen_random_uuid(),'ENG-MUM-008','tachometer','TCH-DT2236-31','NABL-CAL-09',(now()-interval '420 days')::date,(now()-interval '55 days')::date,'NCL-TC-1102','expired',-55,1400,false),
  (gen_random_uuid(),'ENG-MUM-009','torque_wrench','TQ-200NM-08','SITARC Tirupati',(now()-interval '90 days')::date,(now()+interval '275 days')::date,'STC-TQ-9981','valid',275,2400,true),
  (gen_random_uuid(),'ENG-DEL-010','pressure_gauge','PG-5000kPa-22','NPL Bengaluru',(now()-interval '180 days')::date,(now()+interval '185 days')::date,'NPL-PG-7724','valid',185,2200,true),
  (gen_random_uuid(),'ENG-DEL-011','insulation_tester','MIT-1025-19','SITARC Tirupati',(now()-interval '350 days')::date,(now()+interval '15 days')::date,'STC-IT-4419','expiring_soon',15,3800,true),
  (gen_random_uuid(),'ENG-PUN-012','infrared_thermometer','IR-MX2-77','NPL Bengaluru',(now()-interval '60 days')::date,(now()+interval '305 days')::date,'NPL-IR-2255','valid',305,1600,false),
  (gen_random_uuid(),'ENG-KOL-013','oscilloscope','DS-2072A-15','NABL-CAL-09',(now()-interval '380 days')::date,(now()-interval '15 days')::date,'NCL-OS-7708','expired',-15,5400,false),
  (gen_random_uuid(),'ENG-AHM-014','multimeter','FLK-117-90','SITARC Tirupati',(now()-interval '40 days')::date,(now()+interval '325 days')::date,'STC-MM-1144','valid',325,1800,false),
  (gen_random_uuid(),'ENG-HYD-015','leakage_current_tester','LCT-100-77','NPL Bengaluru',(now()-interval '330 days')::date,(now()+interval '35 days')::date,'NPL-LC-5566','expiring_soon',35,4200,true),
  (gen_random_uuid(),'ENG-BLR-016','tachometer','TCH-PCE-44','NABL-CAL-09',(now()-interval '150 days')::date,(now()+interval '215 days')::date,'NCL-TC-6633','valid',215,1400,false),
  (gen_random_uuid(),'ENG-CHN-017','torque_wrench','TQ-100NM-22','SITARC Tirupati',(now()-interval '20 days')::date,(now()+interval '345 days')::date,'STC-TQ-1199','renewal_in_flight',345,2400,true),
  (gen_random_uuid(),'ENG-MUM-018','pressure_gauge','PG-1000kPa-55','NPL Bengaluru',(now()-interval '110 days')::date,(now()+interval '255 days')::date,'NPL-PG-2244','valid',255,2200,true),
  (gen_random_uuid(),'ENG-HYD-001','infrared_thermometer','IR-FLK-62MAX-11','NPL Bengaluru',(now()-interval '250 days')::date,(now()+interval '115 days')::date,'NPL-IR-3399','valid',115,1600,false),
  (gen_random_uuid(),'ENG-BLR-005','multimeter','FLK-179-88','SITARC Tirupati',(now()-interval '160 days')::date,(now()+interval '205 days')::date,'STC-MM-7766','valid',205,1800,false),
  (gen_random_uuid(),'ENG-CHN-007','insulation_tester','MIT-2100-33','NPL Bengaluru',(now()-interval '70 days')::date,(now()+interval '295 days')::date,'NPL-IT-4488','valid',295,3800,true);

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_toolbox_kpi_summary()
RETURNS TABLE (
  total_engineers int,
  on_time_pct numeric,
  overdue_count int,
  avg_discipline_score numeric,
  total_replacement_cost_rupees bigint,
  certs_expired int,
  certs_expiring_30d int,
  super_specialty_blockers int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT engineer_user_id)::int FROM engineer_tool_box_audits_r2886),
    ROUND(100.0 * (SELECT count(*) FILTER (WHERE status='submitted_on_time') FROM engineer_tool_box_audits_r2886)
          / NULLIF((SELECT count(*) FROM engineer_tool_box_audits_r2886),0),1),
    (SELECT count(*)::int FROM engineer_tool_box_audits_r2886 WHERE status='overdue'),
    (SELECT ROUND(AVG(discipline_score),1) FROM engineer_tool_box_audits_r2886),
    (SELECT COALESCE(SUM(replacement_cost_rupees),0)::bigint FROM engineer_tool_box_audits_r2886),
    (SELECT count(*)::int FROM engineer_calibration_certs_r2886 WHERE status='expired'),
    (SELECT count(*)::int FROM engineer_calibration_certs_r2886 WHERE status='expiring_soon'),
    (SELECT count(*)::int FROM engineer_calibration_certs_r2886 WHERE status IN ('expired','expiring_soon') AND blocker_for_super_specialty=true);
END;$$;

-- ============================================================
-- RPC 2: discipline leaderboard
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_discipline_leaderboard()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  cached_tier text,
  discipline_score numeric,
  status text,
  tools_present int,
  tools_required int,
  replacement_cost_rupees int,
  founder_notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_code, t.cached_tier, t.discipline_score, t.status,
         t.tools_present, t.tools_required, t.replacement_cost_rupees, t.founder_notes
  FROM engineer_tool_box_audits_r2886 t
  ORDER BY t.discipline_score DESC;
END;$$;

-- ============================================================
-- RPC 3: overdue + at-risk engineers
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_overdue_engineers()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  cached_tier text,
  status text,
  due_at timestamptz,
  hours_overdue numeric,
  tools_missing int,
  replacement_cost_rupees int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_code, t.cached_tier, t.status, t.due_at,
         ROUND(EXTRACT(EPOCH FROM (now() - t.due_at))/3600.0, 1),
         t.tools_missing, t.replacement_cost_rupees
  FROM engineer_tool_box_audits_r2886 t
  WHERE t.status IN ('overdue','submitted_late','partial')
  ORDER BY t.due_at ASC;
END;$$;

-- ============================================================
-- RPC 4: calibration expiry watch
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_calibration_expiry_watch()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  instrument_kind text,
  serial_no text,
  lab_name text,
  expires_on date,
  days_to_expiry int,
  status text,
  blocker_for_super_specialty boolean,
  renewal_cost_rupees int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_code, c.instrument_kind, c.serial_no, c.lab_name,
         c.expires_on, c.days_to_expiry, c.status, c.blocker_for_super_specialty, c.renewal_cost_rupees
  FROM engineer_calibration_certs_r2886 c
  WHERE c.status IN ('expired','expiring_soon','renewal_in_flight')
  ORDER BY c.days_to_expiry ASC;
END;$$;

-- ============================================================
-- RPC 5: tier × discipline matrix
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_tier_discipline_matrix()
RETURNS TABLE (
  cached_tier text,
  engineer_count int,
  avg_discipline_score numeric,
  on_time_count int,
  overdue_count int,
  total_replacement_cost_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT t.cached_tier,
         count(*)::int,
         ROUND(AVG(t.discipline_score),1),
         count(*) FILTER (WHERE t.status='submitted_on_time')::int,
         count(*) FILTER (WHERE t.status='overdue')::int,
         COALESCE(SUM(t.replacement_cost_rupees),0)::bigint
  FROM engineer_tool_box_audits_r2886 t
  GROUP BY t.cached_tier
  ORDER BY AVG(t.discipline_score) DESC;
END;$$;

-- ============================================================
-- RPC 6: super-specialty blocker list
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_super_specialty_blockers()
RETURNS TABLE (
  id uuid,
  engineer_code text,
  instrument_kind text,
  status text,
  days_to_expiry int,
  expires_on date,
  renewal_cost_rupees int,
  lab_name text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_code, c.instrument_kind, c.status, c.days_to_expiry,
         c.expires_on, c.renewal_cost_rupees, c.lab_name
  FROM engineer_calibration_certs_r2886 c
  WHERE c.blocker_for_super_specialty = true
    AND c.status IN ('expired','expiring_soon')
  ORDER BY c.days_to_expiry ASC;
END;$$;

-- ============================================================
-- RPC 7: lab partner concentration
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2886_lab_partner_concentration()
RETURNS TABLE (
  lab_name text,
  cert_count int,
  expired_count int,
  expiring_soon_count int,
  total_renewal_spend_rupees bigint,
  avg_days_to_expiry numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'founder only'; END IF;
  RETURN QUERY
  SELECT c.lab_name,
         count(*)::int,
         count(*) FILTER (WHERE c.status='expired')::int,
         count(*) FILTER (WHERE c.status='expiring_soon')::int,
         COALESCE(SUM(c.renewal_cost_rupees),0)::bigint,
         ROUND(AVG(c.days_to_expiry),1)
  FROM engineer_calibration_certs_r2886 c
  GROUP BY c.lab_name
  ORDER BY count(*) DESC;
END;$$;

-- ============================================================
-- Permissions: REVOKE FROM PUBLIC/anon, GRANT to authenticated
-- ============================================================
REVOKE EXECUTE ON FUNCTION founder_r2886_toolbox_kpi_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_discipline_leaderboard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_overdue_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_calibration_expiry_watch() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_tier_discipline_matrix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_super_specialty_blockers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2886_lab_partner_concentration() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2886_toolbox_kpi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_discipline_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_overdue_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_calibration_expiry_watch() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_tier_discipline_matrix() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_super_specialty_blockers() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2886_lab_partner_concentration() TO authenticated;

COMMIT;
