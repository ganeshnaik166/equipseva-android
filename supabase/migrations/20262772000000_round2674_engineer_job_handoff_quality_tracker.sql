BEGIN;

-- ============================================================
-- Round 2674 — Engineer Job Handoff Quality Tracker
-- job × outgoing eng × incoming eng × handoff quality × gaps × recovery
-- ============================================================

DROP TABLE IF EXISTS engineer_job_handoffs_r2674 CASCADE;
CREATE TABLE engineer_job_handoffs_r2674 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_code text NOT NULL UNIQUE,
  job_code text NOT NULL,
  hospital_name text NOT NULL,
  device_kind text NOT NULL,
  outgoing_engineer text NOT NULL,
  outgoing_tier text NOT NULL,
  incoming_engineer text NOT NULL,
  incoming_tier text NOT NULL,
  handoff_reason text NOT NULL,
  handoff_started_at timestamptz NOT NULL,
  handoff_completed_at timestamptz,
  quality_score numeric(4,1) NOT NULL,
  quality_grade text NOT NULL,
  handoff_status text NOT NULL,
  customer_impact text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_job_handoffs_r2674 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_job_handoffs_r2674;
CREATE POLICY founder_all ON engineer_job_handoffs_r2674
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_job_handoffs_r2674 (handoff_code, job_code, hospital_name, device_kind, outgoing_engineer, outgoing_tier, incoming_engineer, incoming_tier, handoff_reason, handoff_started_at, handoff_completed_at, quality_score, quality_grade, handoff_status, customer_impact) VALUES
('HOF-2674-001', 'RJ-44821', 'Apollo Jubilee Hills', 'CT Scanner', 'Ravi Kumar', 'gold', 'Suresh Iyer', 'silver', 'engineer_on_leave', now() - interval '8 days', now() - interval '7 days 22 hours', 92.0, 'A', 'completed_clean', 'none'),
('HOF-2674-002', 'RJ-44912', 'KIMS Secunderabad', 'MRI', 'Anita Rao', 'platinum', 'Vikas Sharma', 'gold', 'tier_escalation', now() - interval '6 days', now() - interval '5 days 23 hours', 88.5, 'A', 'completed_clean', 'minor_delay'),
('HOF-2674-003', 'RJ-45033', 'Rainbow Hospitals', 'Ventilator', 'Deepak Joshi', 'silver', 'Rakesh Pillai', 'silver', 'engineer_resigned', now() - interval '4 days', now() - interval '3 days 18 hours', 58.0, 'D', 'completed_with_gaps', 'csat_drop'),
('HOF-2674-004', 'RJ-45144', 'Yashoda Somajiguda', 'Dialysis', 'Manoj Reddy', 'gold', 'Pradeep Naik', 'gold', 'territory_realign', now() - interval '3 days', now() - interval '2 days 21 hours', 76.0, 'B', 'completed_minor_gaps', 'sla_at_risk'),
('HOF-2674-005', 'RJ-45255', 'Care Hospitals Banjara', 'Ultrasound', 'Sneha Patil', 'silver', 'Karthik Menon', 'gold', 'complex_escalation', now() - interval '2 days', NULL, 41.0, 'F', 'stalled', 'sla_breached'),
('HOF-2674-006', 'RJ-45366', 'Continental Hospitals', 'X-Ray', 'Vinod Bhat', 'gold', 'Harish Desai', 'silver', 'engineer_on_leave', now() - interval '12 hours', now() - interval '8 hours', 95.5, 'A', 'completed_clean', 'none'),
('HOF-2674-007', 'RJ-45477', 'Sunshine Gachibowli', 'Patient Monitor', 'Lakshmi N', 'silver', 'Arjun Kapoor', 'gold', 'tier_escalation', now() - interval '1 day', now() - interval '20 hours', 71.0, 'C', 'completed_minor_gaps', 'minor_delay');

