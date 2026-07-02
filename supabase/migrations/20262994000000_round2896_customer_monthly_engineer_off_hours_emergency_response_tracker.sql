-- Round r2896 — Customer Monthly Engineer Off-Hours Emergency Response Tracker
-- Heavy founder ops round. Hospital outcomes + retention angle.

CREATE TABLE IF NOT EXISTS off_hours_emergency_calls_r2896 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_org_id uuid,
  hospital_name text NOT NULL,
  call_month date NOT NULL,
  call_opened_at timestamptz NOT NULL,
  call_closed_at timestamptz,
  device_category text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  engineer_user_id uuid,
  engineer_name text,
  engineer_tier text,
  on_call_window text NOT NULL CHECK (on_call_window IN ('night','weekend','holiday','dawn')),
  response_minutes integer NOT NULL,
  resolution_minutes integer,
  patient_impact text NOT NULL CHECK (patient_impact IN ('none','delayed_procedure','rescheduled','escalated_to_other_hospital')),
  surcharge_rupees integer NOT NULL DEFAULT 0,
  resolved boolean NOT NULL DEFAULT false,
  csat_score numeric(3,2)
);

ALTER TABLE off_hours_emergency_calls_r2896 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS off_hours_response_sla_r2896 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_name text NOT NULL,
  contract_month date NOT NULL,
  promised_response_minutes integer NOT NULL,
  promised_resolution_minutes integer NOT NULL,
  promised_calls_per_month integer NOT NULL,
  actual_calls integer NOT NULL,
  breached_calls integer NOT NULL,
  penalty_rupees integer NOT NULL DEFAULT 0,
  retention_risk text NOT NULL CHECK (retention_risk IN ('green','amber','red')),
  contract_value_rupees integer NOT NULL,
  notes text
);

ALTER TABLE off_hours_response_sla_r2896 ENABLE ROW LEVEL SECURITY;

-- Seed off_hours_emergency_calls_r2896 (18 rows)
INSERT INTO off_hours_emergency_calls_r2896 (hospital_name, call_month, call_opened_at, call_closed_at, device_category, severity, engineer_name, engineer_tier, on_call_window, response_minutes, resolution_minutes, patient_impact, surcharge_rupees, resolved, csat_score) VALUES
('Apollo Jubilee', '2026-06-01', '2026-06-03 02:14', '2026-06-03 04:02', 'ventilator', 'p0', 'Ravi K', 'platinum', 'night', 22, 108, 'none', 18000, true, 4.80),
('KIMS Secunderabad', '2026-06-01', '2026-06-05 23:40', '2026-06-06 01:55', 'dialysis', 'p1', 'Suresh P', 'gold', 'night', 35, 135, 'delayed_procedure', 12000, true, 4.40),
('Yashoda Somajiguda', '2026-06-01', '2026-06-09 06:10', '2026-06-09 07:30', 'anesthesia', 'p1', 'Anita R', 'gold', 'dawn', 40, 80, 'none', 9500, true, 4.60),
('Care Banjara', '2026-06-01', '2026-06-12 22:05', '2026-06-12 23:50', 'ct_scanner', 'p2', 'Manoj T', 'silver', 'night', 55, 105, 'rescheduled', 7500, true, 3.90),
('Continental Gachibowli', '2026-06-01', '2026-06-14 03:30', NULL, 'mri', 'p0', 'Ravi K', 'platinum', 'night', 18, NULL, 'escalated_to_other_hospital', 22000, false, NULL),
('Sunshine Paradise', '2026-06-01', '2026-06-15 11:00', '2026-06-15 13:10', 'xray', 'p2', 'Kiran D', 'silver', 'holiday', 65, 130, 'none', 5000, true, 4.10),
('Rainbow Children Banjara', '2026-06-01', '2026-06-17 01:45', '2026-06-17 02:40', 'infant_warmer', 'p0', 'Anita R', 'gold', 'night', 14, 55, 'none', 20000, true, 4.95),
('AIG Gachibowli', '2026-06-01', '2026-06-18 14:20', '2026-06-18 15:30', 'endoscope', 'p1', 'Suresh P', 'gold', 'weekend', 45, 70, 'delayed_procedure', 8000, true, 4.20),
('Krishna Institute', '2026-06-01', '2026-06-20 23:55', '2026-06-21 02:10', 'ventilator', 'p1', 'Manoj T', 'silver', 'night', 38, 135, 'rescheduled', 11000, true, 3.80),
('Apollo Health City', '2026-06-01', '2026-06-22 04:00', '2026-06-22 05:15', 'dialysis', 'p2', 'Ravi K', 'platinum', 'dawn', 28, 75, 'none', 6500, true, 4.70),
('Medicover HiTec City', '2026-06-01', '2026-06-23 21:10', '2026-06-23 23:00', 'ct_scanner', 'p1', 'Kiran D', 'silver', 'night', 50, 110, 'delayed_procedure', 9000, true, 4.00),
('Star Hospitals', '2026-06-01', '2026-06-25 19:30', '2026-06-25 20:55', 'anesthesia', 'p2', 'Anita R', 'gold', 'weekend', 42, 85, 'none', 7000, true, 4.30),
('Citizens Specialty', '2026-06-01', '2026-06-26 02:20', NULL, 'mri', 'p1', 'Suresh P', 'gold', 'night', 60, NULL, 'escalated_to_other_hospital', 14000, false, NULL),
('Olive Hospital', '2026-06-01', '2026-06-27 13:15', '2026-06-27 14:20', 'endoscope', 'p2', 'Manoj T', 'silver', 'weekend', 48, 65, 'none', 5500, true, 4.15),
('Apollo Jubilee', '2026-06-01', '2026-06-28 23:00', '2026-06-29 00:30', 'ventilator', 'p1', 'Ravi K', 'platinum', 'night', 25, 90, 'none', 13000, true, 4.85),
('KIMS Secunderabad', '2026-06-01', '2026-06-29 05:45', '2026-06-29 07:10', 'dialysis', 'p2', 'Kiran D', 'silver', 'dawn', 52, 85, 'delayed_procedure', 6000, true, 3.95),
('Yashoda Somajiguda', '2026-06-01', '2026-06-30 22:30', '2026-07-01 00:45', 'anesthesia', 'p0', 'Anita R', 'gold', 'night', 19, 135, 'none', 21000, true, 4.75),
('Care Banjara', '2026-06-01', '2026-06-30 03:00', '2026-06-30 04:30', 'xray', 'p2', 'Manoj T', 'silver', 'night', 58, 90, 'rescheduled', 5800, true, 3.85);

