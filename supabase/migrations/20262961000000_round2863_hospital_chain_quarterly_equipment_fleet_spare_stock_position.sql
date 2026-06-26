BEGIN;

-- ============================================================================
-- Round 2863: Hospital Chain Quarterly Equipment Fleet Spare Stock Position
-- chain x asset x spare SKU x on-hand x consumption x reorder x outcome
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: chain_fleet_spare_stock_position_r2863
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chain_fleet_spare_stock_position_r2863 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  chain_name text NOT NULL,
  hospital_count int NOT NULL,
  asset_family text NOT NULL,
  asset_count int NOT NULL,
  spare_sku text NOT NULL,
  spare_sku_name text NOT NULL,
  on_hand_units int NOT NULL,
  reserved_units int NOT NULL,
  available_units int NOT NULL,
  quarterly_consumption_units int NOT NULL,
  consumption_velocity_per_month numeric(8,2) NOT NULL,
  reorder_threshold_units int NOT NULL,
  reorder_qty_units int NOT NULL,
  unit_cost_rupees numeric(12,2) NOT NULL,
  stock_value_rupees numeric(14,2) NOT NULL,
  days_of_cover_estimate int NOT NULL,
  stockout_risk text NOT NULL CHECK (stockout_risk IN ('low','medium','high','critical')),
  outcome_status text NOT NULL CHECK (outcome_status IN ('healthy','reorder_now','overstock','stockout_imminent','obsolete')),
  last_reorder_at timestamptz,
  next_reorder_due_at timestamptz,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_fleet_spare_stock_position_r2863 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON chain_fleet_spare_stock_position_r2863;
CREATE POLICY founder_all ON chain_fleet_spare_stock_position_r2863
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_fleet_spare_stock_position_r2863
  (quarter_label, chain_name, hospital_count, asset_family, asset_count,
   spare_sku, spare_sku_name, on_hand_units, reserved_units, available_units,
   quarterly_consumption_units, consumption_velocity_per_month, reorder_threshold_units,
   reorder_qty_units, unit_cost_rupees, stock_value_rupees, days_of_cover_estimate,
   stockout_risk, outcome_status, last_reorder_at, next_reorder_due_at)
VALUES
  ('Q2-2026','Apollo Group',42,'CT Scanner',58,'SKU-CT-TUBE-A','X-Ray Tube Assembly (CT)',6,2,4,9,3.00,5,8,485000.00,2910000.00,40,'medium','reorder_now','2026-04-10'::date,'2026-06-25'::date),
  ('Q2-2026','Fortis Healthcare',31,'MRI 1.5T',22,'SKU-MRI-COIL-B','Body Coil 1.5T',3,1,2,4,1.33,3,4,720000.00,2160000.00,45,'high','reorder_now','2026-03-22'::date,'2026-06-20'::date),
  ('Q2-2026','Manipal Hospitals',28,'Ultrasound',71,'SKU-US-PROBE-L','Linear Probe 12L',14,3,11,18,6.00,8,12,68000.00,952000.00,55,'low','healthy','2026-05-02'::date,'2026-08-10'::date),
  ('Q2-2026','Max Healthcare',24,'Cath Lab',12,'SKU-CL-FILTER-X','HEPA Filter Set',2,1,1,5,1.67,3,6,42000.00,84000.00,18,'critical','stockout_imminent','2026-02-15'::date,'2026-06-12'::date),
  ('Q2-2026','Narayana Health',36,'Patient Monitor',420,'SKU-PM-BATT-Y','Lithium Battery 11.1V',88,12,76,140,46.67,60,120,4200.00,369600.00,49,'low','healthy','2026-05-18'::date,'2026-07-30'::date),
  ('Q2-2026','Medanta',18,'Linear Accelerator',8,'SKU-LA-KLYS-Z','Klystron Tube',1,0,1,2,0.67,2,2,1850000.00,1850000.00,45,'high','reorder_now','2026-01-30'::date,'2026-06-18'::date),
  ('Q2-2026','Kokilaben',9,'Dialysis Machine',64,'SKU-DM-CART-D','Bicarb Cartridge',240,20,220,650,216.67,300,600,650.00,156000.00,30,'medium','reorder_now','2026-04-25'::date,'2026-06-22'::date),
  ('Q2-2026','Apollo Group',42,'Ventilator',180,'SKU-VENT-FLOW-S','Flow Sensor',12,2,10,28,9.33,15,30,28000.00,336000.00,32,'medium','reorder_now','2026-04-08'::date,'2026-06-30'::date);

