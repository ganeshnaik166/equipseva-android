BEGIN;

-- =========================================================
-- Round 2686 — Engineer Monthly Tool Kit Audit
-- =========================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS engineer_tool_kit_audits_r2686 (
  id bigserial PRIMARY KEY,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  region text NOT NULL,
  audit_month date NOT NULL,
  kit_item text NOT NULL,
  item_category text NOT NULL CHECK (item_category IN ('hand_tool','power_tool','diagnostic','calibration','safety','consumable')),
  condition text NOT NULL CHECK (condition IN ('excellent','good','fair','worn','damaged','missing')),
  calibration_status text NOT NULL CHECK (calibration_status IN ('current','due_soon','overdue','not_required','failed')),
  calibration_due_date date,
  missing_flag boolean NOT NULL DEFAULT false,
  replenish_action text NOT NULL CHECK (replenish_action IN ('none','order_new','recalibrate','repair','escalate','training')),
  cost_estimate_rupees integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_tool_kit_audits_r2686 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_tool_kit_audits_r2686;
CREATE POLICY founder_all ON engineer_tool_kit_audits_r2686 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_tool_kit_replenish_orders_r2686 (
  id bigserial PRIMARY KEY,
  engineer_code text NOT NULL,
  kit_item text NOT NULL,
  order_status text NOT NULL CHECK (order_status IN ('queued','approved','shipped','delivered','cancelled')),
  vendor text NOT NULL,
  ordered_at timestamptz NOT NULL DEFAULT now(),
  expected_delivery_date date,
  amount_rupees integer NOT NULL DEFAULT 0,
  priority text NOT NULL CHECK (priority IN ('low','medium','high','critical')),
  notes text
);

ALTER TABLE engineer_tool_kit_replenish_orders_r2686 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_tool_kit_replenish_orders_r2686;
CREATE POLICY founder_all ON engineer_tool_kit_replenish_orders_r2686 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Seeds ----------

INSERT INTO engineer_tool_kit_audits_r2686
  (engineer_code, engineer_name, region, audit_month, kit_item, item_category, condition, calibration_status, calibration_due_date, missing_flag, replenish_action, cost_estimate_rupees, notes)
VALUES
  ('ENG-HYD-001','Ravi Kumar','Hyderabad','2026-06-01','Digital Multimeter','diagnostic','good','due_soon','2026-07-15',false,'recalibrate',1800,'NABL cert due in 3 weeks'),
  ('ENG-HYD-001','Ravi Kumar','Hyderabad','2026-06-01','Torque Wrench 5-25Nm','hand_tool','worn','overdue','2026-04-01',false,'recalibrate',2400,'overdue 2 months'),
  ('ENG-BLR-014','Priya Iyer','Bangalore','2026-06-01','Insulation Tester','diagnostic','excellent','current','2026-11-20',false,'none',0,'all good'),
  ('ENG-BLR-014','Priya Iyer','Bangalore','2026-06-01','Safety Goggles','safety','damaged','not_required',NULL,false,'order_new',450,'lens cracked'),
  ('ENG-CHN-022','Arun Selvam','Chennai','2026-06-01','Stethoscope Calibrator','calibration','fair','failed','2026-05-15',false,'escalate',12000,'failed last NABL test'),
  ('ENG-CHN-022','Arun Selvam','Chennai','2026-06-01','Pulse Oximeter Tester','calibration','good','current','2026-12-01',false,'none',0,'no action'),
  ('ENG-DEL-007','Vikram Singh','Delhi','2026-06-01','Cordless Drill','power_tool','worn','not_required',NULL,false,'repair',900,'battery weak'),
  ('ENG-DEL-007','Vikram Singh','Delhi','2026-06-01','ECG Lead Set','consumable','missing','not_required',NULL,true,'order_new',1600,'lost on field'),
  ('ENG-MUM-031','Neha Joshi','Mumbai','2026-06-01','Pressure Gauge Kit','diagnostic','good','due_soon','2026-08-10',false,'recalibrate',2100,'30 days out');

INSERT INTO engineer_tool_kit_replenish_orders_r2686
  (engineer_code, kit_item, order_status, vendor, ordered_at, expected_delivery_date, amount_rupees, priority, notes)
VALUES
  ('ENG-DEL-007','ECG Lead Set','approved','MedKart','2026-06-10','2026-06-18',1600,'high','field replacement'),
  ('ENG-BLR-014','Safety Goggles','shipped','SafetyFirst','2026-06-11','2026-06-15',450,'medium','overnight'),
  ('ENG-CHN-022','Stethoscope Calibrator','queued','NABL-CalLab','2026-06-12','2026-06-25',12000,'critical','escalated to ops'),
  ('ENG-HYD-001','Torque Wrench Cal','approved','PrecisionCal','2026-06-09','2026-06-20',2400,'high','annual NABL'),
  ('ENG-MUM-031','Pressure Gauge Cal','queued','PrecisionCal','2026-06-12','2026-07-05',2100,'medium','due August');

-- ---------- RPCs ----------

DROP FUNCTION IF EXISTS founder_r2686_kit_overview();
CREATE OR REPLACE FUNCTION founder_r2686_kit_overview()
RETURNS TABLE (
  total_items bigint,
  engineers_audited bigint,
  missing_items bigint,
  overdue_calibration bigint,
  damaged_items bigint,
  total_replenish_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(DISTINCT engineer_code)::bigint,
    count(*) FILTER (WHERE missing_flag)::bigint,
    count(*) FILTER (WHERE calibration_status = 'overdue')::bigint,
    count(*) FILTER (WHERE condition = 'damaged')::bigint,
    coalesce(sum(cost_estimate_rupees),0)::bigint
  FROM engineer_tool_kit_audits_r2686;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_by_engineer();
CREATE OR REPLACE FUNCTION founder_r2686_kit_by_engineer()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  region text,
  items_audited bigint,
  missing_count bigint,
  overdue_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.engineer_code,
    max(a.engineer_name),
    max(a.region),
    count(*)::bigint,
    count(*) FILTER (WHERE a.missing_flag)::bigint,
    count(*) FILTER (WHERE a.calibration_status = 'overdue')::bigint,
    coalesce(sum(a.cost_estimate_rupees),0)::bigint
  FROM engineer_tool_kit_audits_r2686 a
  GROUP BY a.engineer_code
  ORDER BY count(*) FILTER (WHERE a.missing_flag) DESC, count(*) FILTER (WHERE a.calibration_status = 'overdue') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_by_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_by_engineer() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_calibration_status();
CREATE OR REPLACE FUNCTION founder_r2686_kit_calibration_status()
RETURNS TABLE (
  calibration_status text,
  item_count bigint,
  estimated_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.calibration_status, count(*)::bigint, coalesce(sum(a.cost_estimate_rupees),0)::bigint
  FROM engineer_tool_kit_audits_r2686 a
  GROUP BY a.calibration_status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_calibration_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_calibration_status() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_condition_breakdown();
CREATE OR REPLACE FUNCTION founder_r2686_kit_condition_breakdown()
RETURNS TABLE (
  condition text,
  item_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM engineer_tool_kit_audits_r2686;
  RETURN QUERY
  SELECT
    a.condition,
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0 ELSE round(count(*)::numeric * 100.0 / v_total, 1) END
  FROM engineer_tool_kit_audits_r2686 a
  GROUP BY a.condition
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_condition_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_condition_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_missing_items();
CREATE OR REPLACE FUNCTION founder_r2686_kit_missing_items()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  kit_item text,
  item_category text,
  replenish_action text,
  cost_estimate_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_code, a.engineer_name, a.kit_item, a.item_category, a.replenish_action, a.cost_estimate_rupees
  FROM engineer_tool_kit_audits_r2686 a
  WHERE a.missing_flag OR a.condition IN ('damaged','worn')
  ORDER BY a.cost_estimate_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_missing_items() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_missing_items() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_replenish_queue();
CREATE OR REPLACE FUNCTION founder_r2686_kit_replenish_queue()
RETURNS TABLE (
  id bigint,
  engineer_code text,
  kit_item text,
  order_status text,
  vendor text,
  expected_delivery_date date,
  amount_rupees integer,
  priority text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_code, r.kit_item, r.order_status, r.vendor, r.expected_delivery_date, r.amount_rupees, r.priority
  FROM engineer_tool_kit_replenish_orders_r2686 r
  ORDER BY
    CASE r.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    r.expected_delivery_date NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_replenish_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_replenish_queue() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_category_costs();
CREATE OR REPLACE FUNCTION founder_r2686_kit_category_costs()
RETURNS TABLE (
  item_category text,
  audit_count bigint,
  total_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.item_category, count(*)::bigint, coalesce(sum(a.cost_estimate_rupees),0)::bigint
  FROM engineer_tool_kit_audits_r2686 a
  GROUP BY a.item_category
  ORDER BY sum(a.cost_estimate_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_category_costs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_category_costs() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2686_kit_full_audit_list();
CREATE OR REPLACE FUNCTION founder_r2686_kit_full_audit_list()
RETURNS TABLE (
  id bigint,
  engineer_code text,
  engineer_name text,
  region text,
  kit_item text,
  item_category text,
  condition text,
  calibration_status text,
  missing_flag boolean,
  replenish_action text,
  cost_estimate_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_code, a.engineer_name, a.region, a.kit_item, a.item_category, a.condition, a.calibration_status, a.missing_flag, a.replenish_action, a.cost_estimate_rupees
  FROM engineer_tool_kit_audits_r2686 a
  ORDER BY a.engineer_code, a.kit_item;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2686_kit_full_audit_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2686_kit_full_audit_list() TO authenticated;

COMMIT;