DROP TABLE IF EXISTS engineer_handoff_gaps_r2674 CASCADE;
CREATE TABLE engineer_handoff_gaps_r2674 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_code text NOT NULL,
  gap_category text NOT NULL,
  gap_description text NOT NULL,
  severity text NOT NULL,
  detected_by text NOT NULL,
  detected_at timestamptz NOT NULL,
  recovery_action text NOT NULL,
  recovery_owner text NOT NULL,
  recovery_status text NOT NULL,
  resolved_at timestamptz,
  cost_to_recover_rupees integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handoff_gaps_r2674 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handoff_gaps_r2674;
CREATE POLICY founder_all ON engineer_handoff_gaps_r2674
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_handoff_gaps_r2674 (handoff_code, gap_category, gap_description, severity, detected_by, detected_at, recovery_action, recovery_owner, recovery_status, resolved_at, cost_to_recover_rupees) VALUES
('HOF-2674-003', 'missing_diagnostic_notes', 'Outgoing engineer did not log root-cause hypothesis before exit', 'high', 'incoming_engineer', now() - interval '3 days 12 hours', 'reconstruct from device logs + customer call', 'Rakesh Pillai', 'resolved', now() - interval '3 days 4 hours', 4500),
('HOF-2674-003', 'parts_inventory_mismatch', 'Spare parts marked installed but not actually fitted', 'critical', 'customer', now() - interval '3 days 6 hours', 'physical audit + reorder + apology call', 'ops_supervisor', 'resolved', now() - interval '2 days 18 hours', 18500),
('HOF-2674-004', 'customer_context_missing', 'No briefing on hospital biomed contact preferences', 'medium', 'incoming_engineer', now() - interval '2 days 22 hours', 'shadow call with outgoing engineer', 'Manoj Reddy', 'resolved', now() - interval '2 days 20 hours', 0),
('HOF-2674-005', 'no_warm_handoff_call', 'Outgoing engineer did not call incoming before reassignment', 'high', 'qa_audit', now() - interval '1 day 22 hours', 'force scheduled 30-min call + log to CRM', 'csm_lead', 'in_progress', NULL, 1500),
('HOF-2674-005', 'sla_clock_not_paused', 'Customer SLA continued running through handoff window', 'critical', 'sla_engine', now() - interval '1 day 18 hours', 'credit 1 day to AMC + escalate to founder', 'founder', 'open', NULL, 12000),
('HOF-2674-007', 'tool_kit_not_transferred', 'Specialty calibration kit retained by outgoing engineer', 'medium', 'incoming_engineer', now() - interval '22 hours', 'courier same-day + remind outgoing', 'logistics', 'resolved', now() - interval '12 hours', 850),
('HOF-2674-002', 'documentation_incomplete', 'Service report PDF missing signature page', 'low', 'qa_audit', now() - interval '5 days 12 hours', 're-sign + re-upload', 'Anita Rao', 'resolved', now() - interval '5 days 10 hours', 0);

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_handoff_kpis_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_kpis_r2674()
RETURNS TABLE(
  total_handoffs bigint,
  clean_handoffs bigint,
  stalled_handoffs bigint,
  avg_quality_score numeric,
  pct_with_gaps numeric,
  total_recovery_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM engineer_job_handoffs_r2674),
    (SELECT count(*) FROM engineer_job_handoffs_r2674 WHERE handoff_status = 'completed_clean'),
    (SELECT count(*) FROM engineer_job_handoffs_r2674 WHERE handoff_status = 'stalled'),
    (SELECT round(avg(quality_score)::numeric, 1) FROM engineer_job_handoffs_r2674),
    (SELECT round(100.0 * count(DISTINCT handoff_code)::numeric / NULLIF((SELECT count(*) FROM engineer_job_handoffs_r2674),0), 1) FROM engineer_handoff_gaps_r2674),
    (SELECT coalesce(sum(cost_to_recover_rupees),0) FROM engineer_handoff_gaps_r2674);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_kpis_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_kpis_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_list_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_list_r2674()
