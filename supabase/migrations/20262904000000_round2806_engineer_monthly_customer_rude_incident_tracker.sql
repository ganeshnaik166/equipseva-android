BEGIN;

-- ============================================================================
-- Round 2806: Engineer Monthly Customer Rude Incident Tracker
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: rude_incidents_r2806
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rude_incidents_r2806 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_code text NOT NULL UNIQUE,
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  customer_name text NOT NULL,
  hospital_name text NOT NULL,
  incident_month text NOT NULL,
  incident_date date NOT NULL,
  severity text NOT NULL CHECK (severity IN ('minor','moderate','severe','critical')),
  category text NOT NULL CHECK (category IN ('tone','language','behavior','dispute','no_show','argument')),
  witness_present boolean NOT NULL DEFAULT false,
  witness_name text,
  apology_status text NOT NULL CHECK (apology_status IN ('pending','offered','accepted','rejected','not_required')),
  apology_method text CHECK (apology_method IN ('in_person','phone','email','letter','video_call')),
  resolution_status text NOT NULL CHECK (resolution_status IN ('open','investigating','resolved','escalated','closed')),
  customer_satisfaction_score int CHECK (customer_satisfaction_score BETWEEN 0 AND 10),
  repeat_risk_level text NOT NULL CHECK (repeat_risk_level IN ('low','medium','high','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE rude_incidents_r2806 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON rude_incidents_r2806;
CREATE POLICY founder_all ON rude_incidents_r2806 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO rude_incidents_r2806 (incident_code, engineer_name, engineer_code, customer_name, hospital_name, incident_month, incident_date, severity, category, witness_present, witness_name, apology_status, apology_method, resolution_status, customer_satisfaction_score, repeat_risk_level, notes) VALUES
  ('INC-2806-001','Ravi Kumar','ENG-101','Dr. Sharma','Apollo Hyderabad','2026-06','2026-06-03'::date,'moderate','tone',true,'Nurse Priya','accepted','in_person','resolved',7,'low','Engineer raised voice during AC unit dispute'),
  ('INC-2806-002','Suresh Patel','ENG-102','Dr. Iyer','Yashoda Secunderabad','2026-06','2026-06-08'::date,'severe','argument',true,'Hospital Admin','offered','phone','investigating',4,'high','Heated argument over warranty terms'),
  ('INC-2806-003','Anil Verma','ENG-103','Dr. Reddy','KIMS Kondapur','2026-06','2026-06-12'::date,'minor','language',false,NULL,'accepted','in_person','closed',8,'low','Mild slang used during stressful repair'),
  ('INC-2806-004','Mohan Das','ENG-104','Dr. Khan','Continental Hospitals','2026-06','2026-06-15'::date,'critical','behavior',true,'Security Guard','rejected','letter','escalated',2,'critical','Walked out mid-service after disagreement'),
  ('INC-2806-005','Kiran Joshi','ENG-105','Dr. Nair','Care Banjara Hills','2026-06','2026-06-18'::date,'moderate','no_show',false,NULL,'offered','email','resolved',6,'medium','Did not call ahead about delay'),
  ('INC-2806-006','Ravi Kumar','ENG-101','Dr. Mehta','Apollo Jubilee Hills','2026-06','2026-06-21'::date,'moderate','dispute',true,'Senior Tech','pending',NULL,'open',5,'medium','Repeat incident — billing dispute');

-- ----------------------------------------------------------------------------
-- Table 2: rude_engineer_summary_r2806
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rude_engineer_summary_r2806 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL UNIQUE,
  engineer_name text NOT NULL,
  total_incidents int NOT NULL DEFAULT 0,
  severe_or_critical_count int NOT NULL DEFAULT 0,
  apologies_offered int NOT NULL DEFAULT 0,
  apologies_accepted int NOT NULL DEFAULT 0,
  open_incidents int NOT NULL DEFAULT 0,
  avg_csat numeric(4,2) DEFAULT 0,
  repeat_risk_score int NOT NULL DEFAULT 0 CHECK (repeat_risk_score BETWEEN 0 AND 100),
  coaching_status text NOT NULL CHECK (coaching_status IN ('not_started','scheduled','in_progress','completed','none_required')),
  last_coaching_date date,
  recommended_action text NOT NULL CHECK (recommended_action IN ('monitor','coach','suspend','terminate','reward')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE rude_engineer_summary_r2806 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON rude_engineer_summary_r2806;
CREATE POLICY founder_all ON rude_engineer_summary_r2806 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO rude_engineer_summary_r2806 (engineer_code, engineer_name, total_incidents, severe_or_critical_count, apologies_offered, apologies_accepted, open_incidents, avg_csat, repeat_risk_score, coaching_status, last_coaching_date, recommended_action) VALUES
  ('ENG-101','Ravi Kumar',2,0,1,1,1,6.00,55,'scheduled','2026-05-20'::date,'coach'),
  ('ENG-102','Suresh Patel',1,1,1,0,0,4.00,78,'in_progress','2026-06-09'::date,'coach'),
  ('ENG-103','Anil Verma',1,0,1,1,0,8.00,15,'none_required',NULL,'monitor'),
  ('ENG-104','Mohan Das',1,1,1,0,0,2.00,92,'not_started',NULL,'suspend'),
  ('ENG-105','Kiran Joshi',1,0,1,0,0,6.00,40,'scheduled','2026-06-16'::date,'coach'),
  ('ENG-106','Deepak Yadav',0,0,0,0,0,9.50,5,'none_required',NULL,'reward');

-- ----------------------------------------------------------------------------
-- RPC 1: kpi_summary
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2806_kpi_summary()
RETURNS TABLE(
  total_incidents bigint,
  critical_count bigint,
  open_count bigint,
  avg_csat numeric,
  high_risk_engineers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM rude_incidents_r2806),
    (SELECT COUNT(*) FROM rude_incidents_r2806 WHERE severity IN ('severe','critical')),
    (SELECT COUNT(*) FROM rude_incidents_r2806 WHERE resolution_status IN ('open','investigating')),
    (SELECT COALESCE(AVG(customer_satisfaction_score),0)::numeric(4,2) FROM rude_incidents_r2806),
    (SELECT COUNT(*) FROM rude_engineer_summary_r2806 WHERE repeat_risk_score >= 70);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_kpi_summary() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 2: list_incidents
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_list_incidents();
CREATE OR REPLACE FUNCTION founder_r2806_list_incidents()
RETURNS TABLE(
  incident_code text,
  engineer_name text,
  customer_name text,
  hospital_name text,
  incident_date date,
  severity text,
  category text,
  apology_status text,
  resolution_status text,
  repeat_risk_level text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.incident_code, r.engineer_name, r.customer_name, r.hospital_name,
         r.incident_date, r.severity, r.category, r.apology_status,
         r.resolution_status, r.repeat_risk_level
  FROM rude_incidents_r2806 r
  ORDER BY r.incident_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_list_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_list_incidents() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 3: engineer_summary
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_engineer_summary();
CREATE OR REPLACE FUNCTION founder_r2806_engineer_summary()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  total_incidents int,
  severe_or_critical_count int,
  open_incidents int,
  avg_csat numeric,
  repeat_risk_score int,
  coaching_status text,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.total_incidents,
         s.severe_or_critical_count, s.open_incidents, s.avg_csat,
         s.repeat_risk_score, s.coaching_status, s.recommended_action
  FROM rude_engineer_summary_r2806 s
  ORDER BY s.repeat_risk_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_engineer_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_engineer_summary() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 4: severity_breakdown
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_severity_breakdown();
CREATE OR REPLACE FUNCTION founder_r2806_severity_breakdown()
RETURNS TABLE(
  severity text,
  incident_count bigint,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.severity, COUNT(*)::bigint,
         COALESCE(AVG(r.customer_satisfaction_score),0)::numeric(4,2)
  FROM rude_incidents_r2806 r
  GROUP BY r.severity
  ORDER BY r.severity;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_severity_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_severity_breakdown() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 5: category_breakdown
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_category_breakdown();
CREATE OR REPLACE FUNCTION founder_r2806_category_breakdown()
RETURNS TABLE(
  category text,
  incident_count bigint,
  witness_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.category, COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE r.witness_present)::bigint
  FROM rude_incidents_r2806 r
  GROUP BY r.category
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_category_breakdown() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 6: apology_status_distribution
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_apology_distribution();
CREATE OR REPLACE FUNCTION founder_r2806_apology_distribution()
RETURNS TABLE(
  apology_status text,
  incident_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.apology_status, COUNT(*)::bigint
  FROM rude_incidents_r2806 r
  GROUP BY r.apology_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_apology_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_apology_distribution() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 7: high_risk_engineers
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_high_risk_engineers();
CREATE OR REPLACE FUNCTION founder_r2806_high_risk_engineers()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  repeat_risk_score int,
  recommended_action text,
  coaching_status text,
  last_coaching_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.repeat_risk_score,
         s.recommended_action, s.coaching_status, s.last_coaching_date
  FROM rude_engineer_summary_r2806 s
  WHERE s.repeat_risk_score >= 50
  ORDER BY s.repeat_risk_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_high_risk_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_high_risk_engineers() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 8: monthly_trend
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2806_monthly_trend();
CREATE OR REPLACE FUNCTION founder_r2806_monthly_trend()
RETURNS TABLE(
  incident_month text,
  incident_count bigint,
  severe_count bigint,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.incident_month, COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE r.severity IN ('severe','critical'))::bigint,
         COALESCE(AVG(r.customer_satisfaction_score),0)::numeric(4,2)
  FROM rude_incidents_r2806 r
  GROUP BY r.incident_month
  ORDER BY r.incident_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2806_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2806_monthly_trend() TO authenticated;

COMMIT;
