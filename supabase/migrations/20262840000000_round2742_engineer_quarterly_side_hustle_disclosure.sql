BEGIN;

-- ============================================================================
-- Round 2742 — Engineer Quarterly Side-Hustle Disclosure
-- engineer × side activity × hours × conflict risk × disclosure × approval verdict
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: engineer_side_hustle_disclosures_r2742
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_side_hustle_disclosures_r2742 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  quarter text NOT NULL,
  activity_type text NOT NULL CHECK (activity_type IN ('consulting','teaching','freelance_repair','equipment_sales','content_creation','medical_device_advisory','startup_founder','other')),
  activity_description text NOT NULL,
  external_org text,
  weekly_hours numeric(5,2) NOT NULL CHECK (weekly_hours >= 0 AND weekly_hours <= 40),
  monthly_income_rupees integer NOT NULL DEFAULT 0,
  uses_equipseva_tools boolean NOT NULL DEFAULT false,
  serves_equipseva_clients boolean NOT NULL DEFAULT false,
  conflict_risk_score numeric(4,2) NOT NULL CHECK (conflict_risk_score >= 0 AND conflict_risk_score <= 10),
  conflict_risk_band text NOT NULL CHECK (conflict_risk_band IN ('low','medium','high','critical')),
  disclosure_status text NOT NULL CHECK (disclosure_status IN ('draft','submitted','under_review','approved','rejected','conditional','withdrawn')),
  approval_verdict text CHECK (approval_verdict IN ('approved_no_conditions','approved_with_conditions','approved_time_capped','rejected_conflict','rejected_policy','pending')),
  verdict_notes text,
  submitted_at timestamptz NOT NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_side_hustle_disclosures_r2742 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_side_hustle_disclosures_r2742;
CREATE POLICY founder_all ON engineer_side_hustle_disclosures_r2742 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_side_hustle_disclosures_r2742 (engineer_name, engineer_code, quarter, activity_type, activity_description, external_org, weekly_hours, monthly_income_rupees, uses_equipseva_tools, serves_equipseva_clients, conflict_risk_score, conflict_risk_band, disclosure_status, approval_verdict, verdict_notes, submitted_at, reviewed_at) VALUES
('Ramesh Iyer','ENG-2201','Q2-2026','teaching','Biomedical equipment evening course at JNTU','JNTU Hyderabad',6.00,18000,false,false,1.20,'low','approved','approved_no_conditions','Educational, no conflict','2026-06-01 10:00+05:30','2026-06-03 14:00+05:30'),
('Anita Sharma','ENG-2202','Q2-2026','consulting','Hospital BMS consulting for non-customer chain','MediHealth Group',8.00,42000,true,false,5.80,'medium','approved','approved_with_conditions','No EquipSeva tools, monthly report required','2026-05-28 09:30+05:30','2026-06-02 11:00+05:30'),
('Vikram Reddy','ENG-2203','Q2-2026','freelance_repair','Weekend ventilator repair for current customer','Apollo Health',12.00,65000,true,true,9.40,'critical','rejected','rejected_conflict','Direct customer poaching — terminate immediately','2026-05-30 15:00+05:30','2026-06-01 09:00+05:30'),
('Priya Nair','ENG-2204','Q2-2026','content_creation','YouTube channel on medical device basics',NULL,4.50,8000,false,false,2.10,'low','approved','approved_no_conditions','Generic educational content','2026-06-05 11:00+05:30','2026-06-07 10:00+05:30'),
('Suresh Kumar','ENG-2205','Q2-2026','startup_founder','Co-founder of dental imaging startup','DentalPixel',15.00,0,false,false,7.20,'high','conditional','approved_time_capped','Cap at 10h/week; quarterly review','2026-06-08 14:00+05:30','2026-06-12 16:00+05:30'),
('Meera Patel','ENG-2206','Q2-2026','equipment_sales','Refurb defib resale on marketplace',NULL,5.00,28000,false,true,8.50,'critical','under_review','pending','Investigating customer overlap','2026-06-10 12:00+05:30',NULL),
('Karthik Rao','ENG-2207','Q2-2026','medical_device_advisory','Advisor to seed-stage MedTech startup','PulseAI Labs',3.00,15000,false,false,4.30,'medium','submitted','pending','Need conflict screening','2026-06-15 09:00+05:30',NULL),
('Deepa Singh','ENG-2208','Q1-2026','other','Tutoring biomed students at home',NULL,4.00,6000,false,false,0.80,'low','approved','approved_no_conditions','Trivial scope','2026-03-15 10:00+05:30','2026-03-18 11:00+05:30');

