BEGIN;

-- ============================================================================
-- Round 2807: Hospital Chain Quarterly Equipment Installed Capacity Utilization
-- chain × asset × theoretical capacity × actual × utilization × growth headroom
-- ============================================================================

-- ---------- Table 1: chain quarterly capacity snapshots ----------
CREATE TABLE IF NOT EXISTS chain_quarterly_capacity_snapshots_r2807 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  fiscal_quarter text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','dialysis','ventilator','ot_table','cath_lab','endoscopy','infusion_pump')),
  installed_units int NOT NULL CHECK (installed_units >= 0),
  theoretical_hours_per_quarter numeric(10,2) NOT NULL CHECK (theoretical_hours_per_quarter > 0),
  actual_hours_logged numeric(10,2) NOT NULL CHECK (actual_hours_logged >= 0),
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct >= 0),
  downtime_hours numeric(10,2) NOT NULL DEFAULT 0 CHECK (downtime_hours >= 0),
  revenue_per_hour_rupees numeric(12,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_quarterly_capacity_snapshots_r2807 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_quarterly_capacity_snapshots_r2807;
CREATE POLICY founder_all ON chain_quarterly_capacity_snapshots_r2807
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Table 2: chain headroom growth opportunities ----------
CREATE TABLE IF NOT EXISTS chain_capacity_headroom_opportunities_r2807 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','dialysis','ventilator','ot_table','cath_lab','endoscopy','infusion_pump')),
  headroom_pct numeric(5,2) NOT NULL CHECK (headroom_pct >= 0),
  unrealized_revenue_rupees numeric(14,2) NOT NULL CHECK (unrealized_revenue_rupees >= 0),
  recommended_action text NOT NULL CHECK (recommended_action IN ('add_shift','add_unit','reduce_downtime','reschedule_amc','no_action')),
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  expected_uplift_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','accepted','rejected','closed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_capacity_headroom_opportunities_r2807 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_capacity_headroom_opportunities_r2807;
CREATE POLICY founder_all ON chain_capacity_headroom_opportunities_r2807
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Seed Table 1 ----------
INSERT INTO chain_quarterly_capacity_snapshots_r2807
  (chain_name, fiscal_quarter, asset_category, installed_units, theoretical_hours_per_quarter, actual_hours_logged, utilization_pct, downtime_hours, revenue_per_hour_rupees)
VALUES
  ('Apollo South', 'Q1-FY27', 'imaging', 14, 30240.00, 21168.00, 70.00, 720.00, 8500.00),
  ('Apollo South', 'Q1-FY27', 'dialysis', 22, 47520.00, 38016.00, 80.00, 480.00, 2400.00),
  ('Manipal Bangalore', 'Q1-FY27', 'cath_lab', 6, 12960.00, 9072.00, 70.00, 360.00, 18500.00),
  ('Fortis Mumbai', 'Q1-FY27', 'ventilator', 38, 82080.00, 65664.00, 80.00, 900.00, 1200.00),
  ('Narayana Hyderabad', 'Q1-FY27', 'ot_table', 12, 25920.00, 15552.00, 60.00, 1080.00, 14000.00),
  ('Max Delhi', 'Q1-FY27', 'endoscopy', 9, 19440.00, 13608.00, 70.00, 540.00, 6500.00),
  ('Aster Kerala', 'Q1-FY27', 'infusion_pump', 120, 259200.00, 233280.00, 90.00, 360.00, 180.00);

-- ---------- Seed Table 2 ----------
INSERT INTO chain_capacity_headroom_opportunities_r2807
  (chain_name, asset_category, headroom_pct, unrealized_revenue_rupees, recommended_action, priority, expected_uplift_pct, status)
VALUES
  ('Narayana Hyderabad', 'ot_table', 40.00, 14515200.00, 'add_shift', 'p0', 25.00, 'open'),
  ('Apollo South', 'imaging', 30.00, 7711200.00, 'reduce_downtime', 'p1', 15.00, 'in_review'),
  ('Manipal Bangalore', 'cath_lab', 30.00, 7193400.00, 'add_unit', 'p1', 20.00, 'open'),
  ('Max Delhi', 'endoscopy', 30.00, 3790800.00, 'reschedule_amc', 'p2', 12.00, 'open'),
  ('Fortis Mumbai', 'ventilator', 20.00, 19699200.00, 'add_shift', 'p1', 10.00, 'accepted'),
  ('Apollo South', 'dialysis', 20.00, 22809600.00, 'add_unit', 'p0', 18.00, 'open');

-- ============================================================================
-- RPCs (all SECURITY DEFINER, gated by is_founder)
-- ============================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2807_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2807_kpi_summary()
RETURNS TABLE (
  total_chains int,
  total_installed_units bigint,
  avg_utilization_pct numeric,
  total_unrealized_revenue_rupees numeric,
  open_opportunities bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(DISTINCT chain_name)::int FROM chain_quarterly_capacity_snapshots_r2807),
      (SELECT COALESCE(SUM(installed_units),0)::bigint FROM chain_quarterly_capacity_snapshots_r2807),
      (SELECT COALESCE(AVG(utilization_pct),0)::numeric FROM chain_quarterly_capacity_snapshots_r2807),
      (SELECT COALESCE(SUM(unrealized_revenue_rupees),0)::numeric FROM chain_capacity_headroom_opportunities_r2807),
      (SELECT COUNT(*)::bigint FROM chain_capacity_headroom_opportunities_r2807 WHERE status = 'open');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_kpi_summary() TO authenticated;

-- RPC 2: snapshots list
DROP FUNCTION IF EXISTS founder_r2807_list_snapshots();
CREATE OR REPLACE FUNCTION founder_r2807_list_snapshots()
RETURNS TABLE (
  id uuid,
  chain_name text,
  fiscal_quarter text,
  asset_category text,
  installed_units int,
  theoretical_hours_per_quarter numeric,
  actual_hours_logged numeric,
  utilization_pct numeric,
  downtime_hours numeric,
  revenue_per_hour_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.fiscal_quarter, s.asset_category, s.installed_units,
           s.theoretical_hours_per_quarter, s.actual_hours_logged, s.utilization_pct,
           s.downtime_hours, s.revenue_per_hour_rupees
    FROM chain_quarterly_capacity_snapshots_r2807 s
    ORDER BY s.utilization_pct ASC, s.chain_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_list_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_list_snapshots() TO authenticated;

-- RPC 3: chain rollup
DROP FUNCTION IF EXISTS founder_r2807_chain_rollup();
CREATE OR REPLACE FUNCTION founder_r2807_chain_rollup()
RETURNS TABLE (
  chain_name text,
  asset_categories bigint,
  total_units bigint,
  avg_utilization_pct numeric,
  total_downtime_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name,
           COUNT(DISTINCT s.asset_category)::bigint,
           SUM(s.installed_units)::bigint,
           AVG(s.utilization_pct)::numeric,
           SUM(s.downtime_hours)::numeric
    FROM chain_quarterly_capacity_snapshots_r2807 s
    GROUP BY s.chain_name
    ORDER BY AVG(s.utilization_pct) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_chain_rollup() TO authenticated;

-- RPC 4: asset category rollup
DROP FUNCTION IF EXISTS founder_r2807_asset_rollup();
CREATE OR REPLACE FUNCTION founder_r2807_asset_rollup()
RETURNS TABLE (
  asset_category text,
  chains_count bigint,
  total_units bigint,
  avg_utilization_pct numeric,
  total_actual_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.asset_category,
           COUNT(DISTINCT s.chain_name)::bigint,
           SUM(s.installed_units)::bigint,
           AVG(s.utilization_pct)::numeric,
           SUM(s.actual_hours_logged)::numeric
    FROM chain_quarterly_capacity_snapshots_r2807 s
    GROUP BY s.asset_category
    ORDER BY s.asset_category;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_asset_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_asset_rollup() TO authenticated;

-- RPC 5: headroom opportunities
DROP FUNCTION IF EXISTS founder_r2807_list_opportunities();
CREATE OR REPLACE FUNCTION founder_r2807_list_opportunities()
RETURNS TABLE (
  id uuid,
  chain_name text,
  asset_category text,
  headroom_pct numeric,
  unrealized_revenue_rupees numeric,
  recommended_action text,
  priority text,
  expected_uplift_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.chain_name, o.asset_category, o.headroom_pct, o.unrealized_revenue_rupees,
           o.recommended_action, o.priority, o.expected_uplift_pct, o.status
    FROM chain_capacity_headroom_opportunities_r2807 o
    ORDER BY o.priority, o.unrealized_revenue_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_list_opportunities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_list_opportunities() TO authenticated;

-- RPC 6: top underutilized
DROP FUNCTION IF EXISTS founder_r2807_top_underutilized();
CREATE OR REPLACE FUNCTION founder_r2807_top_underutilized()
RETURNS TABLE (
  chain_name text,
  asset_category text,
  utilization_pct numeric,
  installed_units int,
  headroom_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.asset_category, s.utilization_pct, s.installed_units,
           (100 - s.utilization_pct)::numeric AS headroom_pct
    FROM chain_quarterly_capacity_snapshots_r2807 s
    WHERE s.utilization_pct < 80
    ORDER BY s.utilization_pct ASC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_top_underutilized() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_top_underutilized() TO authenticated;

-- RPC 7: priority action distribution
DROP FUNCTION IF EXISTS founder_r2807_action_distribution();
CREATE OR REPLACE FUNCTION founder_r2807_action_distribution()
RETURNS TABLE (
  recommended_action text,
  opportunities bigint,
  total_unrealized_revenue numeric,
  avg_expected_uplift_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.recommended_action,
           COUNT(*)::bigint,
           SUM(o.unrealized_revenue_rupees)::numeric,
           AVG(o.expected_uplift_pct)::numeric
    FROM chain_capacity_headroom_opportunities_r2807 o
    GROUP BY o.recommended_action
    ORDER BY SUM(o.unrealized_revenue_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_action_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_action_distribution() TO authenticated;

-- RPC 8: mark opportunity accepted
DROP FUNCTION IF EXISTS founder_r2807_accept_opportunity(uuid);
CREATE OR REPLACE FUNCTION founder_r2807_accept_opportunity(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE chain_capacity_headroom_opportunities_r2807
    SET status = 'accepted'
    WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2807_accept_opportunity(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2807_accept_opportunity(uuid) TO authenticated;

COMMIT;
