BEGIN;

-- ============================================================
-- Round r2732: Customer × Monthly × Engineer Recurring Callback
-- ============================================================

-- Table 1: per-customer per-engineer recurring callback monthly stats
CREATE TABLE IF NOT EXISTS customer_engineer_recurring_callback_r2732 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_key       text NOT NULL,
  customer_name   text NOT NULL,
  customer_tier   text NOT NULL CHECK (customer_tier IN ('platinum','gold','silver','bronze')),
  engineer_name   text NOT NULL,
  engineer_tier   text NOT NULL CHECK (engineer_tier IN ('T1','T2','T3','T4')),
  total_visits    integer NOT NULL CHECK (total_visits >= 0),
  callbacks       integer NOT NULL CHECK (callbacks >= 0),
  callback_rate   numeric(5,2) NOT NULL CHECK (callback_rate >= 0 AND callback_rate <= 100),
  recurring_pattern text NOT NULL CHECK (recurring_pattern IN ('same_fault','related_fault','escalating','intermittent','user_error')),
  primary_cause   text NOT NULL CHECK (primary_cause IN ('incomplete_repair','wrong_part','misdiagnosis','training_gap','part_quality','workflow_skip')),
  severity        text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  margin_drag_rupees integer NOT NULL CHECK (margin_drag_rupees >= 0),
  eliminate_action text NOT NULL,
  owner_email     text NOT NULL,
  status          text NOT NULL CHECK (status IN ('open','triaging','fix_in_flight','eliminated','recurrence')),
  detected_on     date NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_engineer_recurring_callback_r2732 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_engineer_recurring_callback_r2732
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_engineer_recurring_callback_r2732
  (month_key, customer_name, customer_tier, engineer_name, engineer_tier,
   total_visits, callbacks, callback_rate, recurring_pattern, primary_cause,
   severity, margin_drag_rupees, eliminate_action, owner_email, status, detected_on)
VALUES
  ('2026-06','Apollo Jubilee Hills','platinum','Ravi Kumar','T1',
   18, 5, 27.78, 'same_fault','incomplete_repair','p1',48500,
   'Mandate teardown photo + supervisor sign-off on autoclave seal jobs','ops@equipseva.in','triaging','2026-06-18'::date),
  ('2026-06','Yashoda Secunderabad','gold','Suresh Patil','T2',
   14, 3, 21.43, 'related_fault','training_gap','p2',31200,
   'Enroll Suresh in centrifuge calibration micro-course; freeze new assigns 14 days','ops@equipseva.in','fix_in_flight','2026-06-17'::date),
  ('2026-06','KIMS Kondapur','gold','Vinay Reddy','T3',
   22, 7, 31.82, 'escalating','wrong_part','p0',92400,
   'Audit Vinay last 30d part picks; route via supervisor for 21 days','ops@equipseva.in','open','2026-06-20'::date),
  ('2026-05','Continental Gachibowli','platinum','Anjali Mehta','T1',
   16, 2, 12.50, 'intermittent','part_quality','p2',18700,
   'Switch BPL ECG probe supplier from Vendor-X to Vendor-Y batch','ops@equipseva.in','eliminated','2026-05-22'::date),
  ('2026-05','Sunshine Paradise','silver','Karthik Iyer','T2',
   12, 4, 33.33, 'same_fault','misdiagnosis','p1',26800,
   'Add 3-question pre-diagnosis checklist for suction units','ops@equipseva.in','recurrence','2026-05-25'::date),
  ('2026-04','Star Begumpet','bronze','Mohammed Imran','T4',
   9, 3, 33.33, 'user_error','workflow_skip','p2',14500,
   'Force in-app SOP video gate for OT-light installs','ops@equipseva.in','eliminated','2026-04-19'::date),
  ('2026-04','Rainbow Banjara','gold','Priya Sharma','T2',
   15, 4, 26.67, 'related_fault','training_gap','p1',33900,
   'Pair Priya with T1 mentor for next 10 paeds-incubator jobs','ops@equipseva.in','fix_in_flight','2026-04-12'::date);


-- Table 2: callback elimination action ledger (interventions + outcomes)
CREATE TABLE IF NOT EXISTS callback_elimination_action_r2732 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ref_month       text NOT NULL,
  customer_name   text NOT NULL,
  engineer_name   text NOT NULL,
  action_type     text NOT NULL CHECK (action_type IN ('training','supervisor_gate','part_swap','sop_update','vendor_swap','process_freeze','mentor_pair')),
  action_summary  text NOT NULL,
  cost_rupees     integer NOT NULL CHECK (cost_rupees >= 0),
  expected_savings_rupees integer NOT NULL CHECK (expected_savings_rupees >= 0),
  roi_ratio       numeric(6,2) NOT NULL CHECK (roi_ratio >= 0),
  outcome         text NOT NULL CHECK (outcome IN ('pending','in_progress','succeeded','failed','partial')),
  callback_before integer NOT NULL CHECK (callback_before >= 0),
  callback_after  integer NOT NULL CHECK (callback_after >= 0),
  delta_pct       numeric(6,2) NOT NULL,
  owner_email     text NOT NULL,
  started_on      date NOT NULL,
  closed_on       date,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE callback_elimination_action_r2732 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON callback_elimination_action_r2732
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO callback_elimination_action_r2732
  (ref_month, customer_name, engineer_name, action_type, action_summary,
   cost_rupees, expected_savings_rupees, roi_ratio, outcome,
   callback_before, callback_after, delta_pct, owner_email, started_on, closed_on)
