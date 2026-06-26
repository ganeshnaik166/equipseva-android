BEGIN;

-- ============================================================
-- Round 2883: Hospital Chain Quarterly Equipment Fleet
-- Pre-Festival Readiness — chain × asset × festival weekend
-- × prep × on-call × outcome × verdict
-- ============================================================

CREATE TABLE IF NOT EXISTS festival_fleet_readiness_assessments_r2883 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','dialysis','ventilator','ot_critical','lab_analyzer','endoscopy','monitor_fleet')),
  asset_serial text NOT NULL,
  festival_name text NOT NULL CHECK (festival_name IN ('diwali','dussehra','christmas','sankranti','holi','ganesh_chaturthi','eid','onam')),
  festival_weekend_start date NOT NULL,
  prep_status text NOT NULL CHECK (prep_status IN ('not_started','in_progress','calibrated','spares_stocked','engineer_assigned','fully_ready','blocked')),
  on_call_engineer text NOT NULL,
  on_call_response_sla_minutes int NOT NULL CHECK (on_call_response_sla_minutes BETWEEN 15 AND 240),
  outcome text NOT NULL CHECK (outcome IN ('flawless','minor_glitch','major_incident','near_miss','equipment_failure','pending')),
  downtime_minutes int NOT NULL DEFAULT 0 CHECK (downtime_minutes >= 0),
  verdict text NOT NULL CHECK (verdict IN ('approved','needs_review','escalate_chain','renew_amc_premium','add_redundancy','rotate_engineer','exemplary')),
  risk_score numeric(5,2) NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE festival_fleet_readiness_assessments_r2883 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON festival_fleet_readiness_assessments_r2883;
CREATE POLICY founder_all ON festival_fleet_readiness_assessments_r2883
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO festival_fleet_readiness_assessments_r2883
  (chain_name, hospital_site, asset_category, asset_serial, festival_name, festival_weekend_start, prep_status, on_call_engineer, on_call_response_sla_minutes, outcome, downtime_minutes, verdict, risk_score, notes)
VALUES
  ('Apollo Group','Apollo Jubilee Hills','imaging','SIE-CT-90-44721','diwali','2026-11-07'::date,'fully_ready','Ravi Kumar',30,'flawless',0,'exemplary',8.50,'CT-90 ready; spare tube on-site; 2 backup engineers'),
  ('Yashoda Hospitals','Yashoda Somajiguda','dialysis','FRE-4008S-12388','diwali','2026-11-07'::date,'spares_stocked','Priya Sharma',45,'minor_glitch',22,'approved',18.00,'15 dialysis bays; one membrane leak patched in 22min'),
  ('Manipal Hospitals','Manipal Vijayawada','ventilator','HAM-G5-77104','dussehra','2026-10-24'::date,'engineer_assigned','Suresh Reddy',60,'major_incident',180,'escalate_chain',72.50,'2 vents went down during peak ICU load; need redundancy plan'),
  ('Care Hospitals','Care Banjara Hills','ot_critical','MAQ-FLOW-i-9921','christmas','2026-12-26'::date,'fully_ready','Anjali Verma',20,'flawless',0,'exemplary',5.25,'Christmas weekend OT package; zero issues across 6 OTs'),
  ('KIMS Hospitals','KIMS Secunderabad','lab_analyzer','ROC-COBAS-8000-3349','sankranti','2027-01-16'::date,'in_progress','Vikram Singh',90,'pending',0,'needs_review',42.00,'Calibration kit delayed; pickup Tue; risk if not closed by Fri'),
  ('Aster DM','Aster Prime Ameerpet','endoscopy','OLY-CV-190-55812','holi','2027-03-13'::date,'calibrated','Neha Gupta',45,'near_miss',8,'add_redundancy',35.00,'Scope-2 froze briefly; spare scope deployed in 8min'),
  ('Continental','Continental Gachibowli','monitor_fleet','PHI-IM50-21134','ganesh_chaturthi','2026-09-12'::date,'blocked','Arjun Mehta',60,'equipment_failure',420,'rotate_engineer',88.00,'4 monitors failed; engineer was on leave; replacement took 7hr'),
  ('Apollo Group','Apollo Hyderguda','imaging','GE-MR-450W-11209','eid','2027-03-29'::date,'fully_ready','Ravi Kumar',30,'flawless',0,'approved',12.00,'MR coil pre-checked; helium top-up done'),
  ('Manipal Hospitals','Manipal Hi-Tec City','dialysis','FRE-5008S-44091','onam','2026-09-05'::date,'spares_stocked','Priya Sharma',45,'minor_glitch',35,'approved',22.00,'Onam weekend; one reverse-osmosis line clogged; flushed in 35min'),
  ('Yashoda Hospitals','Yashoda Malakpet','ot_critical','DRG-PRIMUS-IE-66721','diwali','2026-11-07'::date,'engineer_assigned','Suresh Reddy',60,'pending',0,'needs_review',48.50,'AMC renewal pending; vendor confirm by Tue');