-- ----------------------------------------------------------------------------
-- Table 2: engineer_side_hustle_audit_events_r2742
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_side_hustle_audit_events_r2742 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  disclosure_id uuid NOT NULL REFERENCES engineer_side_hustle_disclosures_r2742(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('submitted','reviewer_assigned','conflict_check','customer_overlap_scan','tools_audit','income_verified','approved','rejected','conditional_set','renewed','withdrawn','escalated')),
  event_severity text NOT NULL CHECK (event_severity IN ('info','warn','high','critical')),
  actor text NOT NULL,
  notes text NOT NULL,
  evidence_url text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_side_hustle_audit_events_r2742 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_side_hustle_audit_events_r2742;
CREATE POLICY founder_all ON engineer_side_hustle_audit_events_r2742 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'submitted','info','engineer_self','Initial disclosure form submitted','https://docs.example.com/disc/'||d.engineer_code,'2026-06-01 10:05+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2201';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'customer_overlap_scan','critical','compliance_bot','Direct overlap with active customer Apollo Health',NULL,'2026-05-31 09:30+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2203';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'rejected','critical','founder','Termination notice queued','https://docs.example.com/term/ENG-2203','2026-06-01 09:05+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2203';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'conditional_set','warn','compliance_lead','10h/week cap + quarterly review imposed',NULL,'2026-06-12 16:05+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2205';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'tools_audit','high','it_team','Confirmed no EquipSeva ticketing tool used externally',NULL,'2026-06-02 10:30+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2202';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'escalated','high','reviewer_2','Flagged for founder review — possible customer overlap',NULL,'2026-06-11 09:00+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2206';

INSERT INTO engineer_side_hustle_audit_events_r2742 (disclosure_id, event_type, event_severity, actor, notes, evidence_url, occurred_at)
SELECT d.id, 'reviewer_assigned','info','triage_bot','Assigned to compliance_lead',NULL,'2026-06-15 09:30+05:30'
FROM engineer_side_hustle_disclosures_r2742 d WHERE d.engineer_code = 'ENG-2207';

