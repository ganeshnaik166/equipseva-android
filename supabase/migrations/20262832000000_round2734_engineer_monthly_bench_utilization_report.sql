BEGIN;

CREATE TABLE IF NOT EXISTS engineer_bench_utilization_r2734 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  region text NOT NULL,
  month_label text NOT NULL,
  available_hours numeric(8,2) NOT NULL,
  billable_hours numeric(8,2) NOT NULL,
  bench_hours numeric(8,2) NOT NULL,
  utilization_pct numeric(5,2) NOT NULL,
  primary_cause text NOT NULL CHECK (primary_cause IN ('low_demand','training','sick_leave','vacation','reassignment','market_slump','onboarding')),
  redeploy_action text NOT NULL CHECK (redeploy_action IN ('shadow_senior','cross_train','region_swap','amc_pool','marketing_field','hold','retrain_cert')),
  redeploy_status text NOT NULL DEFAULT 'pending' CHECK (redeploy_status IN ('pending','planned','executed','cancelled')),
  cost_loss_rupees numeric(12,2) NOT NULL DEFAULT 0,
  report_date date NOT NULL DEFAULT '2026-06-25'::date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_bench_utilization_r2734 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_bench_utilization_r2734;
CREATE POLICY founder_all ON engineer_bench_utilization_r2734 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_bench_redeploy_actions_r2734 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  utilization_id uuid REFERENCES engineer_bench_utilization_r2734(id) ON DELETE CASCADE,
  action_label text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('shadow_senior','cross_train','region_swap','amc_pool','marketing_field','hold','retrain_cert')),
  owner text NOT NULL,
  target_billable_hours numeric(8,2) NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  due_date date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_bench_redeploy_actions_r2734 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_bench_redeploy_actions_r2734;
CREATE POLICY founder_all ON engineer_bench_redeploy_actions_r2734 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_bench_utilization_r2734 (engineer_name, engineer_code, region, month_label, available_hours, billable_hours, bench_hours, utilization_pct, primary_cause, redeploy_action, redeploy_status, cost_loss_rupees) VALUES
('Ravi Kumar', 'ENG-001', 'Hyderabad', '2026-06', 176.00, 92.00, 84.00, 52.27, 'low_demand', 'amc_pool', 'planned', 42000.00),
('Priya Sharma', 'ENG-002', 'Bangalore', '2026-06', 176.00, 158.00, 18.00, 89.77, 'training', 'cross_train', 'executed', 9000.00),
('Amit Patel', 'ENG-003', 'Mumbai', '2026-06', 176.00, 64.00, 112.00, 36.36, 'market_slump', 'region_swap', 'pending', 56000.00),
('Sneha Reddy', 'ENG-004', 'Chennai', '2026-06', 176.00, 120.00, 56.00, 68.18, 'vacation', 'shadow_senior', 'planned', 28000.00),
('Vikram Singh', 'ENG-005', 'Delhi', '2026-06', 176.00, 48.00, 128.00, 27.27, 'onboarding', 'retrain_cert', 'pending', 64000.00),
('Anjali Iyer', 'ENG-006', 'Pune', '2026-06', 176.00, 140.00, 36.00, 79.55, 'reassignment', 'marketing_field', 'executed', 18000.00);

INSERT INTO engineer_bench_redeploy_actions_r2734 (action_label, action_type, owner, target_billable_hours, status, due_date, notes) VALUES
('Move Ravi to AMC pool', 'amc_pool', 'ops_head', 60.00, 'in_progress', '2026-07-10'::date, 'Cover 2 hospital AMC routes'),
('Cross-train Priya on lab analyzers', 'cross_train', 'training_lead', 24.00, 'done', '2026-06-20'::date, 'Cert completed'),
('Swap Amit to Hyderabad', 'region_swap', 'regional_mgr', 80.00, 'open', '2026-07-15'::date, 'Mumbai demand soft'),
('Shadow senior with Sneha', 'shadow_senior', 'senior_eng', 40.00, 'in_progress', '2026-07-05'::date, 'CT-scan onboarding'),
('Retrain Vikram on imaging cert', 'retrain_cert', 'training_lead', 80.00, 'open', '2026-07-20'::date, 'New hire ramp'),
('Anjali field marketing visits', 'marketing_field', 'sales_head', 24.00, 'done', '2026-06-25'::date, 'Closed 3 leads');

