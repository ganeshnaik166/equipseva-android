BEGIN;

-- =====================================================================
-- Round r2878 — Engineer Monthly Customer Handover Quiet-Hours Discipline
-- Tracks engineer behaviour during customer handover windows (post-job
-- repair sign-off + AMC monthly check-in). Quiet-hour breaches are
-- correlated to NPS dip + patient ward disturbance complaints.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLE 1: engineer monthly quiet-hours scorecard
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_handover_quiet_hours_scorecard_r2878 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  region text NOT NULL,
  handovers_total int NOT NULL CHECK (handovers_total >= 0),
  handovers_in_quiet_window int NOT NULL CHECK (handovers_in_quiet_window >= 0),
  quiet_breach_count int NOT NULL CHECK (quiet_breach_count >= 0),
  avg_call_decibel numeric(5,2) NOT NULL CHECK (avg_call_decibel >= 0),
  loud_call_minutes int NOT NULL CHECK (loud_call_minutes >= 0),
  post_22_call_count int NOT NULL CHECK (post_22_call_count >= 0),
  pre_07_call_count int NOT NULL CHECK (pre_07_call_count >= 0),
  ward_disturbance_complaints int NOT NULL CHECK (ward_disturbance_complaints >= 0),
  nps_delta numeric(5,2) NOT NULL,
  discipline_score numeric(5,2) NOT NULL CHECK (discipline_score >= 0 AND discipline_score <= 100),
  verdict text NOT NULL CHECK (verdict IN ('exemplary','acceptable','watchlist','coaching_required','suspension_review')),
  coaching_assigned boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_quiet_hours_scorecard_r2878 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_quiet_hours_scorecard_r2878;
CREATE POLICY founder_all ON engineer_handover_quiet_hours_scorecard_r2878
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handover_quiet_hours_scorecard_r2878
  (cycle_month, engineer_code, engineer_name, region, handovers_total, handovers_in_quiet_window,
   quiet_breach_count, avg_call_decibel, loud_call_minutes, post_22_call_count, pre_07_call_count,
   ward_disturbance_complaints, nps_delta, discipline_score, verdict, coaching_assigned, notes)
VALUES
  ('2026-06-01'::date,'ENG-HYD-014','Ravi Tej','Hyderabad',42,18,0,58.20,0,0,0,0,4.80,96.50,'exemplary',false,'gold standard handover etiquette'),
  ('2026-06-01'::date,'ENG-BLR-027','Anita Reddy','Bengaluru',38,15,2,64.10,12,1,0,1,1.20,82.30,'acceptable',false,'one late call to ICU coordinator, justified'),
  ('2026-06-01'::date,'ENG-DEL-009','Vikram Singh','Delhi NCR',51,22,7,71.80,46,5,2,4,-3.40,58.70,'watchlist',true,'repeated post-22 calls to nursing stations'),
  ('2026-06-01'::date,'ENG-CHN-031','Suresh Kumar','Chennai',29,11,11,78.40,92,9,6,7,-8.10,32.20,'coaching_required',true,'systemic disregard for ward quiet hours'),
  ('2026-06-01'::date,'ENG-MUM-018','Priya Iyer','Mumbai',46,20,14,82.60,118,11,8,9,-12.30,18.40,'suspension_review',true,'10 patient complaints; ICU manager escalation'),
  ('2026-06-01'::date,'ENG-PUN-022','Deepak Joshi','Pune',33,14,1,60.50,8,1,0,0,2.10,89.70,'exemplary',false,'consistent low-volume sign-offs'),
  ('2026-06-01'::date,'ENG-KOL-013','Arnab Sen','Kolkata',27,12,3,66.30,22,2,1,2,-1.80,74.60,'acceptable',false,'minor breach during emergency vent repair');

