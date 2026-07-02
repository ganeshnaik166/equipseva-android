BEGIN;

CREATE TABLE IF NOT EXISTS uniform_photo_captures_r2736 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL,
  customer_org text NOT NULL,
  engineer_name text NOT NULL,
  capture_at timestamptz NOT NULL DEFAULT now(),
  photo_url text NOT NULL,
  geo_lat numeric(10,6),
  geo_lng numeric(10,6),
  on_site boolean NOT NULL DEFAULT true,
  uniform_score integer NOT NULL CHECK (uniform_score BETWEEN 0 AND 100),
  compliance_status text NOT NULL CHECK (compliance_status IN ('compliant','minor_issue','major_issue','non_compliant')),
  verified boolean NOT NULL DEFAULT false,
  verified_by text,
  verified_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE uniform_photo_captures_r2736 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON uniform_photo_captures_r2736;
CREATE POLICY founder_all ON uniform_photo_captures_r2736 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS uniform_compliance_actions_r2736 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  capture_id uuid REFERENCES uniform_photo_captures_r2736(id) ON DELETE CASCADE,
  issue_type text NOT NULL CHECK (issue_type IN ('missing_uniform','dirty_uniform','no_id_badge','wrong_color','torn_uniform','no_safety_gear')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  action_taken text NOT NULL,
  action_owner text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','resolved','escalated')),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE uniform_compliance_actions_r2736 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON uniform_compliance_actions_r2736;
CREATE POLICY founder_all ON uniform_compliance_actions_r2736 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO uniform_photo_captures_r2736 (job_code, customer_org, engineer_name, capture_at, photo_url, geo_lat, geo_lng, on_site, uniform_score, compliance_status, verified, verified_by, verified_at, notes) VALUES
('JOB-77821','Apollo Hyderabad','Ramesh K','2026-06-24 09:14:00+05:30','https://cdn.equipseva.com/uniform/77821.jpg',17.435400,78.448700,true,96,'compliant',true,'qa.priya','2026-06-24 10:00:00+05:30','clean uniform, badge visible'),
('JOB-77822','KIMS Secunderabad','Suresh M','2026-06-24 10:02:00+05:30','https://cdn.equipseva.com/uniform/77822.jpg',17.443200,78.498100,true,72,'minor_issue',true,'qa.priya','2026-06-24 11:00:00+05:30','small stain on sleeve'),
('JOB-77823','Yashoda Hospitals','Vikram T','2026-06-24 11:30:00+05:30','https://cdn.equipseva.com/uniform/77823.jpg',17.408900,78.484500,true,45,'major_issue',false,NULL,NULL,'no ID badge on uniform'),
('JOB-77824','Care Banjara','Anil P','2026-06-23 14:15:00+05:30','https://cdn.equipseva.com/uniform/77824.jpg',17.413200,78.443100,true,20,'non_compliant',true,'qa.deepa','2026-06-23 15:30:00+05:30','engineer wearing personal clothes'),
('JOB-77825','Continental Gachibowli','Mahesh R','2026-06-24 12:45:00+05:30','https://cdn.equipseva.com/uniform/77825.jpg',17.453200,78.378200,true,88,'compliant',true,'qa.deepa','2026-06-24 13:30:00+05:30','full PPE on site'),
('JOB-77826','Rainbow Childrens','Naveen S','2026-06-24 08:30:00+05:30','https://cdn.equipseva.com/uniform/77826.jpg',17.426100,78.451200,false,0,'non_compliant',false,NULL,NULL,'photo taken off-site, geo mismatch'),
('JOB-77827','Sunshine Hospital','Kiran B','2026-06-22 16:20:00+05:30','https://cdn.equipseva.com/uniform/77827.jpg',17.443900,78.498500,true,80,'compliant',true,'qa.priya','2026-06-22 17:00:00+05:30','verified at site');

INSERT INTO uniform_compliance_actions_r2736 (capture_id, issue_type, severity, action_taken, action_owner, status, resolved_at) VALUES
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77822'), 'dirty_uniform', 'low', 'Reminder issued to engineer + uniform laundry slip', 'ops.manager', 'resolved', '2026-06-24 12:00:00+05:30'),
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77823'), 'no_id_badge', 'medium', 'New badge re-issued, training reminder sent', 'hr.team', 'in_progress', NULL),
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77824'), 'missing_uniform', 'high', 'Engineer pulled from rotation, formal warning', 'ops.head', 'escalated', NULL),
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77826'), 'missing_uniform', 'critical', 'Job re-assigned, engineer suspended pending review', 'founder', 'open', NULL),
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77827'), 'no_safety_gear', 'medium', 'Safety gear kit re-issued, toolbox talk scheduled', 'safety.lead', 'resolved', '2026-06-23 09:00:00+05:30'),
((SELECT id FROM uniform_photo_captures_r2736 WHERE job_code='JOB-77821'), 'wrong_color', 'low', 'Old uniform replaced with new branded set', 'ops.manager', 'resolved', '2026-06-24 14:00:00+05:30');

DROP FUNCTION IF EXISTS r2736_kpi_summary();
CREATE OR REPLACE FUNCTION r2736_kpi_summary()
RETURNS TABLE(total_captures bigint, compliant bigint, non_compliant bigint, verified bigint, open_actions bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM uniform_photo_captures_r2736),
    (SELECT COUNT(*) FROM uniform_photo_captures_r2736 WHERE compliance_status='compliant'),
    (SELECT COUNT(*) FROM uniform_photo_captures_r2736 WHERE compliance_status='non_compliant'),
    (SELECT COUNT(*) FROM uniform_photo_captures_r2736 WHERE verified=true),
    (SELECT COUNT(*) FROM uniform_compliance_actions_r2736 WHERE status IN ('open','in_progress','escalated')),
    (SELECT ROUND(AVG(uniform_score)::numeric, 2) FROM uniform_photo_captures_r2736);
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2736_list_captures();
CREATE OR REPLACE FUNCTION r2736_list_captures()
RETURNS TABLE(id uuid, job_code text, customer_org text, engineer_name text, capture_at timestamptz, uniform_score integer, compliance_status text, on_site boolean, verified boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.job_code, c.customer_org, c.engineer_name, c.capture_at, c.uniform_score, c.compliance_status, c.on_site, c.verified
  FROM uniform_photo_captures_r2736 c
  ORDER BY c.capture_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_list_captures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_list_captures() TO authenticated;

DROP FUNCTION IF EXISTS r2736_list_actions();
CREATE OR REPLACE FUNCTION r2736_list_actions()
RETURNS TABLE(id uuid, job_code text, issue_type text, severity text, action_taken text, action_owner text, status text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, c.job_code, a.issue_type, a.severity, a.action_taken, a.action_owner, a.status, a.created_at
  FROM uniform_compliance_actions_r2736 a
  JOIN uniform_photo_captures_r2736 c ON c.id = a.capture_id
  ORDER BY a.created_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_list_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_list_actions() TO authenticated;

DROP FUNCTION IF EXISTS r2736_compliance_breakdown();
CREATE OR REPLACE FUNCTION r2736_compliance_breakdown()
RETURNS TABLE(compliance_status text, captures bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.compliance_status, COUNT(*)::bigint, ROUND(AVG(c.uniform_score)::numeric,2)
  FROM uniform_photo_captures_r2736 c
  GROUP BY c.compliance_status
  ORDER BY captures DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_compliance_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_compliance_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2736_issue_breakdown();
CREATE OR REPLACE FUNCTION r2736_issue_breakdown()
RETURNS TABLE(issue_type text, actions bigint, open_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.issue_type, COUNT(*)::bigint, COUNT(*) FILTER (WHERE a.status IN ('open','in_progress','escalated'))::bigint
  FROM uniform_compliance_actions_r2736 a
  GROUP BY a.issue_type
  ORDER BY actions DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_issue_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_issue_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2736_engineer_scores();
CREATE OR REPLACE FUNCTION r2736_engineer_scores()
RETURNS TABLE(engineer_name text, captures bigint, avg_score numeric, non_compliant_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_name, COUNT(*)::bigint, ROUND(AVG(c.uniform_score)::numeric,2), COUNT(*) FILTER (WHERE c.compliance_status='non_compliant')::bigint
  FROM uniform_photo_captures_r2736 c
  GROUP BY c.engineer_name
  ORDER BY avg_score ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_engineer_scores() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_engineer_scores() TO authenticated;

DROP FUNCTION IF EXISTS r2736_unverified_queue();
CREATE OR REPLACE FUNCTION r2736_unverified_queue()
RETURNS TABLE(job_code text, customer_org text, engineer_name text, uniform_score integer, compliance_status text, capture_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.job_code, c.customer_org, c.engineer_name, c.uniform_score, c.compliance_status, c.capture_at
  FROM uniform_photo_captures_r2736 c
  WHERE c.verified = false
  ORDER BY c.capture_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_unverified_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_unverified_queue() TO authenticated;

DROP FUNCTION IF EXISTS r2736_severity_breakdown();
CREATE OR REPLACE FUNCTION r2736_severity_breakdown()
RETURNS TABLE(severity text, actions bigint, resolved bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.severity, COUNT(*)::bigint, COUNT(*) FILTER (WHERE a.status='resolved')::bigint
  FROM uniform_compliance_actions_r2736 a
  GROUP BY a.severity
  ORDER BY actions DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION r2736_severity_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2736_severity_breakdown() TO authenticated;

COMMIT;