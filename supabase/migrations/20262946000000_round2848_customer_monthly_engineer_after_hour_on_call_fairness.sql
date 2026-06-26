BEGIN;

-- ============================================================================
-- Round 2848 — Customer Monthly Engineer After-Hour On-Call Fairness
-- engineer x shift x jobs x pay x overtime x fairness x refine action
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_on_call_shifts_r2848 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  shift_date date NOT NULL,
  shift_window text NOT NULL CHECK (shift_window IN ('weeknight','weekend','holiday','overnight')),
  hours_on_call numeric(5,2) NOT NULL CHECK (hours_on_call >= 0),
  jobs_handled int NOT NULL DEFAULT 0 CHECK (jobs_handled >= 0),
  base_pay_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (base_pay_rupees >= 0),
  overtime_pay_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (overtime_pay_rupees >= 0),
  fairness_score numeric(4,2) NOT NULL DEFAULT 0 CHECK (fairness_score >= 0 AND fairness_score <= 100),
  region text NOT NULL,
  flagged_unfair boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_on_call_shifts_r2848 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_on_call_shifts_r2848;
CREATE POLICY founder_all ON engineer_on_call_shifts_r2848
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_oncall_refine_actions_r2848 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('rebalance','cap_hours','bonus','rotate','coach','escalate')),
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','applied','dismissed','reverted')),
  proposed_by text NOT NULL DEFAULT 'founder',
  applied_at timestamptz,
  delta_rupees numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_oncall_refine_actions_r2848 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_oncall_refine_actions_r2848;
CREATE POLICY founder_all ON engineer_oncall_refine_actions_r2848
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: shifts
INSERT INTO engineer_on_call_shifts_r2848
(engineer_code, engineer_name, shift_date, shift_window, hours_on_call, jobs_handled, base_pay_rupees, overtime_pay_rupees, fairness_score, region, flagged_unfair, notes)
VALUES
('ENG-101','Ravi Kumar','2026-06-01'::date,'weeknight',8.5,3,2400.00,900.00,72.50,'Hyderabad',false,'Standard weeknight rotation'),
('ENG-102','Priya Sharma','2026-06-02'::date,'weekend',12.0,5,3600.00,2400.00,55.00,'Bangalore',true,'Heavy weekend load — needs rebalance'),
('ENG-103','Arjun Reddy','2026-06-03'::date,'holiday',10.0,4,4000.00,3000.00,68.00,'Chennai',false,'Republic Day on-call'),
('ENG-104','Sneha Iyer','2026-06-04'::date,'overnight',9.5,6,2850.00,1800.00,48.00,'Mumbai',true,'Six overnight calls — fatigue risk'),
('ENG-105','Vikram Singh','2026-06-05'::date,'weeknight',7.0,2,2100.00,500.00,81.00,'Delhi',false,'Light shift — fair distribution'),
('ENG-101','Ravi Kumar','2026-06-08'::date,'weekend',11.0,4,3300.00,2100.00,62.00,'Hyderabad',false,'Second weekend in row');