VALUES
  ('2026-06','Apollo Jubilee Hills','Ravi Kumar','supervisor_gate',
   'Teardown photo + supervisor sign-off on autoclave seal jobs',
   4500, 48500, 10.78, 'in_progress', 5, 2, -60.00,
   'ops@equipseva.in','2026-06-19'::date, NULL),
  ('2026-06','Yashoda Secunderabad','Suresh Patil','training',
   'Centrifuge calibration micro-course (4h) + skills test',
   3200, 31200, 9.75, 'in_progress', 3, 1, -66.67,
   'ops@equipseva.in','2026-06-18'::date, NULL),
  ('2026-05','Continental Gachibowli','Anjali Mehta','vendor_swap',
   'Switch BPL ECG probe supplier Vendor-X to Vendor-Y',
   1200, 18700, 15.58, 'succeeded', 2, 0, -100.00,
   'ops@equipseva.in','2026-05-23'::date,'2026-06-10'::date),
  ('2026-05','Sunshine Paradise','Karthik Iyer','sop_update',
   '3-question pre-diagnosis checklist for suction units',
   800, 26800, 33.50, 'partial', 4, 3, -25.00,
   'ops@equipseva.in','2026-05-26'::date,'2026-06-15'::date),
  ('2026-04','Star Begumpet','Mohammed Imran','sop_update',
   'In-app SOP video gate for OT-light installs',
   1500, 14500, 9.67, 'succeeded', 3, 0, -100.00,
   'ops@equipseva.in','2026-04-20'::date,'2026-05-08'::date),
  ('2026-04','Rainbow Banjara','Priya Sharma','mentor_pair',
   'Pair with T1 mentor for next 10 paeds-incubator jobs',
   2200, 33900, 15.41, 'in_progress', 4, 2, -50.00,
   'ops@equipseva.in','2026-04-13'::date, NULL),
  ('2026-06','KIMS Kondapur','Vinay Reddy','process_freeze',
   'Freeze new high-value assigns 21 days + audit last 30d part picks',
   0, 92400, 0.00, 'pending', 7, 7, 0.00,
   'ops@equipseva.in','2026-06-20'::date, NULL);


-- ============================================================
-- RPCs
-- ============================================================