-- Seed off_hours_response_sla_r2896 (14 rows)
INSERT INTO off_hours_response_sla_r2896 (hospital_name, contract_month, promised_response_minutes, promised_resolution_minutes, promised_calls_per_month, actual_calls, breached_calls, penalty_rupees, retention_risk, contract_value_rupees, notes) VALUES
('Apollo Jubilee', '2026-06-01', 30, 120, 4, 2, 0, 0, 'green', 480000, 'Anchor account — beat SLA on both calls'),
('KIMS Secunderabad', '2026-06-01', 30, 120, 4, 2, 1, 8000, 'amber', 360000, 'Resolution breach — engineer waited for spare'),
('Yashoda Somajiguda', '2026-06-01', 45, 120, 3, 2, 0, 0, 'green', 320000, 'Multi-site chain — renewal Q3'),
('Care Banjara', '2026-06-01', 30, 90, 3, 2, 2, 22000, 'red', 280000, 'Two breaches — escalate before renewal call'),
('Continental Gachibowli', '2026-06-01', 30, 120, 2, 1, 1, 18000, 'red', 250000, 'P0 escalated out — biggest churn risk'),
('Sunshine Paradise', '2026-06-01', 45, 150, 2, 1, 0, 0, 'green', 180000, 'Holiday call met SLA'),
('Rainbow Children Banjara', '2026-06-01', 20, 90, 2, 1, 0, 0, 'green', 220000, 'Pediatric — 14m response on infant warmer'),
('AIG Gachibowli', '2026-06-01', 30, 90, 3, 1, 0, 0, 'green', 340000, 'Strong renewal signal'),
('Krishna Institute', '2026-06-01', 30, 120, 3, 1, 1, 9000, 'amber', 200000, 'Resolution miss — Tier-2 chain'),
('Apollo Health City', '2026-06-01', 30, 120, 4, 1, 0, 0, 'green', 420000, 'Chain anchor — expanding contract'),
('Medicover HiTec City', '2026-06-01', 30, 120, 3, 1, 1, 7500, 'amber', 260000, 'CT scanner breach — pre-empt with replacement plan'),
('Star Hospitals', '2026-06-01', 45, 120, 2, 1, 0, 0, 'green', 190000, 'Weekend call within SLA'),
('Citizens Specialty', '2026-06-01', 30, 120, 2, 1, 1, 14000, 'red', 175000, 'MRI escalated out — at-risk'),
('Olive Hospital', '2026-06-01', 45, 120, 2, 1, 0, 0, 'green', 150000, 'Tier-3 — stable');

