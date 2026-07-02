BEGIN;

-- =====================================================================
-- Round 2748 — Customer Monthly Equipment Cleaning Protocol Compliance
-- =====================================================================

CREATE TABLE IF NOT EXISTS equipment_cleaning_protocols_r2748 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  equipment_code text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('ventilator','dialysis','endoscope','ot_table','mri','ct','xray','ultrasound','infusion_pump','autoclave')),
  protocol_code text NOT NULL,
  protocol_version text NOT NULL,
  required_frequency text NOT NULL CHECK (required_frequency IN ('daily','weekly','monthly','quarterly')),
  steps_required int NOT NULL CHECK (steps_required > 0),
  audit_window_month date NOT NULL,
  cycles_required int NOT NULL CHECK (cycles_required > 0),
  cycles_completed int NOT NULL DEFAULT 0 CHECK (cycles_completed >= 0),
  cycles_partial int NOT NULL DEFAULT 0 CHECK (cycles_partial >= 0),
  cycles_missed int NOT NULL DEFAULT 0 CHECK (cycles_missed >= 0),
  adherence_pct numeric(5,2) NOT NULL DEFAULT 0,
  audit_score numeric(5,2) NOT NULL DEFAULT 0,
  risk_tier text NOT NULL CHECK (risk_tier IN ('low','medium','high','critical')),
  compliance_state text NOT NULL CHECK (compliance_state IN ('green','amber','red','breach')),
  last_audited_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_cleaning_protocols_r2748 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON equipment_cleaning_protocols_r2748;