-- Seeds: refine actions
INSERT INTO engineer_oncall_refine_actions_r2848
(engineer_code, action_type, reason, status, proposed_by, delta_rupees)
VALUES
('ENG-102','rebalance','Weekend load 2x peer median','pending','founder',0.00),
('ENG-104','cap_hours','Six overnight calls breach fatigue policy','applied','founder',-1200.00),
('ENG-103','bonus','Holiday coverage above SLA','applied','founder',1500.00),
('ENG-101','rotate','Two consecutive weekends','pending','founder',0.00),
('ENG-105','coach','Strong fairness score — mentor others','pending','founder',0.00),
('ENG-102','escalate','Repeated overload — needs HR review','pending','founder',0.00);

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS r2848_oncall_kpis();
CREATE OR REPLACE FUNCTION r2848_oncall_kpis()
RETURNS TABLE(
  total_shifts bigint,
  total_engineers bigint,
  total_hours numeric,
  total_jobs bigint,
  total_pay numeric,
  total_overtime numeric,
  avg_fairness numeric,
  flagged_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(DISTINCT engineer_code)::bigint,
    COALESCE(SUM(hours_on_call),0)::numeric,
    COALESCE(SUM(jobs_handled),0)::bigint,
    COALESCE(SUM(base_pay_rupees + overtime_pay_rupees),0)::numeric,
    COALESCE(SUM(overtime_pay_rupees),0)::numeric,
    COALESCE(AVG(fairness_score),0)::numeric,
    COUNT(*) FILTER (WHERE flagged_unfair)::bigint
  FROM engineer_on_call_shifts_r2848;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_oncall_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_oncall_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2848_shifts_list();
CREATE OR REPLACE FUNCTION r2848_shifts_list()
RETURNS SETOF engineer_on_call_shifts_r2848
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_on_call_shifts_r2848 ORDER BY shift_date DESC, engineer_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_shifts_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_shifts_list() TO authenticated;

DROP FUNCTION IF EXISTS r2848_engineer_summary();
CREATE OR REPLACE FUNCTION r2848_engineer_summary()
RETURNS TABLE(
  engineer_code text,
  engineer_name text,
  shifts_count bigint,
  total_hours numeric,
  total_jobs bigint,
  total_pay numeric,
  avg_fairness numeric,
  flagged_shifts bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_code,
    MAX(s.engineer_name),
    COUNT(*)::bigint,
    SUM(s.hours_on_call)::numeric,
    SUM(s.jobs_handled)::bigint,
    SUM(s.base_pay_rupees + s.overtime_pay_rupees)::numeric,
    AVG(s.fairness_score)::numeric,
    COUNT(*) FILTER (WHERE s.flagged_unfair)::bigint
  FROM engineer_on_call_shifts_r2848 s
  GROUP BY s.engineer_code
  ORDER BY AVG(s.fairness_score) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_engineer_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_engineer_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2848_shift_window_breakdown();
CREATE OR REPLACE FUNCTION r2848_shift_window_breakdown()
RETURNS TABLE(
  shift_window text,
  shifts bigint,
  total_hours numeric,
  total_jobs bigint,
  total_overtime numeric,
  avg_fairness numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.shift_window,
    COUNT(*)::bigint,
    SUM(s.hours_on_call)::numeric,
    SUM(s.jobs_handled)::bigint,
    SUM(s.overtime_pay_rupees)::numeric,
    AVG(s.fairness_score)::numeric
  FROM engineer_on_call_shifts_r2848 s
  GROUP BY s.shift_window
  ORDER BY SUM(s.hours_on_call) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_shift_window_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_shift_window_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2848_unfair_shifts();
CREATE OR REPLACE FUNCTION r2848_unfair_shifts()
RETURNS SETOF engineer_on_call_shifts_r2848
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_on_call_shifts_r2848
  WHERE flagged_unfair OR fairness_score < 60
  ORDER BY fairness_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_unfair_shifts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_unfair_shifts() TO authenticated;

DROP FUNCTION IF EXISTS r2848_refine_actions_list();
CREATE OR REPLACE FUNCTION r2848_refine_actions_list()
RETURNS SETOF engineer_oncall_refine_actions_r2848
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM engineer_oncall_refine_actions_r2848 ORDER BY created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_refine_actions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_refine_actions_list() TO authenticated;

DROP FUNCTION IF EXISTS r2848_region_load();
CREATE OR REPLACE FUNCTION r2848_region_load()
RETURNS TABLE(
  region text,
  engineers bigint,
  shifts bigint,
  total_hours numeric,
  total_pay numeric,
  flagged bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.region,
    COUNT(DISTINCT s.engineer_code)::bigint,
    COUNT(*)::bigint,
    SUM(s.hours_on_call)::numeric,
    SUM(s.base_pay_rupees + s.overtime_pay_rupees)::numeric,
    COUNT(*) FILTER (WHERE s.flagged_unfair)::bigint
  FROM engineer_on_call_shifts_r2848 s
  GROUP BY s.region
  ORDER BY SUM(s.hours_on_call) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_region_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_region_load() TO authenticated;

DROP FUNCTION IF EXISTS r2848_apply_refine_action(uuid);
CREATE OR REPLACE FUNCTION r2848_apply_refine_action(p_action_id uuid)
RETURNS engineer_oncall_refine_actions_r2848
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_row engineer_oncall_refine_actions_r2848;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_oncall_refine_actions_r2848
    SET status = 'applied', applied_at = now()
    WHERE id = p_action_id
    RETURNING * INTO v_row;
  IF NOT FOUND THEN RAISE EXCEPTION 'action_not_found'; END IF;
  RETURN v_row;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2848_apply_refine_action(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2848_apply_refine_action(uuid) TO authenticated;

COMMIT;