-- RPC 1: hospital roll-up
CREATE OR REPLACE FUNCTION fn_r2896_hospital_response_rollup()
RETURNS TABLE (
  hospital_name text,
  total_calls bigint,
  p0_calls bigint,
  avg_response_minutes numeric,
  avg_resolution_minutes numeric,
  surcharge_rupees bigint,
  escalations bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT c.hospital_name,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.severity='p0')::bigint,
    ROUND(AVG(c.response_minutes)::numeric, 1),
    ROUND(AVG(c.resolution_minutes)::numeric, 1),
    COALESCE(SUM(c.surcharge_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE c.patient_impact='escalated_to_other_hospital')::bigint
  FROM off_hours_emergency_calls_r2896 c
  GROUP BY c.hospital_name
  ORDER BY COUNT(*) FILTER (WHERE c.severity='p0') DESC, AVG(c.response_minutes) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_hospital_response_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_hospital_response_rollup() TO authenticated;

-- RPC 2: engineer leaderboard
CREATE OR REPLACE FUNCTION fn_r2896_engineer_oncall_leaderboard()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  calls_handled bigint,
  avg_response_minutes numeric,
  p0_calls bigint,
  avg_csat numeric,
  surcharge_earned_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT c.engineer_name,
    c.engineer_tier,
    COUNT(*)::bigint,
    ROUND(AVG(c.response_minutes)::numeric, 1),
    COUNT(*) FILTER (WHERE c.severity='p0')::bigint,
    ROUND(AVG(c.csat_score)::numeric, 2),
    COALESCE(SUM(c.surcharge_rupees), 0)::bigint
  FROM off_hours_emergency_calls_r2896 c
  WHERE c.engineer_name IS NOT NULL
  GROUP BY c.engineer_name, c.engineer_tier
  ORDER BY AVG(c.response_minutes) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_engineer_oncall_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_engineer_oncall_leaderboard() TO authenticated;

-- RPC 3: SLA breach watchlist
CREATE OR REPLACE FUNCTION fn_r2896_sla_breach_watchlist()
RETURNS TABLE (
  hospital_name text,
  retention_risk text,
  actual_calls integer,
  breached_calls integer,
  penalty_rupees integer,
  contract_value_rupees integer,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT s.hospital_name, s.retention_risk, s.actual_calls, s.breached_calls,
    s.penalty_rupees, s.contract_value_rupees, s.notes
  FROM off_hours_response_sla_r2896 s
  ORDER BY CASE s.retention_risk WHEN 'red' THEN 0 WHEN 'amber' THEN 1 ELSE 2 END,
    s.contract_value_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_sla_breach_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_sla_breach_watchlist() TO authenticated;

-- RPC 4: on-call window distribution
CREATE OR REPLACE FUNCTION fn_r2896_oncall_window_mix()
RETURNS TABLE (
  on_call_window text,
  calls bigint,
  avg_response_minutes numeric,
  surcharge_rupees bigint,
  p0_share_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT c.on_call_window,
    COUNT(*)::bigint,
    ROUND(AVG(c.response_minutes)::numeric, 1),
    COALESCE(SUM(c.surcharge_rupees), 0)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.severity='p0') / NULLIF(COUNT(*),0), 1)
  FROM off_hours_emergency_calls_r2896 c
  GROUP BY c.on_call_window
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_oncall_window_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_oncall_window_mix() TO authenticated;

-- RPC 5: patient impact ledger
CREATE OR REPLACE FUNCTION fn_r2896_patient_impact_ledger()
RETURNS TABLE (
  patient_impact text,
  calls bigint,
  avg_response_minutes numeric,
  surcharge_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT c.patient_impact, COUNT(*)::bigint,
    ROUND(AVG(c.response_minutes)::numeric, 1),
    COALESCE(SUM(c.surcharge_rupees), 0)::bigint
  FROM off_hours_emergency_calls_r2896 c
  GROUP BY c.patient_impact
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_patient_impact_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_patient_impact_ledger() TO authenticated;

-- RPC 6: device category response
CREATE OR REPLACE FUNCTION fn_r2896_device_category_response()
RETURNS TABLE (
  device_category text,
  calls bigint,
  avg_response_minutes numeric,
  avg_resolution_minutes numeric,
  unresolved bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT c.device_category, COUNT(*)::bigint,
    ROUND(AVG(c.response_minutes)::numeric, 1),
    ROUND(AVG(c.resolution_minutes)::numeric, 1),
    COUNT(*) FILTER (WHERE c.resolved=false)::bigint
  FROM off_hours_emergency_calls_r2896 c
  GROUP BY c.device_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_device_category_response() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_device_category_response() TO authenticated;

-- RPC 7: monthly KPI summary
CREATE OR REPLACE FUNCTION fn_r2896_monthly_kpi_summary()
RETURNS TABLE (
  total_calls bigint,
  avg_response_minutes numeric,
  avg_csat numeric,
  total_surcharge_rupees bigint,
  red_accounts bigint,
  arr_at_risk_rupees bigint,
  unresolved_calls bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'not founder'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM off_hours_emergency_calls_r2896)::bigint,
    (SELECT ROUND(AVG(response_minutes)::numeric, 1) FROM off_hours_emergency_calls_r2896),
    (SELECT ROUND(AVG(csat_score)::numeric, 2) FROM off_hours_emergency_calls_r2896),
    (SELECT COALESCE(SUM(surcharge_rupees),0)::bigint FROM off_hours_emergency_calls_r2896),
    (SELECT COUNT(*) FROM off_hours_response_sla_r2896 WHERE retention_risk='red')::bigint,
    (SELECT COALESCE(SUM(contract_value_rupees),0)::bigint FROM off_hours_response_sla_r2896 WHERE retention_risk IN ('red','amber')),
    (SELECT COUNT(*) FROM off_hours_emergency_calls_r2896 WHERE resolved=false)::bigint;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_r2896_monthly_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_r2896_monthly_kpi_summary() TO authenticated;