CREATE POLICY founder_all ON equipment_cleaning_protocols_r2748
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS cleaning_protocol_gap_actions_r2748 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  protocol_id uuid NOT NULL REFERENCES equipment_cleaning_protocols_r2748(id) ON DELETE CASCADE,
  gap_type text NOT NULL CHECK (gap_type IN ('missed_cycle','partial_cycle','step_skipped','wrong_chemical','no_signoff','expired_chemical','documentation_gap')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  identified_on date NOT NULL,
  root_cause text NOT NULL,
  close_action text NOT NULL,
  owner_role text NOT NULL CHECK (owner_role IN ('biomed','housekeeping','infection_control','customer_admin','equipseva_engineer')),
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','closed','escalated','overdue')),
  hours_to_close numeric(7,2),
  reopened_count int NOT NULL DEFAULT 0,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cleaning_protocol_gap_actions_r2748 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cleaning_protocol_gap_actions_r2748;
CREATE POLICY founder_all ON cleaning_protocol_gap_actions_r2748
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================ Seeds ===================================
INSERT INTO equipment_cleaning_protocols_r2748
  (customer_org_name, equipment_code, equipment_category, protocol_code, protocol_version, required_frequency, steps_required, audit_window_month, cycles_required, cycles_completed, cycles_partial, cycles_missed, adherence_pct, audit_score, risk_tier, compliance_state, notes)
VALUES
  ('Apollo Jubilee Hills','VENT-A14','ventilator','VENT-CLEAN-01','v3.2','daily','12','2026-06-01'::date,30,28,2,0,93.33,91.50,'high','green','Strong adherence; minor signoff lag on Sundays'),
  ('Yashoda Secunderabad','DIAL-Y07','dialysis','DIAL-DECON-04','v2.1','weekly','9','2026-06-01'::date,4,3,1,0,75.00,72.00,'critical','amber','One partial cycle — chlorine concentration short'),
  ('KIMS Kondapur','ENDO-K22','endoscope','ENDO-REPROC-02','v4.0','daily','15','2026-06-01'::date,30,22,4,4,73.33,68.00,'critical','red','Repeated step-skip on enzymatic soak'),
  ('Continental Gachibowli','OT-C03','ot_table','OT-TERM-CLEAN','v1.8','daily','8','2026-06-01'::date,30,30,0,0,100.00,98.00,'high','green','Reference site — daily signoff complete'),
  ('Care Banjara','AUTO-CB02','autoclave','AUTO-VALID-03','v2.5','weekly','7','2026-06-01'::date,4,2,1,1,62.50,60.00,'high','red','Bowie-Dick test missed week 3'),
  ('Sunshine Paradise','MRI-S01','mri','MRI-COIL-CLEAN','v1.4','monthly','5','2026-06-01'::date,1,1,0,0,100.00,95.00,'medium','green','Compliant'),
  ('Rainbow Hyderguda','INFP-R11','infusion_pump','INFP-WIPE-01','v1.2','daily','4','2026-06-01'::date,30,18,6,6,70.00,65.00,'medium','amber','Night shift gap pattern');

INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'missed_cycle','critical','2026-06-12'::date,'Housekeeping roster gap on weekend','Add weekend backup roster; biomed signoff','housekeeping','2026-06-25'::date,'in_progress',NULL,0,NULL
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='ENDO-K22' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'wrong_chemical','high','2026-06-10'::date,'Wrong enzymatic detergent SKU received','Verify SKU at GRN; supplier swap','biomed','2026-06-18'::date,'closed',96.50,0,'2026-06-14 10:00+00'
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='DIAL-Y07' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'no_signoff','medium','2026-06-09'::date,'Night shift signoff form missing','Digital QR signoff rollout','customer_admin','2026-06-22'::date,'open',NULL,0,NULL
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='INFP-R11' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'documentation_gap','low','2026-06-05'::date,'Logbook page torn','Reissue logbook + train staff','infection_control','2026-06-15'::date,'closed',48.00,1,'2026-06-08 09:00+00'
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='VENT-A14' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'expired_chemical','critical','2026-06-11'::date,'Sterilant past expiry','Quarantine + supplier RMA','biomed','2026-06-13'::date,'escalated',NULL,2,NULL
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='AUTO-CB02' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'step_skipped','high','2026-06-08'::date,'Enzymatic soak duration short','SOP retrain; timer enforcement','equipseva_engineer','2026-06-20'::date,'overdue',NULL,1,NULL
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='ENDO-K22' LIMIT 1;
INSERT INTO cleaning_protocol_gap_actions_r2748
  (protocol_id, gap_type, severity, identified_on, root_cause, close_action, owner_role, due_date, status, hours_to_close, reopened_count, closed_at)
SELECT id,'partial_cycle','medium','2026-06-07'::date,'Patient overlap delayed cycle','Block 30-min buffer between cases','customer_admin','2026-06-19'::date,'closed',120.00,0,'2026-06-12 14:00+00'
FROM equipment_cleaning_protocols_r2748 WHERE equipment_code='INFP-R11' LIMIT 1;

-- ============================ RPCs ====================================
DROP FUNCTION IF EXISTS founder_r2748_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2748_kpi_summary()
RETURNS TABLE(metric text, value numeric, label text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'protocols_tracked'::text, COUNT(*)::numeric, 'Protocols tracked'::text FROM equipment_cleaning_protocols_r2748
    UNION ALL SELECT 'avg_adherence_pct', ROUND(AVG(adherence_pct)::numeric,2), 'Average adherence %' FROM equipment_cleaning_protocols_r2748
    UNION ALL SELECT 'avg_audit_score', ROUND(AVG(audit_score)::numeric,2), 'Average audit score' FROM equipment_cleaning_protocols_r2748
    UNION ALL SELECT 'red_protocols', COUNT(*)::numeric, 'Protocols in red state' FROM equipment_cleaning_protocols_r2748 WHERE compliance_state IN ('red','breach')
    UNION ALL SELECT 'open_gaps', COUNT(*)::numeric, 'Open gap actions' FROM cleaning_protocol_gap_actions_r2748 WHERE status IN ('open','in_progress','escalated','overdue')
    UNION ALL SELECT 'overdue_gaps', COUNT(*)::numeric, 'Overdue gaps' FROM cleaning_protocol_gap_actions_r2748 WHERE status='overdue';
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_protocols_list();
CREATE OR REPLACE FUNCTION founder_r2748_protocols_list()
RETURNS TABLE(id uuid, customer_org_name text, equipment_code text, equipment_category text, protocol_code text, required_frequency text, adherence_pct numeric, audit_score numeric, risk_tier text, compliance_state text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id,p.customer_org_name,p.equipment_code,p.equipment_category,p.protocol_code,p.required_frequency,p.adherence_pct,p.audit_score,p.risk_tier,p.compliance_state
    FROM equipment_cleaning_protocols_r2748 p
    ORDER BY (CASE p.compliance_state WHEN 'breach' THEN 0 WHEN 'red' THEN 1 WHEN 'amber' THEN 2 ELSE 3 END), p.adherence_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_protocols_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_protocols_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_category_breakdown();
CREATE OR REPLACE FUNCTION founder_r2748_category_breakdown()
RETURNS TABLE(equipment_category text, protocols int, avg_adherence numeric, avg_audit numeric, red_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.equipment_category,
           COUNT(*)::int,
           ROUND(AVG(p.adherence_pct)::numeric,2),
           ROUND(AVG(p.audit_score)::numeric,2),
           SUM(CASE WHEN p.compliance_state IN ('red','breach') THEN 1 ELSE 0 END)::int
    FROM equipment_cleaning_protocols_r2748 p
    GROUP BY p.equipment_category
    ORDER BY 3 ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_category_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_gap_list();
CREATE OR REPLACE FUNCTION founder_r2748_gap_list()
RETURNS TABLE(id uuid, equipment_code text, customer_org_name text, gap_type text, severity text, owner_role text, due_date date, status text, reopened_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.id, p.equipment_code, p.customer_org_name, g.gap_type, g.severity, g.owner_role, g.due_date, g.status, g.reopened_count
    FROM cleaning_protocol_gap_actions_r2748 g
    JOIN equipment_cleaning_protocols_r2748 p ON p.id = g.protocol_id
    ORDER BY (CASE g.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END), g.due_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_gap_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_gap_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_owner_load();
CREATE OR REPLACE FUNCTION founder_r2748_owner_load()
RETURNS TABLE(owner_role text, open_count int, overdue_count int, avg_hours_to_close numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.owner_role,
           SUM(CASE WHEN g.status IN ('open','in_progress','escalated') THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN g.status='overdue' THEN 1 ELSE 0 END)::int,
           ROUND(AVG(g.hours_to_close)::numeric,2)
    FROM cleaning_protocol_gap_actions_r2748 g
    GROUP BY g.owner_role
    ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_owner_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_owner_load() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_customer_scorecard();
CREATE OR REPLACE FUNCTION founder_r2748_customer_scorecard()
RETURNS TABLE(customer_org_name text, protocols int, avg_adherence numeric, open_gaps int, critical_gaps int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.customer_org_name,
           COUNT(DISTINCT p.id)::int,
           ROUND(AVG(p.adherence_pct)::numeric,2),
           SUM(CASE WHEN g.status IN ('open','in_progress','escalated','overdue') THEN 1 ELSE 0 END)::int,
           SUM(CASE WHEN g.severity='critical' AND g.status<>'closed' THEN 1 ELSE 0 END)::int
    FROM equipment_cleaning_protocols_r2748 p
    LEFT JOIN cleaning_protocol_gap_actions_r2748 g ON g.protocol_id = p.id
    GROUP BY p.customer_org_name
    ORDER BY 3 ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_customer_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_customer_scorecard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_red_protocols();
CREATE OR REPLACE FUNCTION founder_r2748_red_protocols()
RETURNS TABLE(customer_org_name text, equipment_code text, adherence_pct numeric, audit_score numeric, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.customer_org_name,p.equipment_code,p.adherence_pct,p.audit_score,p.notes
    FROM equipment_cleaning_protocols_r2748 p
    WHERE p.compliance_state IN ('red','breach') OR p.risk_tier IN ('critical')
    ORDER BY p.adherence_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_red_protocols() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_red_protocols() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2748_close_action(uuid);
CREATE OR REPLACE FUNCTION founder_r2748_close_action(p_gap_id uuid)
RETURNS TABLE(closed_id uuid, new_status text)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE cleaning_protocol_gap_actions_r2748
  SET status='closed', closed_at=now(), hours_to_close=COALESCE(hours_to_close, EXTRACT(EPOCH FROM (now() - created_at))/3600.0)
  WHERE id = p_gap_id
  RETURNING id INTO v_id;
  RETURN QUERY SELECT v_id, 'closed'::text;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2748_close_action(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2748_close_action(uuid) TO authenticated;

COMMIT;