-- ----------------------------------------------------------------------------
-- RPC 1: KPI overview
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_kpis_r2742();
CREATE FUNCTION founder_side_hustle_kpis_r2742()
RETURNS TABLE(
  total_disclosures int,
  pending_review int,
  approved_count int,
  rejected_count int,
  critical_risk_count int,
  total_external_hours numeric,
  total_external_income_rupees bigint,
  customer_overlap_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE disclosure_status IN ('submitted','under_review'))::int,
    COUNT(*) FILTER (WHERE disclosure_status = 'approved')::int,
    COUNT(*) FILTER (WHERE disclosure_status = 'rejected')::int,
    COUNT(*) FILTER (WHERE conflict_risk_band = 'critical')::int,
    COALESCE(SUM(weekly_hours),0)::numeric,
    COALESCE(SUM(monthly_income_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE serves_equipseva_clients)::int
  FROM engineer_side_hustle_disclosures_r2742;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_kpis_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_kpis_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 2: List disclosures
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_list_r2742();
CREATE FUNCTION founder_side_hustle_list_r2742()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  engineer_code text,
  quarter text,
  activity_type text,
  weekly_hours numeric,
  monthly_income_rupees int,
  conflict_risk_score numeric,
  conflict_risk_band text,
  disclosure_status text,
  approval_verdict text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_name, d.engineer_code, d.quarter, d.activity_type,
         d.weekly_hours, d.monthly_income_rupees, d.conflict_risk_score,
         d.conflict_risk_band, d.disclosure_status, d.approval_verdict, d.submitted_at
  FROM engineer_side_hustle_disclosures_r2742 d
  ORDER BY
    CASE d.conflict_risk_band WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    d.submitted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_list_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_list_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 3: Breakdown by activity type
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_by_activity_r2742();
CREATE FUNCTION founder_side_hustle_by_activity_r2742()
RETURNS TABLE(
  activity_type text,
  count int,
  avg_weekly_hours numeric,
  avg_risk_score numeric,
  total_income_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.activity_type,
         COUNT(*)::int,
         ROUND(AVG(d.weekly_hours),2)::numeric,
         ROUND(AVG(d.conflict_risk_score),2)::numeric,
         COALESCE(SUM(d.monthly_income_rupees),0)::bigint
  FROM engineer_side_hustle_disclosures_r2742 d
  GROUP BY d.activity_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_by_activity_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_by_activity_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 4: Risk band breakdown
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_by_risk_r2742();
CREATE FUNCTION founder_side_hustle_by_risk_r2742()
RETURNS TABLE(
  conflict_risk_band text,
  count int,
  approved_count int,
  rejected_count int,
  avg_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.conflict_risk_band,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE d.disclosure_status = 'approved')::int,
         COUNT(*) FILTER (WHERE d.disclosure_status = 'rejected')::int,
         ROUND(AVG(d.weekly_hours),2)::numeric
  FROM engineer_side_hustle_disclosures_r2742 d
  GROUP BY d.conflict_risk_band
  ORDER BY
    CASE d.conflict_risk_band WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_by_risk_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_by_risk_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 5: Critical conflicts requiring action
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_critical_r2742();
CREATE FUNCTION founder_side_hustle_critical_r2742()
RETURNS TABLE(
  id uuid,
  engineer_name text,
  engineer_code text,
  activity_type text,
  activity_description text,
  weekly_hours numeric,
  conflict_risk_score numeric,
  uses_equipseva_tools boolean,
  serves_equipseva_clients boolean,
  disclosure_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_name, d.engineer_code, d.activity_type, d.activity_description,
         d.weekly_hours, d.conflict_risk_score, d.uses_equipseva_tools,
         d.serves_equipseva_clients, d.disclosure_status
  FROM engineer_side_hustle_disclosures_r2742 d
  WHERE d.conflict_risk_band IN ('high','critical')
     OR d.serves_equipseva_clients = true
  ORDER BY d.conflict_risk_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_critical_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_critical_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 6: Audit timeline
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_audit_timeline_r2742();
CREATE FUNCTION founder_side_hustle_audit_timeline_r2742()
RETURNS TABLE(
  id uuid,
  engineer_code text,
  engineer_name text,
  event_type text,
  event_severity text,
  actor text,
  notes text,
  occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, d.engineer_code, d.engineer_name, e.event_type, e.event_severity,
         e.actor, e.notes, e.occurred_at
  FROM engineer_side_hustle_audit_events_r2742 e
  JOIN engineer_side_hustle_disclosures_r2742 d ON d.id = e.disclosure_id
  ORDER BY e.occurred_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_audit_timeline_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_audit_timeline_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 7: Quarter rollup
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_quarter_rollup_r2742();
CREATE FUNCTION founder_side_hustle_quarter_rollup_r2742()
RETURNS TABLE(
  quarter text,
  total_disclosures int,
  approved_count int,
  rejected_count int,
  conditional_count int,
  pending_count int,
  total_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.quarter,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE d.disclosure_status = 'approved')::int,
         COUNT(*) FILTER (WHERE d.disclosure_status = 'rejected')::int,
         COUNT(*) FILTER (WHERE d.disclosure_status = 'conditional')::int,
         COUNT(*) FILTER (WHERE d.disclosure_status IN ('submitted','under_review'))::int,
         COALESCE(SUM(d.weekly_hours),0)::numeric
  FROM engineer_side_hustle_disclosures_r2742 d
  GROUP BY d.quarter
  ORDER BY d.quarter DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_quarter_rollup_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_quarter_rollup_r2742() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 8: Verdict breakdown
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_side_hustle_verdict_breakdown_r2742();
CREATE FUNCTION founder_side_hustle_verdict_breakdown_r2742()
RETURNS TABLE(
  approval_verdict text,
  count int,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_side_hustle_disclosures_r2742 WHERE approval_verdict IS NOT NULL;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT COALESCE(d.approval_verdict,'pending')::text,
         COUNT(*)::int,
         ROUND((COUNT(*)::numeric / total) * 100, 2)::numeric
  FROM engineer_side_hustle_disclosures_r2742 d
  WHERE d.approval_verdict IS NOT NULL
  GROUP BY d.approval_verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_side_hustle_verdict_breakdown_r2742() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_hustle_verdict_breakdown_r2742() TO authenticated;

COMMIT;