-- ---------------------------------------------------------------------
-- TABLE 2: individual quiet-hour breach incidents
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_quiet_hours_breach_incidents_r2878 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_at timestamptz NOT NULL,
  engineer_code text NOT NULL,
  hospital_code text NOT NULL,
  ward text NOT NULL,
  device_id text NOT NULL,
  handover_type text NOT NULL CHECK (handover_type IN ('repair_signoff','amc_monthly','installation','training','escalation')),
  breach_type text NOT NULL CHECK (breach_type IN ('loud_phone_call','equipment_test_beep','cart_noise','door_slam','voice_raised','tool_clatter')),
  decibel_peak numeric(5,2) NOT NULL CHECK (decibel_peak >= 0),
  duration_seconds int NOT NULL CHECK (duration_seconds >= 0),
  patient_present boolean NOT NULL,
  patient_count_in_range int NOT NULL CHECK (patient_count_in_range >= 0),
  complaint_filed boolean NOT NULL,
  complaint_severity text NOT NULL CHECK (complaint_severity IN ('none','low','medium','high','critical')),
  customer_verdict text NOT NULL CHECK (customer_verdict IN ('forgiven','warning_issued','formal_complaint','demand_replacement','contract_review')),
  founder_action text NOT NULL CHECK (founder_action IN ('logged','coaching_scheduled','written_warning','payout_penalty','suspension_72h','termination_review')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_quiet_hours_breach_incidents_r2878 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_quiet_hours_breach_incidents_r2878;
CREATE POLICY founder_all ON engineer_quiet_hours_breach_incidents_r2878
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_quiet_hours_breach_incidents_r2878
  (incident_at, engineer_code, hospital_code, ward, device_id, handover_type, breach_type,
   decibel_peak, duration_seconds, patient_present, patient_count_in_range, complaint_filed,
   complaint_severity, customer_verdict, founder_action, notes)
VALUES
  ('2026-06-03 22:47:00+05:30','ENG-MUM-018','HOSP-MUM-007','ICU-3','VENT-PB840-014','repair_signoff','loud_phone_call',86.40,420,true,6,true,'high','formal_complaint','suspension_72h','shouting at vendor on post-repair call inside ICU'),
  ('2026-06-05 06:12:00+05:30','ENG-CHN-031','HOSP-CHN-002','NICU','INCU-GE-009','amc_monthly','equipment_test_beep',79.20,180,true,4,true,'critical','demand_replacement','termination_review','ran 3 min self-test beep during NICU rest window'),
  ('2026-06-08 23:30:00+05:30','ENG-DEL-009','HOSP-DEL-011','Cardiac-2','DEFIB-PHI-022','escalation','voice_raised',74.80,95,true,3,true,'medium','warning_issued','coaching_scheduled','argued with night nurse over device serial'),
  ('2026-06-12 21:55:00+05:30','ENG-BLR-027','HOSP-BLR-005','Onco-ward-1','PUMP-BBR-031','amc_monthly','cart_noise',68.30,40,true,2,false,'low','forgiven','logged','rolling tool cart on tile floor, minor'),
  ('2026-06-14 22:18:00+05:30','ENG-MUM-018','HOSP-MUM-007','ICU-3','MON-MIN-018','repair_signoff','loud_phone_call',84.10,310,true,5,true,'high','contract_review','suspension_72h','second breach same hospital same month'),
  ('2026-06-17 05:48:00+05:30','ENG-CHN-031','HOSP-CHN-014','Peds-1','NEB-PHI-008','installation','door_slam',81.70,5,true,8,true,'medium','formal_complaint','written_warning','slammed equipment closet door pre-dawn'),
  ('2026-06-19 22:33:00+05:30','ENG-KOL-013','HOSP-KOL-003','OT-2','ANES-DRA-011','escalation','tool_clatter',72.50,25,false,0,false,'none','forgiven','logged','OT empty, after-hours emergency justified');

-- =====================================================================
-- RPCS
-- =====================================================================

-- RPC 1: overall KPIs
DROP FUNCTION IF EXISTS r2878_kpis();
CREATE OR REPLACE FUNCTION r2878_kpis()
RETURNS TABLE(
  engineers_scored int,
  total_handovers int,
  total_breaches int,
  patient_complaints int,
  suspension_review_count int,
  coaching_required_count int,
  avg_discipline_score numeric,
  avg_nps_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(handovers_total),0)::int,
    COALESCE(SUM(quiet_breach_count),0)::int,
    COALESCE(SUM(ward_disturbance_complaints),0)::int,
    COUNT(*) FILTER (WHERE verdict='suspension_review')::int,
    COUNT(*) FILTER (WHERE verdict='coaching_required')::int,
    ROUND(AVG(discipline_score),2),
    ROUND(AVG(nps_delta),2)
  FROM engineer_handover_quiet_hours_scorecard_r2878;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_kpis() TO authenticated;

-- RPC 2: scorecard listing
DROP FUNCTION IF EXISTS r2878_scorecard();
CREATE OR REPLACE FUNCTION r2878_scorecard()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  region text,
  handovers_total int,
  quiet_breach_count int,
  ward_disturbance_complaints int,
  nps_delta numeric,
  discipline_score numeric,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.region, s.handovers_total,
         s.quiet_breach_count, s.ward_disturbance_complaints, s.nps_delta,
         s.discipline_score, s.verdict
  FROM engineer_handover_quiet_hours_scorecard_r2878 s
  ORDER BY s.discipline_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_scorecard() TO authenticated;

-- RPC 3: recent incidents
DROP FUNCTION IF EXISTS r2878_incidents();
CREATE OR REPLACE FUNCTION r2878_incidents()
RETURNS TABLE(
  incident_at timestamptz,
  engineer_code text,
  hospital_code text,
  ward text,
  handover_type text,
  breach_type text,
  decibel_peak numeric,
  patient_count_in_range int,
  complaint_severity text,
  customer_verdict text,
  founder_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.incident_at, i.engineer_code, i.hospital_code, i.ward, i.handover_type,
         i.breach_type, i.decibel_peak, i.patient_count_in_range,
         i.complaint_severity, i.customer_verdict, i.founder_action
  FROM engineer_quiet_hours_breach_incidents_r2878 i
  ORDER BY i.incident_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_incidents() TO authenticated;

-- RPC 4: verdict mix
DROP FUNCTION IF EXISTS r2878_verdict_mix();
CREATE OR REPLACE FUNCTION r2878_verdict_mix()
RETURNS TABLE(verdict text, engineer_count int, pct_of_total numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_handover_quiet_hours_scorecard_r2878;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT s.verdict, COUNT(*)::int,
         ROUND(COUNT(*)::numeric * 100 / total, 2)
  FROM engineer_handover_quiet_hours_scorecard_r2878 s
  GROUP BY s.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_verdict_mix() TO authenticated;

-- RPC 5: breach-type heatmap
DROP FUNCTION IF EXISTS r2878_breach_heatmap();
CREATE OR REPLACE FUNCTION r2878_breach_heatmap()
RETURNS TABLE(
  breach_type text,
  incidents int,
  avg_decibel numeric,
  patients_affected int,
  complaints_filed int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.breach_type, COUNT(*)::int,
         ROUND(AVG(i.decibel_peak),2),
         COALESCE(SUM(i.patient_count_in_range),0)::int,
         COUNT(*) FILTER (WHERE i.complaint_filed)::int
  FROM engineer_quiet_hours_breach_incidents_r2878 i
  GROUP BY i.breach_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_breach_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_breach_heatmap() TO authenticated;

-- RPC 6: patient impact
DROP FUNCTION IF EXISTS r2878_patient_impact();
CREATE OR REPLACE FUNCTION r2878_patient_impact()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  patient_complaints int,
  total_patients_disturbed int,
  worst_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH sev AS (
    SELECT i.engineer_code,
           SUM(i.patient_count_in_range)::int AS patients,
           COUNT(*) FILTER (WHERE i.complaint_filed)::int AS complaints,
           MAX(CASE i.complaint_severity
                 WHEN 'critical' THEN 5
                 WHEN 'high' THEN 4
                 WHEN 'medium' THEN 3
                 WHEN 'low' THEN 2
                 WHEN 'none' THEN 1 END) AS sev_rank
    FROM engineer_quiet_hours_breach_incidents_r2878 i
    GROUP BY i.engineer_code
  )
  SELECT s.engineer_code, sc.engineer_name, sev.complaints, sev.patients,
         CASE sev.sev_rank WHEN 5 THEN 'critical' WHEN 4 THEN 'high'
              WHEN 3 THEN 'medium' WHEN 2 THEN 'low' ELSE 'none' END
  FROM sev
  JOIN engineer_handover_quiet_hours_scorecard_r2878 sc ON sc.engineer_code = sev.engineer_code
  JOIN sev s ON s.engineer_code = sev.engineer_code
  ORDER BY sev.complaints DESC, sev.patients DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_patient_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_patient_impact() TO authenticated;

-- RPC 7: founder action ledger
DROP FUNCTION IF EXISTS r2878_action_ledger();
CREATE OR REPLACE FUNCTION r2878_action_ledger()
RETURNS TABLE(founder_action text, incidents int, engineers_touched int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.founder_action, COUNT(*)::int, COUNT(DISTINCT i.engineer_code)::int
  FROM engineer_quiet_hours_breach_incidents_r2878 i
  GROUP BY i.founder_action
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_action_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_action_ledger() TO authenticated;

-- RPC 8: discipline leaderboard top exemplary
DROP FUNCTION IF EXISTS r2878_top_exemplary();
CREATE OR REPLACE FUNCTION r2878_top_exemplary()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  region text,
  discipline_score numeric,
  nps_delta numeric,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.region, s.discipline_score, s.nps_delta, s.verdict
  FROM engineer_handover_quiet_hours_scorecard_r2878 s
  WHERE s.discipline_score >= 80
  ORDER BY s.discipline_score DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2878_top_exemplary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2878_top_exemplary() TO authenticated;

COMMIT;