RETURNS TABLE(
  handoff_code text,
  job_code text,
  hospital_name text,
  device_kind text,
  outgoing_engineer text,
  incoming_engineer text,
  handoff_reason text,
  quality_score numeric,
  quality_grade text,
  handoff_status text,
  customer_impact text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.handoff_code, h.job_code, h.hospital_name, h.device_kind,
         h.outgoing_engineer, h.incoming_engineer, h.handoff_reason,
         h.quality_score, h.quality_grade, h.handoff_status, h.customer_impact
  FROM engineer_job_handoffs_r2674 h
  ORDER BY h.handoff_started_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_list_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_list_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_gap_list_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_gap_list_r2674()
RETURNS TABLE(
  handoff_code text,
  gap_category text,
  gap_description text,
  severity text,
  detected_by text,
  recovery_action text,
  recovery_owner text,
  recovery_status text,
  cost_to_recover_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.handoff_code, g.gap_category, g.gap_description, g.severity,
         g.detected_by, g.recovery_action, g.recovery_owner,
         g.recovery_status, g.cost_to_recover_rupees
  FROM engineer_handoff_gaps_r2674 g
  ORDER BY
    CASE g.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    g.detected_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_gap_list_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_gap_list_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_by_outgoing_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_by_outgoing_r2674()
RETURNS TABLE(
  outgoing_engineer text,
  outgoing_tier text,
  handoff_count bigint,
  avg_quality numeric,
  clean_count bigint,
  stalled_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.outgoing_engineer, h.outgoing_tier,
         count(*),
         round(avg(h.quality_score)::numeric, 1),
         count(*) FILTER (WHERE h.handoff_status = 'completed_clean'),
         count(*) FILTER (WHERE h.handoff_status = 'stalled')
  FROM engineer_job_handoffs_r2674 h
  GROUP BY h.outgoing_engineer, h.outgoing_tier
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_by_outgoing_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_by_outgoing_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_by_reason_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_by_reason_r2674()
RETURNS TABLE(
  handoff_reason text,
  handoff_count bigint,
  avg_quality numeric,
  gap_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.handoff_reason,
         count(*),
         round(avg(h.quality_score)::numeric, 1),
         (SELECT count(*) FROM engineer_handoff_gaps_r2674 g
          WHERE g.handoff_code IN (SELECT handoff_code FROM engineer_job_handoffs_r2674 WHERE handoff_reason = h.handoff_reason))
  FROM engineer_job_handoffs_r2674 h
  GROUP BY h.handoff_reason
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_by_reason_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_by_reason_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_gap_severity_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_gap_severity_r2674()
RETURNS TABLE(
  severity text,
  gap_count bigint,
  resolved_count bigint,
  open_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.severity,
         count(*),
         count(*) FILTER (WHERE g.recovery_status = 'resolved'),
         count(*) FILTER (WHERE g.recovery_status IN ('open','in_progress')),
         coalesce(sum(g.cost_to_recover_rupees),0)
  FROM engineer_handoff_gaps_r2674 g
  GROUP BY g.severity
  ORDER BY CASE g.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_gap_severity_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_gap_severity_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_open_recovery_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_open_recovery_r2674()
RETURNS TABLE(
  handoff_code text,
  gap_category text,
  severity text,
  recovery_action text,
  recovery_owner text,
  recovery_status text,
  cost_to_recover_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.handoff_code, g.gap_category, g.severity,
         g.recovery_action, g.recovery_owner, g.recovery_status,
         g.cost_to_recover_rupees
  FROM engineer_handoff_gaps_r2674 g
  WHERE g.recovery_status IN ('open','in_progress')
  ORDER BY
    CASE g.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    g.cost_to_recover_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_open_recovery_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_open_recovery_r2674() TO authenticated;

DROP FUNCTION IF EXISTS founder_handoff_impact_breakdown_r2674();
CREATE OR REPLACE FUNCTION founder_handoff_impact_breakdown_r2674()
RETURNS TABLE(
  customer_impact text,
  handoff_count bigint,
  avg_quality numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.customer_impact,
         count(*),
         round(avg(h.quality_score)::numeric, 1)
  FROM engineer_job_handoffs_r2674 h
  GROUP BY h.customer_impact
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_handoff_impact_breakdown_r2674() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_handoff_impact_breakdown_r2674() TO authenticated;

COMMIT;