-- RPC 1: top recurring-callback rows
DROP FUNCTION IF EXISTS rpc_r2732_top_recurring_callback();
CREATE OR REPLACE FUNCTION rpc_r2732_top_recurring_callback()
RETURNS TABLE(
  id uuid, month_key text, customer_name text, customer_tier text,
  engineer_name text, engineer_tier text,
  total_visits integer, callbacks integer, callback_rate numeric,
  recurring_pattern text, primary_cause text, severity text,
  margin_drag_rupees integer, eliminate_action text, status text, detected_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.month_key, t.customer_name, t.customer_tier,
           t.engineer_name, t.engineer_tier,
           t.total_visits, t.callbacks, t.callback_rate,
           t.recurring_pattern, t.primary_cause, t.severity,
           t.margin_drag_rupees, t.eliminate_action, t.status, t.detected_on
    FROM customer_engineer_recurring_callback_r2732 t
    ORDER BY t.callback_rate DESC, t.margin_drag_rupees DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_top_recurring_callback() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_top_recurring_callback() TO authenticated;


-- RPC 2: kpi summary
DROP FUNCTION IF EXISTS rpc_r2732_kpi_summary();
CREATE OR REPLACE FUNCTION rpc_r2732_kpi_summary()
RETURNS TABLE(
  total_rows integer, avg_callback_rate numeric,
  total_margin_drag_rupees bigint, open_rows integer,
  eliminated_rows integer, recurrence_rows integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::integer,
      COALESCE(ROUND(AVG(callback_rate)::numeric, 2), 0),
      COALESCE(SUM(margin_drag_rupees), 0)::bigint,
      COUNT(*) FILTER (WHERE status = 'open')::integer,
      COUNT(*) FILTER (WHERE status = 'eliminated')::integer,
      COUNT(*) FILTER (WHERE status = 'recurrence')::integer
    FROM customer_engineer_recurring_callback_r2732;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_kpi_summary() TO authenticated;


-- RPC 3: by pattern breakdown
DROP FUNCTION IF EXISTS rpc_r2732_by_pattern();
CREATE OR REPLACE FUNCTION rpc_r2732_by_pattern()
RETURNS TABLE(recurring_pattern text, n integer, avg_rate numeric, margin_drag bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.recurring_pattern,
           COUNT(*)::integer,
           ROUND(AVG(t.callback_rate)::numeric, 2),
           SUM(t.margin_drag_rupees)::bigint
    FROM customer_engineer_recurring_callback_r2732 t
    GROUP BY t.recurring_pattern
    ORDER BY SUM(t.margin_drag_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_by_pattern() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_by_pattern() TO authenticated;


-- RPC 4: by primary cause
DROP FUNCTION IF EXISTS rpc_r2732_by_cause();
CREATE OR REPLACE FUNCTION rpc_r2732_by_cause()
RETURNS TABLE(primary_cause text, n integer, avg_rate numeric, margin_drag bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.primary_cause,
           COUNT(*)::integer,
           ROUND(AVG(t.callback_rate)::numeric, 2),
           SUM(t.margin_drag_rupees)::bigint
    FROM customer_engineer_recurring_callback_r2732 t
    GROUP BY t.primary_cause
    ORDER BY SUM(t.margin_drag_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_by_cause() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_by_cause() TO authenticated;


-- RPC 5: by engineer rank
DROP FUNCTION IF EXISTS rpc_r2732_engineer_rank();
CREATE OR REPLACE FUNCTION rpc_r2732_engineer_rank()
RETURNS TABLE(engineer_name text, engineer_tier text, jobs integer, callbacks_sum integer, avg_rate numeric, margin_drag bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.engineer_name, t.engineer_tier,
           SUM(t.total_visits)::integer,
           SUM(t.callbacks)::integer,
           ROUND(AVG(t.callback_rate)::numeric, 2),
           SUM(t.margin_drag_rupees)::bigint
    FROM customer_engineer_recurring_callback_r2732 t
    GROUP BY t.engineer_name, t.engineer_tier
    ORDER BY SUM(t.margin_drag_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_engineer_rank() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_engineer_rank() TO authenticated;


-- RPC 6: actions list
DROP FUNCTION IF EXISTS rpc_r2732_actions_list();
CREATE OR REPLACE FUNCTION rpc_r2732_actions_list()
RETURNS TABLE(
  id uuid, ref_month text, customer_name text, engineer_name text,
  action_type text, action_summary text,
  cost_rupees integer, expected_savings_rupees integer, roi_ratio numeric,
  outcome text, callback_before integer, callback_after integer, delta_pct numeric,
  started_on date, closed_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.ref_month, a.customer_name, a.engineer_name,
           a.action_type, a.action_summary,
           a.cost_rupees, a.expected_savings_rupees, a.roi_ratio,
           a.outcome, a.callback_before, a.callback_after, a.delta_pct,
           a.started_on, a.closed_on
    FROM callback_elimination_action_r2732 a
    ORDER BY a.started_on DESC, a.expected_savings_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_actions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_actions_list() TO authenticated;


-- RPC 7: action ROI summary
DROP FUNCTION IF EXISTS rpc_r2732_action_roi_summary();
CREATE OR REPLACE FUNCTION rpc_r2732_action_roi_summary()
RETURNS TABLE(
  total_actions integer, total_cost_rupees bigint, total_expected_savings_rupees bigint,
  blended_roi numeric, succeeded integer, in_progress integer, pending integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  cost_sum bigint;
  save_sum bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(cost_rupees),0), COALESCE(SUM(expected_savings_rupees),0)
    INTO cost_sum, save_sum
    FROM callback_elimination_action_r2732;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM callback_elimination_action_r2732)::integer,
      cost_sum, save_sum,
      CASE WHEN cost_sum = 0 THEN 0 ELSE ROUND((save_sum::numeric / NULLIF(cost_sum,0))::numeric, 2) END,
      (SELECT COUNT(*) FROM callback_elimination_action_r2732 WHERE outcome = 'succeeded')::integer,
      (SELECT COUNT(*) FROM callback_elimination_action_r2732 WHERE outcome = 'in_progress')::integer,
      (SELECT COUNT(*) FROM callback_elimination_action_r2732 WHERE outcome = 'pending')::integer;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_action_roi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_action_roi_summary() TO authenticated;


-- RPC 8: mark eliminated (mutation)
DROP FUNCTION IF EXISTS rpc_r2732_mark_eliminated(uuid);
CREATE OR REPLACE FUNCTION rpc_r2732_mark_eliminated(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE customer_engineer_recurring_callback_r2732
     SET status = 'eliminated'
   WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2732_mark_eliminated(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2732_mark_eliminated(uuid) TO authenticated;

COMMIT;