DROP FUNCTION IF EXISTS founder_bench_kpis_r2734();
CREATE OR REPLACE FUNCTION founder_bench_kpis_r2734()
RETURNS TABLE(total_engineers bigint, total_bench_hours numeric, total_billable_hours numeric, avg_utilization_pct numeric, total_cost_loss_rupees numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint, COALESCE(sum(bench_hours),0), COALESCE(sum(billable_hours),0),
         COALESCE(round(avg(utilization_pct),2),0), COALESCE(sum(cost_loss_rupees),0)
  FROM engineer_bench_utilization_r2734;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_kpis_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_kpis_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_list_r2734();
CREATE OR REPLACE FUNCTION founder_bench_list_r2734()
RETURNS TABLE(id uuid, engineer_name text, engineer_code text, region text, month_label text, available_hours numeric, billable_hours numeric, bench_hours numeric, utilization_pct numeric, primary_cause text, redeploy_action text, redeploy_status text, cost_loss_rupees numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.engineer_name, u.engineer_code, u.region, u.month_label, u.available_hours, u.billable_hours, u.bench_hours, u.utilization_pct, u.primary_cause, u.redeploy_action, u.redeploy_status, u.cost_loss_rupees
  FROM engineer_bench_utilization_r2734 u
  ORDER BY u.utilization_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_list_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_list_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_by_region_r2734();
CREATE OR REPLACE FUNCTION founder_bench_by_region_r2734()
RETURNS TABLE(region text, engineers bigint, bench_hours numeric, billable_hours numeric, avg_util numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.region, count(*)::bigint, sum(u.bench_hours), sum(u.billable_hours), round(avg(u.utilization_pct),2)
  FROM engineer_bench_utilization_r2734 u
  GROUP BY u.region
  ORDER BY avg(u.utilization_pct) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_by_region_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_by_region_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_by_cause_r2734();
CREATE OR REPLACE FUNCTION founder_bench_by_cause_r2734()
RETURNS TABLE(primary_cause text, engineers bigint, total_bench_hours numeric, total_loss numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.primary_cause, count(*)::bigint, sum(u.bench_hours), sum(u.cost_loss_rupees)
  FROM engineer_bench_utilization_r2734 u
  GROUP BY u.primary_cause
  ORDER BY sum(u.bench_hours) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_by_cause_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_by_cause_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_redeploy_actions_r2734();
CREATE OR REPLACE FUNCTION founder_bench_redeploy_actions_r2734()
RETURNS TABLE(id uuid, action_label text, action_type text, owner text, target_billable_hours numeric, status text, due_date date, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.action_label, a.action_type, a.owner, a.target_billable_hours, a.status, a.due_date, a.notes
  FROM engineer_bench_redeploy_actions_r2734 a
  ORDER BY a.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_redeploy_actions_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_redeploy_actions_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_low_util_r2734();
CREATE OR REPLACE FUNCTION founder_bench_low_util_r2734()
RETURNS TABLE(engineer_name text, engineer_code text, region text, utilization_pct numeric, bench_hours numeric, redeploy_action text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.engineer_name, u.engineer_code, u.region, u.utilization_pct, u.bench_hours, u.redeploy_action
  FROM engineer_bench_utilization_r2734 u
  WHERE u.utilization_pct < 60
  ORDER BY u.utilization_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_low_util_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_low_util_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_action_status_r2734();
CREATE OR REPLACE FUNCTION founder_bench_action_status_r2734()
RETURNS TABLE(status text, action_count bigint, total_target_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, count(*)::bigint, sum(a.target_billable_hours)
  FROM engineer_bench_redeploy_actions_r2734 a
  GROUP BY a.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_action_status_r2734() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_action_status_r2734() TO authenticated;

DROP FUNCTION IF EXISTS founder_bench_mark_executed_r2734(uuid);
CREATE OR REPLACE FUNCTION founder_bench_mark_executed_r2734(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_bench_utilization_r2734 SET redeploy_status = 'executed' WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_bench_mark_executed_r2734(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_bench_mark_executed_r2734(uuid) TO authenticated;

COMMIT;
