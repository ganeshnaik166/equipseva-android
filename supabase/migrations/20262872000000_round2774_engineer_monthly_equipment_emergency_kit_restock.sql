BEGIN;

-- ============================================================================
-- Round 2774: Engineer Monthly Equipment Emergency Kit Restock
-- kit x item x consumption x restock x cost x cadence x verdict
-- ============================================================================

-- Table 1: Engineer emergency kit master roster
CREATE TABLE IF NOT EXISTS engineer_emergency_kits_r2774 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  kit_tier text NOT NULL CHECK (kit_tier IN ('bronze','silver','gold','platinum')),
  kit_capacity_items int NOT NULL CHECK (kit_capacity_items > 0),
  last_audit_date date NOT NULL,
  next_audit_due date NOT NULL,
  current_fill_pct numeric(5,2) NOT NULL CHECK (current_fill_pct >= 0 AND current_fill_pct <= 100),
  monthly_restock_budget_rupees int NOT NULL CHECK (monthly_restock_budget_rupees >= 0),
  restock_cadence_days int NOT NULL CHECK (restock_cadence_days > 0),
  jobs_handled_last_30d int NOT NULL DEFAULT 0,
  stockout_incidents_last_30d int NOT NULL DEFAULT 0,
  verdict text NOT NULL CHECK (verdict IN ('healthy','watch','depleted','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_emergency_kits_r2774 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_emergency_kits_r2774;
CREATE POLICY founder_all ON engineer_emergency_kits_r2774 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_emergency_kits_r2774 (engineer_code, engineer_name, city, kit_tier, kit_capacity_items, last_audit_date, next_audit_due, current_fill_pct, monthly_restock_budget_rupees, restock_cadence_days, jobs_handled_last_30d, stockout_incidents_last_30d, verdict, notes) VALUES
('ENG-HYD-014', 'Ravi Kumar', 'Hyderabad', 'platinum', 48, '2026-06-15'::date, '2026-07-15'::date, 92.5, 18000, 30, 42, 0, 'healthy', 'top performer south zone'),
('ENG-BLR-027', 'Sunita Iyer', 'Bengaluru', 'gold', 36, '2026-06-10'::date, '2026-07-10'::date, 78.0, 14000, 30, 38, 1, 'healthy', 'consistent delivery'),
('ENG-MUM-009', 'Arjun Mehta', 'Mumbai', 'gold', 36, '2026-06-05'::date, '2026-07-05'::date, 54.5, 14000, 30, 51, 3, 'watch', 'high job volume eating kit'),
('ENG-DEL-018', 'Pooja Singh', 'Delhi', 'silver', 24, '2026-05-28'::date, '2026-06-28'::date, 31.0, 9500, 30, 47, 5, 'depleted', 'overdue restock 22 days'),
('ENG-CHN-022', 'Karthik Subramanian', 'Chennai', 'platinum', 48, '2026-06-18'::date, '2026-07-18'::date, 88.0, 18000, 30, 35, 0, 'healthy', 'low consumption month'),
('ENG-PUN-031', 'Neha Deshpande', 'Pune', 'silver', 24, '2026-05-20'::date, '2026-06-20'::date, 12.5, 9500, 30, 39, 9, 'critical', 'restock requisition lost - escalate'),
('ENG-KOL-007', 'Tapan Banerjee', 'Kolkata', 'bronze', 18, '2026-06-12'::date, '2026-07-12'::date, 66.0, 6500, 30, 28, 2, 'watch', 'newer engineer ramping');

-- Table 2: Individual kit item consumption + restock ledger
CREATE TABLE IF NOT EXISTS emergency_kit_item_consumption_r2774 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  item_sku text NOT NULL,
  item_name text NOT NULL,
  item_category text NOT NULL CHECK (item_category IN ('fuse','cable','sensor','battery','solder','filter','gasket','adhesive','tool')),
  par_qty int NOT NULL CHECK (par_qty > 0),
  on_hand_qty int NOT NULL CHECK (on_hand_qty >= 0),
  consumed_last_30d int NOT NULL CHECK (consumed_last_30d >= 0),
  unit_cost_rupees int NOT NULL CHECK (unit_cost_rupees > 0),
  restock_qty_due int NOT NULL CHECK (restock_qty_due >= 0),
  last_restocked_at date NOT NULL,
  reorder_lead_days int NOT NULL CHECK (reorder_lead_days >= 0),
  stockout_flag boolean NOT NULL DEFAULT false,
  consumption_verdict text NOT NULL CHECK (consumption_verdict IN ('normal','elevated','spike','dead_stock')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE emergency_kit_item_consumption_r2774 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON emergency_kit_item_consumption_r2774;
CREATE POLICY founder_all ON emergency_kit_item_consumption_r2774 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO emergency_kit_item_consumption_r2774 (engineer_code, item_sku, item_name, item_category, par_qty, on_hand_qty, consumed_last_30d, unit_cost_rupees, restock_qty_due, last_restocked_at, reorder_lead_days, stockout_flag, consumption_verdict) VALUES
('ENG-HYD-014', 'FUS-10A-CER', '10A ceramic fuse', 'fuse', 20, 18, 6, 45, 2, '2026-06-15'::date, 3, false, 'normal'),
('ENG-HYD-014', 'CBL-XR-2M', 'X-ray HV cable 2m', 'cable', 4, 3, 1, 2800, 1, '2026-06-15'::date, 7, false, 'normal'),
('ENG-BLR-027', 'SNS-O2-MED', 'O2 medical sensor', 'sensor', 6, 4, 3, 1850, 2, '2026-06-10'::date, 5, false, 'elevated'),
('ENG-BLR-027', 'BAT-LI-18650', 'Li-ion 18650 cell', 'battery', 12, 5, 9, 320, 7, '2026-06-10'::date, 2, false, 'spike'),
('ENG-MUM-009', 'SLD-FLX-100G', 'flux solder paste 100g', 'solder', 5, 1, 5, 680, 4, '2026-06-05'::date, 4, true, 'spike'),
('ENG-MUM-009', 'FLT-HEPA-13', 'HEPA H13 filter', 'filter', 8, 2, 7, 1100, 6, '2026-06-05'::date, 6, false, 'spike'),
('ENG-DEL-018', 'GSK-AUTO-RING', 'autoclave gasket ring', 'gasket', 6, 0, 8, 540, 6, '2026-05-28'::date, 5, true, 'spike'),
('ENG-DEL-018', 'ADH-EPOXY-2K', '2K epoxy adhesive', 'adhesive', 4, 1, 4, 420, 3, '2026-05-28'::date, 3, false, 'elevated'),
('ENG-CHN-022', 'TOO-MULTI-DG', 'digital multimeter probe', 'tool', 2, 2, 0, 1450, 0, '2026-06-18'::date, 7, false, 'dead_stock'),
('ENG-CHN-022', 'FUS-5A-GLS', '5A glass fuse', 'fuse', 25, 22, 3, 28, 3, '2026-06-18'::date, 3, false, 'normal'),
('ENG-PUN-031', 'BAT-CR2032', 'CR2032 coin cell', 'battery', 30, 2, 26, 35, 28, '2026-05-20'::date, 2, true, 'spike'),
('ENG-PUN-031', 'CBL-USB-MED', 'medical USB cable', 'cable', 6, 0, 6, 480, 6, '2026-05-20'::date, 4, true, 'spike'),
('ENG-KOL-007', 'SNS-TEMP-PT', 'PT100 temp sensor', 'sensor', 5, 3, 2, 920, 2, '2026-06-12'::date, 5, false, 'normal'),
('ENG-KOL-007', 'SLD-WIRE-1MM', 'solder wire 1mm', 'solder', 3, 2, 1, 240, 1, '2026-06-12'::date, 3, false, 'normal');

-- ============================================================================
-- RPCs (7+ SECDEF, gated by is_founder)
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2774_kit_kpi();
CREATE OR REPLACE FUNCTION founder_r2774_kit_kpi()
RETURNS TABLE (
  total_engineers int,
  critical_kits int,
  depleted_kits int,
  watch_kits int,
  healthy_kits int,
  avg_fill_pct numeric,
  total_stockouts int,
  total_restock_budget_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE verdict = 'critical')::int,
    COUNT(*) FILTER (WHERE verdict = 'depleted')::int,
    COUNT(*) FILTER (WHERE verdict = 'watch')::int,
    COUNT(*) FILTER (WHERE verdict = 'healthy')::int,
    ROUND(AVG(current_fill_pct), 2),
    COALESCE(SUM(stockout_incidents_last_30d), 0)::int,
    COALESCE(SUM(monthly_restock_budget_rupees), 0)::bigint
  FROM engineer_emergency_kits_r2774;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_kit_kpi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_kit_kpi() TO authenticated;

-- RPC 2: Engineer kit roster
DROP FUNCTION IF EXISTS founder_r2774_engineer_roster();
CREATE OR REPLACE FUNCTION founder_r2774_engineer_roster()
RETURNS SETOF engineer_emergency_kits_r2774
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM engineer_emergency_kits_r2774
  ORDER BY
    CASE verdict WHEN 'critical' THEN 1 WHEN 'depleted' THEN 2 WHEN 'watch' THEN 3 ELSE 4 END,
    current_fill_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_engineer_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_engineer_roster() TO authenticated;

-- RPC 3: Stockout offenders
DROP FUNCTION IF EXISTS founder_r2774_stockout_offenders();
CREATE OR REPLACE FUNCTION founder_r2774_stockout_offenders()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  city text,
  stockout_items int,
  total_consumed int,
  worst_item text,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    k.engineer_code,
    k.engineer_name,
    k.city,
    COUNT(*) FILTER (WHERE i.stockout_flag)::int,
    COALESCE(SUM(i.consumed_last_30d), 0)::int,
    (SELECT item_name FROM emergency_kit_item_consumption_r2774 ii
       WHERE ii.engineer_code = k.engineer_code AND ii.stockout_flag
       ORDER BY ii.consumed_last_30d DESC LIMIT 1),
    k.verdict
  FROM engineer_emergency_kits_r2774 k
  LEFT JOIN emergency_kit_item_consumption_r2774 i ON i.engineer_code = k.engineer_code
  GROUP BY k.engineer_code, k.engineer_name, k.city, k.verdict
  HAVING COUNT(*) FILTER (WHERE i.stockout_flag) > 0
  ORDER BY COUNT(*) FILTER (WHERE i.stockout_flag) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_stockout_offenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_stockout_offenders() TO authenticated;

-- RPC 4: Item consumption ledger
DROP FUNCTION IF EXISTS founder_r2774_item_ledger();
CREATE OR REPLACE FUNCTION founder_r2774_item_ledger()
RETURNS SETOF emergency_kit_item_consumption_r2774
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM emergency_kit_item_consumption_r2774
  ORDER BY stockout_flag DESC, consumed_last_30d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_item_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_item_ledger() TO authenticated;

-- RPC 5: Restock cost by category
DROP FUNCTION IF EXISTS founder_r2774_restock_cost_by_category();
CREATE OR REPLACE FUNCTION founder_r2774_restock_cost_by_category()
RETURNS TABLE (
  item_category text,
  items_tracked int,
  total_restock_qty int,
  total_restock_cost_rupees bigint,
  stockout_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.item_category,
    COUNT(*)::int,
    COALESCE(SUM(i.restock_qty_due), 0)::int,
    COALESCE(SUM(i.restock_qty_due * i.unit_cost_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE i.stockout_flag)::int
  FROM emergency_kit_item_consumption_r2774 i
  GROUP BY i.item_category
  ORDER BY SUM(i.restock_qty_due * i.unit_cost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_restock_cost_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_restock_cost_by_category() TO authenticated;

-- RPC 6: Cadence audit (overdue / due soon)
DROP FUNCTION IF EXISTS founder_r2774_cadence_audit();
CREATE OR REPLACE FUNCTION founder_r2774_cadence_audit()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  city text,
  last_audit_date date,
  next_audit_due date,
  days_until_due int,
  cadence_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    k.engineer_code,
    k.engineer_name,
    k.city,
    k.last_audit_date,
    k.next_audit_due,
    (k.next_audit_due - CURRENT_DATE)::int,
    CASE
      WHEN k.next_audit_due < CURRENT_DATE THEN 'overdue'
      WHEN (k.next_audit_due - CURRENT_DATE) <= 7 THEN 'due_soon'
      ELSE 'on_schedule'
    END
  FROM engineer_emergency_kits_r2774 k
  ORDER BY k.next_audit_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_cadence_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_cadence_audit() TO authenticated;

-- RPC 7: Spike consumption items
DROP FUNCTION IF EXISTS founder_r2774_spike_items();
CREATE OR REPLACE FUNCTION founder_r2774_spike_items()
RETURNS TABLE (
  engineer_code text,
  item_sku text,
  item_name text,
  par_qty int,
  on_hand_qty int,
  consumed_last_30d int,
  burn_rate_pct numeric,
  unit_cost_rupees int,
  consumption_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.engineer_code,
    i.item_sku,
    i.item_name,
    i.par_qty,
    i.on_hand_qty,
    i.consumed_last_30d,
    ROUND((i.consumed_last_30d::numeric / NULLIF(i.par_qty, 0)) * 100, 2),
    i.unit_cost_rupees,
    i.consumption_verdict
  FROM emergency_kit_item_consumption_r2774 i
  WHERE i.consumption_verdict IN ('spike','elevated')
  ORDER BY i.consumed_last_30d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_spike_items() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_spike_items() TO authenticated;

-- RPC 8: Verdict mix rollup
DROP FUNCTION IF EXISTS founder_r2774_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2774_verdict_mix()
RETURNS TABLE (
  verdict text,
  engineer_count int,
  avg_fill_pct numeric,
  total_budget_rupees bigint,
  total_jobs int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    k.verdict,
    COUNT(*)::int,
    ROUND(AVG(k.current_fill_pct), 2),
    COALESCE(SUM(k.monthly_restock_budget_rupees), 0)::bigint,
    COALESCE(SUM(k.jobs_handled_last_30d), 0)::int
  FROM engineer_emergency_kits_r2774 k
  GROUP BY k.verdict
  ORDER BY
    CASE k.verdict WHEN 'critical' THEN 1 WHEN 'depleted' THEN 2 WHEN 'watch' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2774_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2774_verdict_mix() TO authenticated;

COMMIT;