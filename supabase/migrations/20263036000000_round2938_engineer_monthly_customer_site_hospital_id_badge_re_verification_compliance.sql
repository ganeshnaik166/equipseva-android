-- Round r2938: Engineer Monthly Customer Site Hospital ID-Badge Re-Verification Compliance

CREATE TABLE IF NOT EXISTS engineer_badge_reverifications_r2938 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  hospital_code text NOT NULL,
  hospital_city text NOT NULL,
  reverification_month date NOT NULL,
  badge_serial text NOT NULL,
  badge_status text NOT NULL CHECK (badge_status IN ('verified','expired','tampered','missing','reissued')),
  photo_match_score numeric(5,2) NOT NULL,
  hospital_signoff_at timestamptz,
  compliance_flag text NOT NULL CHECK (compliance_flag IN ('compliant','warning','non_compliant','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_badge_reverifications_r2938 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS engineer_badge_audit_events_r2938 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  hospital_code text NOT NULL,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_type text NOT NULL CHECK (event_type IN ('check_in','badge_scan','photo_capture','signoff','escalation','reissue')),
  severity text NOT NULL CHECK (severity IN ('info','low','medium','high','critical')),
  resolution_state text NOT NULL CHECK (resolution_state IN ('open','in_review','resolved','escalated','dismissed')),
  duration_minutes int NOT NULL DEFAULT 0,
  detail text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_badge_audit_events_r2938 ENABLE ROW LEVEL SECURITY;

INSERT INTO engineer_badge_reverifications_r2938 (engineer_code, hospital_code, hospital_city, reverification_month, badge_serial, badge_status, photo_match_score, hospital_signoff_at, compliance_flag, notes) VALUES
('ENG-2101','HOS-DEL-01','Delhi','2026-06-01'::date,'BDG-44801','verified',97.40,'2026-06-03 11:20'::timestamptz,'compliant','clean monthly check'),
('ENG-2102','HOS-MUM-02','Mumbai','2026-06-01'::date,'BDG-44802','verified',95.10,'2026-06-04 09:45'::timestamptz,'compliant','photo refresh ok'),
('ENG-2103','HOS-BLR-03','Bengaluru','2026-06-01'::date,'BDG-44803','expired',88.20,NULL,'warning','badge past validity 12 days'),
('ENG-2104','HOS-HYD-04','Hyderabad','2026-06-01'::date,'BDG-44804','tampered',61.50,NULL,'critical','laminate peeled, photo mismatch'),
('ENG-2105','HOS-CHE-05','Chennai','2026-06-01'::date,'BDG-44805','missing',0.00,NULL,'non_compliant','badge lost on rural trip'),
('ENG-2106','HOS-KOL-06','Kolkata','2026-06-01'::date,'BDG-44806','reissued',96.80,'2026-06-05 14:10'::timestamptz,'compliant','reissued post damage'),
('ENG-2107','HOS-PUN-07','Pune','2026-06-01'::date,'BDG-44807','verified',98.20,'2026-06-02 10:00'::timestamptz,'compliant','flagship hospital'),
('ENG-2108','HOS-AHM-08','Ahmedabad','2026-06-01'::date,'BDG-44808','verified',93.40,'2026-06-06 12:30'::timestamptz,'compliant','minor scratch noted'),
('ENG-2109','HOS-JAI-09','Jaipur','2026-06-01'::date,'BDG-44809','expired',85.10,NULL,'warning','renewal scheduled'),
('ENG-2110','HOS-LUC-10','Lucknow','2026-06-01'::date,'BDG-44810','verified',91.30,'2026-06-07 16:00'::timestamptz,'compliant','ok'),
('ENG-2111','HOS-IND-11','Indore','2026-06-01'::date,'BDG-44811','tampered',58.90,NULL,'critical','suspicious sticker overlay'),
('ENG-2112','HOS-NAG-12','Nagpur','2026-06-01'::date,'BDG-44812','verified',94.60,'2026-06-08 09:15'::timestamptz,'compliant','passed'),
('ENG-2113','HOS-COI-13','Coimbatore','2026-06-01'::date,'BDG-44813','verified',96.10,'2026-06-08 11:45'::timestamptz,'compliant','passed'),
('ENG-2114','HOS-BHU-14','Bhubaneswar','2026-06-01'::date,'BDG-44814','reissued',92.20,'2026-06-09 10:20'::timestamptz,'compliant','reissued after relocation'),
('ENG-2115','HOS-VIS-15','Visakhapatnam','2026-06-01'::date,'BDG-44815','verified',95.70,'2026-06-09 14:50'::timestamptz,'compliant','clean'),
('ENG-2116','HOS-DEL-16','Delhi','2026-06-01'::date,'BDG-44816','expired',80.40,NULL,'warning','engineer on leave'),
('ENG-2117','HOS-MUM-17','Mumbai','2026-06-01'::date,'BDG-44817','missing',0.00,NULL,'non_compliant','reported stolen'),
('ENG-2118','HOS-BLR-18','Bengaluru','2026-06-01'::date,'BDG-44818','verified',97.90,'2026-06-10 11:00'::timestamptz,'compliant','top score'),
('ENG-2119','HOS-HYD-19','Hyderabad','2026-06-01'::date,'BDG-44819','verified',93.00,'2026-06-10 13:30'::timestamptz,'compliant','passed'),
('ENG-2120','HOS-CHE-20','Chennai','2026-06-01'::date,'BDG-44820','tampered',55.20,NULL,'critical','field investigation opened');

INSERT INTO engineer_badge_audit_events_r2938 (engineer_code, hospital_code, event_at, event_type, severity, resolution_state, duration_minutes, detail) VALUES
('ENG-2101','HOS-DEL-01','2026-06-03 11:18'::timestamptz,'check_in','info','resolved',4,'arrived on site'),
('ENG-2101','HOS-DEL-01','2026-06-03 11:20'::timestamptz,'badge_scan','info','resolved',1,'QR scanned ok'),
('ENG-2103','HOS-BLR-03','2026-06-04 10:11'::timestamptz,'badge_scan','medium','open',2,'expiry detected'),
('ENG-2104','HOS-HYD-04','2026-06-04 12:30'::timestamptz,'photo_capture','high','escalated',7,'photo mismatch >30%'),
('ENG-2104','HOS-HYD-04','2026-06-04 12:50'::timestamptz,'escalation','critical','in_review',20,'tamper alert to ops'),
('ENG-2105','HOS-CHE-05','2026-06-05 09:00'::timestamptz,'escalation','critical','escalated',45,'badge missing'),
('ENG-2106','HOS-KOL-06','2026-06-05 14:00'::timestamptz,'reissue','low','resolved',30,'new badge printed'),
('ENG-2107','HOS-PUN-07','2026-06-02 09:55'::timestamptz,'signoff','info','resolved',3,'flagship signoff'),
('ENG-2108','HOS-AHM-08','2026-06-06 12:25'::timestamptz,'badge_scan','low','resolved',2,'minor wear'),
('ENG-2111','HOS-IND-11','2026-06-07 11:00'::timestamptz,'photo_capture','high','escalated',9,'sticker overlay'),
('ENG-2111','HOS-IND-11','2026-06-07 11:30'::timestamptz,'escalation','critical','in_review',25,'tamper investigation'),
('ENG-2114','HOS-BHU-14','2026-06-09 10:15'::timestamptz,'reissue','low','resolved',28,'relocation reissue'),
('ENG-2117','HOS-MUM-17','2026-06-08 08:30'::timestamptz,'escalation','critical','escalated',50,'stolen badge'),
('ENG-2118','HOS-BLR-18','2026-06-10 10:55'::timestamptz,'signoff','info','resolved',2,'clean signoff'),
('ENG-2120','HOS-CHE-20','2026-06-10 15:00'::timestamptz,'photo_capture','high','escalated',12,'mismatch detected'),
('ENG-2120','HOS-CHE-20','2026-06-10 15:20'::timestamptz,'escalation','critical','in_review',35,'field investigation'),
('ENG-2102','HOS-MUM-02','2026-06-04 09:40'::timestamptz,'check_in','info','resolved',3,'on time'),
('ENG-2109','HOS-JAI-09','2026-06-06 10:10'::timestamptz,'badge_scan','medium','open',2,'expired badge'),
('ENG-2112','HOS-NAG-12','2026-06-08 09:10'::timestamptz,'signoff','info','resolved',2,'ok'),
('ENG-2116','HOS-DEL-16','2026-06-07 14:00'::timestamptz,'badge_scan','medium','dismissed',2,'engineer on leave, re-checked next visit');

CREATE OR REPLACE FUNCTION founder_r2938_compliance_summary()
RETURNS TABLE(compliance_flag text, total int, avg_match numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.compliance_flag, count(*)::int, round(avg(r.photo_match_score)::numeric,2)
  FROM engineer_badge_reverifications_r2938 r
  GROUP BY r.compliance_flag
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_badge_status_breakdown()
RETURNS TABLE(badge_status text, total int, signed_off int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.badge_status, count(*)::int,
         (count(*) filter (where r.hospital_signoff_at is not null))::int
  FROM engineer_badge_reverifications_r2938 r
  GROUP BY r.badge_status
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_top_risk_engineers()
RETURNS TABLE(engineer_code text, hospital_code text, badge_status text, photo_match_score numeric, compliance_flag text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.hospital_code, r.badge_status, r.photo_match_score, r.compliance_flag
  FROM engineer_badge_reverifications_r2938 r
  WHERE r.compliance_flag IN ('critical','non_compliant','warning')
  ORDER BY r.photo_match_score ASC
  LIMIT 10;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_city_rollup()
RETURNS TABLE(hospital_city text, total int, critical int, avg_match numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.hospital_city, count(*)::int,
         (count(*) filter (where r.compliance_flag = 'critical'))::int,
         round(avg(r.photo_match_score)::numeric,2)
  FROM engineer_badge_reverifications_r2938 r
  GROUP BY r.hospital_city
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_event_severity_mix()
RETURNS TABLE(severity text, total int, open_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.severity, count(*)::int,
         (count(*) filter (where e.resolution_state IN ('open','in_review','escalated')))::int
  FROM engineer_badge_audit_events_r2938 e
  GROUP BY e.severity
  ORDER BY count(*) DESC;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_open_escalations()
RETURNS TABLE(engineer_code text, hospital_code text, event_type text, severity text, detail text, event_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_code, e.hospital_code, e.event_type, e.severity, e.detail, e.event_at
  FROM engineer_badge_audit_events_r2938 e
  WHERE e.resolution_state IN ('open','in_review','escalated')
    AND e.severity IN ('high','critical','medium')
  ORDER BY e.event_at DESC
  LIMIT 15;
END;$$;

CREATE OR REPLACE FUNCTION founder_r2938_event_type_volume()
RETURNS TABLE(event_type text, total int, avg_duration numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_type, count(*)::int, round(avg(e.duration_minutes)::numeric,2)
  FROM engineer_badge_audit_events_r2938 e
  GROUP BY e.event_type
  ORDER BY count(*) DESC;
END;$$;

REVOKE EXECUTE ON FUNCTION founder_r2938_compliance_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_badge_status_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_top_risk_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_city_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_event_severity_mix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_open_escalations() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2938_event_type_volume() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2938_compliance_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_badge_status_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_top_risk_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_city_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_event_severity_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_open_escalations() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2938_event_type_volume() TO authenticated;