CREATE TABLE IF NOT EXISTS festival_oncall_engineer_rotations_r2883 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  city text NOT NULL,
  festival_window text NOT NULL CHECK (festival_window IN ('diwali_2026','dussehra_2026','christmas_2026','sankranti_2027','holi_2027','ganesh_2026','eid_2027','onam_2026')),
  chains_covered text NOT NULL,
  total_sites int NOT NULL CHECK (total_sites BETWEEN 1 AND 50),
  shift_hours numeric(5,2) NOT NULL CHECK (shift_hours BETWEEN 0 AND 96),
  incidents_handled int NOT NULL DEFAULT 0 CHECK (incidents_handled >= 0),
  avg_response_minutes numeric(6,2) NOT NULL CHECK (avg_response_minutes BETWEEN 0 AND 480),
  fatigue_score numeric(4,2) NOT NULL CHECK (fatigue_score BETWEEN 0 AND 10),
  bonus_eligible boolean NOT NULL DEFAULT false,
  rotation_verdict text NOT NULL CHECK (rotation_verdict IN ('keep','bonus_award','swap_next','remove','promote','train_more','red_flag')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE festival_oncall_engineer_rotations_r2883 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON festival_oncall_engineer_rotations_r2883;
CREATE POLICY founder_all ON festival_oncall_engineer_rotations_r2883
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO festival_oncall_engineer_rotations_r2883
  (engineer_name, city, festival_window, chains_covered, total_sites, shift_hours, incidents_handled, avg_response_minutes, fatigue_score, bonus_eligible, rotation_verdict)
VALUES
  ('Ravi Kumar','Hyderabad','diwali_2026','Apollo Group, KIMS',8,72.00,4,28.50,7.20,true,'bonus_award'),
  ('Priya Sharma','Hyderabad','diwali_2026','Yashoda, Manipal',6,68.50,3,38.00,6.80,true,'keep'),
  ('Suresh Reddy','Vijayawada','dussehra_2026','Manipal, Care',5,48.00,7,72.00,8.90,false,'swap_next'),
  ('Anjali Verma','Hyderabad','christmas_2026','Care, Aster DM',7,60.00,1,22.00,5.00,true,'promote'),
  ('Vikram Singh','Secunderabad','sankranti_2027','KIMS, Continental',4,40.00,2,85.00,4.50,false,'train_more'),
  ('Neha Gupta','Hyderabad','holi_2027','Aster DM, Apollo',6,54.00,3,42.00,6.20,true,'keep'),
  ('Arjun Mehta','Hyderabad','ganesh_2026','Continental, KIMS',5,38.00,5,180.00,9.40,false,'red_flag'),
  ('Kiran Rao','Bangalore','onam_2026','Manipal Bangalore',4,44.00,2,46.00,5.80,true,'keep'),
  ('Deepa Iyer','Chennai','diwali_2026','Apollo Chennai',5,58.00,4,32.00,6.00,true,'bonus_award'),
  ('Manoj Patel','Mumbai','diwali_2026','Yashoda Mumbai',3,36.00,1,30.00,4.20,false,'train_more');

-- ============================================================
-- RPCs (7+) — all SECURITY DEFINER, plpgsql, is_founder gated
-- ============================================================

DROP FUNCTION IF EXISTS rpc_r2883_fleet_kpis();
CREATE OR REPLACE FUNCTION rpc_r2883_fleet_kpis()
RETURNS TABLE(
  total_assets int,
  fully_ready int,
  blocked_assets int,
  major_incidents int,
  avg_risk_score numeric,
  total_downtime_minutes int,
  exemplary_verdicts int,
  escalations int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE prep_status = 'fully_ready')::int,
    COUNT(*) FILTER (WHERE prep_status = 'blocked')::int,
    COUNT(*) FILTER (WHERE outcome = 'major_incident')::int,
    ROUND(AVG(risk_score), 2),
    COALESCE(SUM(downtime_minutes), 0)::int,
    COUNT(*) FILTER (WHERE verdict = 'exemplary')::int,
    COUNT(*) FILTER (WHERE verdict = 'escalate_chain')::int
  FROM festival_fleet_readiness_assessments_r2883;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_fleet_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_fleet_kpis() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_assessments_list();
CREATE OR REPLACE FUNCTION rpc_r2883_assessments_list()
RETURNS TABLE(
  id uuid,
  chain_name text,
  hospital_site text,
  asset_category text,
  asset_serial text,
  festival_name text,
  festival_weekend_start date,
  prep_status text,
  on_call_engineer text,
  outcome text,
  downtime_minutes int,
  verdict text,
  risk_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_site, a.asset_category, a.asset_serial,
         a.festival_name, a.festival_weekend_start, a.prep_status, a.on_call_engineer,
         a.outcome, a.downtime_minutes, a.verdict, a.risk_score
  FROM festival_fleet_readiness_assessments_r2883 a
  ORDER BY a.risk_score DESC, a.festival_weekend_start ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_assessments_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_assessments_list() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_chain_summary();
CREATE OR REPLACE FUNCTION rpc_r2883_chain_summary()
RETURNS TABLE(
  chain_name text,
  total_assets int,
  ready_assets int,
  high_risk_assets int,
  total_downtime int,
  avg_risk numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.chain_name,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE a.prep_status = 'fully_ready')::int,
    COUNT(*) FILTER (WHERE a.risk_score >= 50)::int,
    COALESCE(SUM(a.downtime_minutes), 0)::int,
    ROUND(AVG(a.risk_score), 2)
  FROM festival_fleet_readiness_assessments_r2883 a
  GROUP BY a.chain_name
  ORDER BY AVG(a.risk_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_chain_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_chain_summary() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_festival_breakdown();
CREATE OR REPLACE FUNCTION rpc_r2883_festival_breakdown()
RETURNS TABLE(
  festival_name text,
  asset_count int,
  ready_count int,
  incidents int,
  total_downtime int,
  next_weekend date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.festival_name,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE a.prep_status = 'fully_ready')::int,
    COUNT(*) FILTER (WHERE a.outcome IN ('major_incident','equipment_failure'))::int,
    COALESCE(SUM(a.downtime_minutes), 0)::int,
    MIN(a.festival_weekend_start)
  FROM festival_fleet_readiness_assessments_r2883 a
  GROUP BY a.festival_name
  ORDER BY MIN(a.festival_weekend_start) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_festival_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_festival_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_oncall_rotations();
CREATE OR REPLACE FUNCTION rpc_r2883_oncall_rotations()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  city text,
  festival_window text,
  chains_covered text,
  total_sites int,
  shift_hours numeric,
  incidents_handled int,
  avg_response_minutes numeric,
  fatigue_score numeric,
  bonus_eligible boolean,
  rotation_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_name, r.city, r.festival_window, r.chains_covered,
         r.total_sites, r.shift_hours, r.incidents_handled, r.avg_response_minutes,
         r.fatigue_score, r.bonus_eligible, r.rotation_verdict
  FROM festival_oncall_engineer_rotations_r2883 r
  ORDER BY r.fatigue_score DESC, r.incidents_handled DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_oncall_rotations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_oncall_rotations() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_high_risk_assets();
CREATE OR REPLACE FUNCTION rpc_r2883_high_risk_assets()
RETURNS TABLE(
  chain_name text,
  hospital_site text,
  asset_serial text,
  asset_category text,
  prep_status text,
  risk_score numeric,
  verdict text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name, a.hospital_site, a.asset_serial, a.asset_category,
         a.prep_status, a.risk_score, a.verdict, a.notes
  FROM festival_fleet_readiness_assessments_r2883 a
  WHERE a.risk_score >= 40 OR a.prep_status = 'blocked' OR a.outcome IN ('major_incident','equipment_failure')
  ORDER BY a.risk_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_high_risk_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_high_risk_assets() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_engineer_fatigue();
CREATE OR REPLACE FUNCTION rpc_r2883_engineer_fatigue()
RETURNS TABLE(
  engineer_name text,
  total_sites int,
  shift_hours numeric,
  fatigue_score numeric,
  incidents_handled int,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_name, r.total_sites, r.shift_hours, r.fatigue_score,
         r.incidents_handled, r.rotation_verdict
  FROM festival_oncall_engineer_rotations_r2883 r
  WHERE r.fatigue_score >= 6.0 OR r.rotation_verdict IN ('red_flag','swap_next','remove')
  ORDER BY r.fatigue_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_engineer_fatigue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_engineer_fatigue() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2883_verdict_distribution();
CREATE OR REPLACE FUNCTION rpc_r2883_verdict_distribution()
RETURNS TABLE(
  verdict text,
  count int,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total_count int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_count FROM festival_fleet_readiness_assessments_r2883;
  RETURN QUERY
  SELECT
    a.verdict,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric / NULLIF(total_count, 0)) * 100, 2)
  FROM festival_fleet_readiness_assessments_r2883 a
  GROUP BY a.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2883_verdict_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2883_verdict_distribution() TO authenticated;

COMMIT;