-- ---------------------------------------------------------------------------
-- Table 2: chain_fleet_spare_reorder_outcomes_r2863
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chain_fleet_spare_reorder_outcomes_r2863 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  chain_name text NOT NULL,
  spare_sku text NOT NULL,
  reorder_event_at timestamptz NOT NULL,
  qty_ordered int NOT NULL,
  qty_delivered int NOT NULL,
  lead_time_days int NOT NULL,
  supplier_name text NOT NULL,
  unit_cost_rupees numeric(12,2) NOT NULL,
  total_cost_rupees numeric(14,2) NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('delivered_on_time','delivered_late','partial_delivery','cancelled','backordered')),
  downtime_hours_avoided int NOT NULL,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_fleet_spare_reorder_outcomes_r2863 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON chain_fleet_spare_reorder_outcomes_r2863;
CREATE POLICY founder_all ON chain_fleet_spare_reorder_outcomes_r2863
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_fleet_spare_reorder_outcomes_r2863
  (quarter_label, chain_name, spare_sku, reorder_event_at, qty_ordered, qty_delivered,
   lead_time_days, supplier_name, unit_cost_rupees, total_cost_rupees, outcome,
   downtime_hours_avoided, notes)
VALUES
  ('Q2-2026','Apollo Group','SKU-CT-TUBE-A','2026-04-10'::date,8,8,21,'Siemens Healthineers',485000.00,3880000.00,'delivered_on_time',72,'Standard quarterly replenishment'),
  ('Q2-2026','Fortis Healthcare','SKU-MRI-COIL-B','2026-03-22'::date,4,3,35,'GE Healthcare',720000.00,2160000.00,'partial_delivery',48,'1 coil backordered'),
  ('Q2-2026','Manipal Hospitals','SKU-US-PROBE-L','2026-05-02'::date,12,12,14,'Philips India',68000.00,816000.00,'delivered_on_time',24,'Vendor managed inventory'),
  ('Q2-2026','Max Healthcare','SKU-CL-FILTER-X','2026-02-15'::date,6,0,90,'Local Distributor',42000.00,0.00,'backordered',0,'Supply chain disruption'),
  ('Q2-2026','Narayana Health','SKU-PM-BATT-Y','2026-05-18'::date,120,120,7,'Mindray India',4200.00,504000.00,'delivered_on_time',16,'Bulk consolidated order'),
  ('Q2-2026','Medanta','SKU-LA-KLYS-Z','2026-01-30'::date,2,2,60,'Varian Medical',1850000.00,3700000.00,'delivered_late',0,'Customs delay 15d'),
  ('Q2-2026','Kokilaben','SKU-DM-CART-D','2026-04-25'::date,600,600,10,'Fresenius Medical',650.00,390000.00,'delivered_on_time',36,'Monthly subscription delivery');

-- ---------------------------------------------------------------------------
-- RPC 1: founder_chain_fleet_spare_stock_kpis_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_stock_kpis_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_stock_kpis_r2863()
RETURNS TABLE (
  total_chains int,
  total_skus int,
  total_stock_value_rupees numeric,
  critical_risk_count int,
  reorder_now_count int,
  avg_days_of_cover numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_name)::int,
    COUNT(DISTINCT spare_sku)::int,
    COALESCE(SUM(stock_value_rupees),0)::numeric,
    COUNT(*) FILTER (WHERE stockout_risk = 'critical')::int,
    COUNT(*) FILTER (WHERE outcome_status = 'reorder_now')::int,
    COALESCE(AVG(days_of_cover_estimate),0)::numeric
  FROM chain_fleet_spare_stock_position_r2863;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_stock_kpis_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_stock_kpis_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: founder_chain_fleet_spare_stock_list_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_stock_list_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_stock_list_r2863()
RETURNS SETOF chain_fleet_spare_stock_position_r2863
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM chain_fleet_spare_stock_position_r2863
  ORDER BY stock_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_stock_list_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_stock_list_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: founder_chain_fleet_spare_by_chain_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_by_chain_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_by_chain_r2863()
RETURNS TABLE (
  chain_name text,
  sku_count int,
  total_on_hand int,
  total_stock_value_rupees numeric,
  critical_risk_count int,
  avg_days_of_cover numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    COUNT(*)::int,
    SUM(p.on_hand_units)::int,
    SUM(p.stock_value_rupees)::numeric,
    COUNT(*) FILTER (WHERE p.stockout_risk = 'critical')::int,
    AVG(p.days_of_cover_estimate)::numeric
  FROM chain_fleet_spare_stock_position_r2863 p
  GROUP BY p.chain_name
  ORDER BY SUM(p.stock_value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_by_chain_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_by_chain_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: founder_chain_fleet_spare_by_asset_family_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_by_asset_family_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_by_asset_family_r2863()
RETURNS TABLE (
  asset_family text,
  sku_count int,
  total_assets int,
  total_consumption_units int,
  total_stock_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    p.asset_family,
    COUNT(*)::int,
    SUM(p.asset_count)::int,
    SUM(p.quarterly_consumption_units)::int,
    SUM(p.stock_value_rupees)::numeric
  FROM chain_fleet_spare_stock_position_r2863 p
  GROUP BY p.asset_family
  ORDER BY SUM(p.stock_value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_by_asset_family_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_by_asset_family_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: founder_chain_fleet_spare_stockout_risks_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_stockout_risks_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_stockout_risks_r2863()
RETURNS SETOF chain_fleet_spare_stock_position_r2863
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM chain_fleet_spare_stock_position_r2863
  WHERE stockout_risk IN ('high','critical')
     OR outcome_status IN ('reorder_now','stockout_imminent')
  ORDER BY
    CASE stockout_risk
      WHEN 'critical' THEN 0
      WHEN 'high' THEN 1
      WHEN 'medium' THEN 2
      ELSE 3
    END,
    days_of_cover_estimate ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_stockout_risks_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_stockout_risks_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: founder_chain_fleet_spare_reorder_outcomes_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_reorder_outcomes_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_reorder_outcomes_r2863()
RETURNS SETOF chain_fleet_spare_reorder_outcomes_r2863
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM chain_fleet_spare_reorder_outcomes_r2863
  ORDER BY reorder_event_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_reorder_outcomes_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_reorder_outcomes_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: founder_chain_fleet_spare_reorder_outcome_summary_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_reorder_outcome_summary_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_reorder_outcome_summary_r2863()
RETURNS TABLE (
  outcome text,
  event_count int,
  total_qty_ordered int,
  total_qty_delivered int,
  avg_lead_time_days numeric,
  total_cost_rupees numeric,
  total_downtime_hours_avoided int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    o.outcome,
    COUNT(*)::int,
    SUM(o.qty_ordered)::int,
    SUM(o.qty_delivered)::int,
    AVG(o.lead_time_days)::numeric,
    SUM(o.total_cost_rupees)::numeric,
    SUM(o.downtime_hours_avoided)::int
  FROM chain_fleet_spare_reorder_outcomes_r2863 o
  GROUP BY o.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_reorder_outcome_summary_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_reorder_outcome_summary_r2863() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: founder_chain_fleet_spare_supplier_performance_r2863
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_chain_fleet_spare_supplier_performance_r2863();
CREATE OR REPLACE FUNCTION founder_chain_fleet_spare_supplier_performance_r2863()
RETURNS TABLE (
  supplier_name text,
  reorder_count int,
  total_cost_rupees numeric,
  avg_lead_time_days numeric,
  on_time_count int,
  late_count int,
  total_downtime_hours_avoided int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    o.supplier_name,
    COUNT(*)::int,
    SUM(o.total_cost_rupees)::numeric,
    AVG(o.lead_time_days)::numeric,
    COUNT(*) FILTER (WHERE o.outcome = 'delivered_on_time')::int,
    COUNT(*) FILTER (WHERE o.outcome = 'delivered_late')::int,
    SUM(o.downtime_hours_avoided)::int
  FROM chain_fleet_spare_reorder_outcomes_r2863 o
  GROUP BY o.supplier_name
  ORDER BY SUM(o.total_cost_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_fleet_spare_supplier_performance_r2863() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_fleet_spare_supplier_performance_r2863() TO authenticated;

COMMIT;
