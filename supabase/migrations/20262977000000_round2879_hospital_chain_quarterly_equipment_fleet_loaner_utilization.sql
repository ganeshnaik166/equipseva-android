BEGIN;

-- =========================================================================
-- Round 2879: Hospital Chain Quarterly Equipment Fleet Loaner Utilization
-- chain × asset × loaner pool × utilization × refill rate × outcome
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: loaner pool inventory per chain × asset class × quarter
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chain_loaner_pool_inventory_r2879 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_chain_code text NOT NULL,
  asset_class text NOT NULL CHECK (asset_class IN ('ventilator','infusion_pump','defibrillator','patient_monitor','syringe_pump','ecg_machine','ultrasound','dialysis')),
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('FY26_Q1','FY26_Q2','FY26_Q3','FY26_Q4','FY27_Q1','FY27_Q2')),
  pool_size_units integer NOT NULL CHECK (pool_size_units >= 0),
  deployed_units integer NOT NULL CHECK (deployed_units >= 0),
  reserve_units integer NOT NULL CHECK (reserve_units >= 0),
  refill_target_units integer NOT NULL CHECK (refill_target_units >= 0),
  refill_actual_units integer NOT NULL CHECK (refill_actual_units >= 0),
  refill_rate_pct numeric(5,2) NOT NULL CHECK (refill_rate_pct >= 0 AND refill_rate_pct <= 200),
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct >= 0 AND utilization_pct <= 200),
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('A','B','C','D','F')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_loaner_pool_inventory_r2879 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_loaner_pool_inventory_r2879;
CREATE POLICY founder_all ON chain_loaner_pool_inventory_r2879
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_loaner_pool_inventory_r2879
  (chain_name, hospital_chain_code, asset_class, fiscal_quarter, pool_size_units, deployed_units, reserve_units, refill_target_units, refill_actual_units, refill_rate_pct, utilization_pct, outcome_grade)
VALUES
  ('Apollo Hospitals', 'APOLLO', 'ventilator', 'FY26_Q3', 240, 198, 42, 30, 28, 93.33, 82.50, 'A'),
  ('Manipal Health', 'MANIPAL', 'infusion_pump', 'FY26_Q3', 420, 380, 40, 50, 47, 94.00, 90.48, 'A'),
  ('Fortis Healthcare', 'FORTIS', 'defibrillator', 'FY26_Q3', 96, 71, 25, 12, 8, 66.67, 73.96, 'C'),
  ('Max Healthcare', 'MAX', 'patient_monitor', 'FY26_Q3', 310, 264, 46, 38, 35, 92.11, 85.16, 'B'),
  ('Narayana Health', 'NARAYANA', 'syringe_pump', 'FY26_Q3', 188, 152, 36, 22, 14, 63.64, 80.85, 'C'),
  ('Aster DM Healthcare', 'ASTER', 'ecg_machine', 'FY26_Q3', 64, 41, 23, 8, 4, 50.00, 64.06, 'D'),
  ('KIMS Hospitals', 'KIMS', 'ultrasound', 'FY26_Q2', 28, 22, 6, 4, 4, 100.00, 78.57, 'B'),
  ('Yashoda Hospitals', 'YASHODA', 'dialysis', 'FY26_Q3', 54, 49, 5, 7, 6, 85.71, 90.74, 'A');

-- -------------------------------------------------------------------------
-- Table 2: per-asset utilization & outcome events
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chain_loaner_utilization_events_r2879 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_chain_code text NOT NULL,
  asset_class text NOT NULL CHECK (asset_class IN ('ventilator','infusion_pump','defibrillator','patient_monitor','syringe_pump','ecg_machine','ultrasound','dialysis')),
  asset_serial text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('deploy','retrieve','swap','refill','breakdown','idle_alert','contract_renew')),
  utilization_hours numeric(8,2) NOT NULL CHECK (utilization_hours >= 0),
  uptime_pct numeric(5,2) NOT NULL CHECK (uptime_pct >= 0 AND uptime_pct <= 100),
  outcome text NOT NULL CHECK (outcome IN ('on_track','watch','intervene','escalate','closed_ok','closed_loss')),
  revenue_impact_rupees numeric(14,2) NOT NULL DEFAULT 0,
  event_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_loaner_utilization_events_r2879 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_loaner_utilization_events_r2879;
CREATE POLICY founder_all ON chain_loaner_utilization_events_r2879
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_loaner_utilization_events_r2879
  (hospital_chain_code, asset_class, asset_serial, event_type, utilization_hours, uptime_pct, outcome, revenue_impact_rupees, event_date)
VALUES
  ('APOLLO', 'ventilator', 'VENT-APL-0042', 'deploy', 612.50, 98.20, 'on_track', 184500.00, '2026-05-12'::date),
  ('MANIPAL', 'infusion_pump', 'IP-MNP-1188', 'refill', 0.00, 100.00, 'closed_ok', 0.00, '2026-05-18'::date),
  ('FORTIS', 'defibrillator', 'DEF-FRT-0207', 'breakdown', 0.00, 0.00, 'escalate', -82000.00, '2026-05-22'::date),
  ('MAX', 'patient_monitor', 'PM-MAX-3301', 'deploy', 488.75, 96.40, 'on_track', 142800.00, '2026-05-25'::date),
  ('NARAYANA', 'syringe_pump', 'SP-NRY-0914', 'idle_alert', 12.00, 22.10, 'watch', -14500.00, '2026-05-28'::date),
  ('ASTER', 'ecg_machine', 'ECG-ASR-0156', 'swap', 308.00, 78.20, 'intervene', 24500.00, '2026-06-02'::date),
  ('YASHODA', 'dialysis', 'DL-YSH-0078', 'contract_renew', 720.00, 99.10, 'closed_ok', 412000.00, '2026-06-08'::date),
  ('KIMS', 'ultrasound', 'US-KMS-0033', 'deploy', 402.00, 94.80, 'on_track', 128400.00, '2026-06-12'::date);

-- =========================================================================
-- RPCs
-- =========================================================================

-- RPC 1: KPI summary
DROP FUNCTION IF EXISTS founder_r2879_kpi_summary();
CREATE FUNCTION founder_r2879_kpi_summary()
RETURNS TABLE (
  total_chains integer,
  total_pool_units bigint,
  deployed_units bigint,
  avg_utilization_pct numeric,
  avg_refill_rate_pct numeric,
  chains_grade_a integer,
  chains_grade_d_or_f integer,
  total_revenue_impact_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT hospital_chain_code)::int FROM chain_loaner_pool_inventory_r2879),
    COALESCE(SUM(pool_size_units), 0)::bigint,
    COALESCE(SUM(deployed_units), 0)::bigint,
    COALESCE(ROUND(AVG(utilization_pct), 2), 0),
    COALESCE(ROUND(AVG(refill_rate_pct), 2), 0),
    COALESCE(SUM(CASE WHEN outcome_grade = 'A' THEN 1 ELSE 0 END), 0)::int,
    COALESCE(SUM(CASE WHEN outcome_grade IN ('D','F') THEN 1 ELSE 0 END), 0)::int,
    COALESCE((SELECT SUM(revenue_impact_rupees) FROM chain_loaner_utilization_events_r2879), 0)
  FROM chain_loaner_pool_inventory_r2879;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_kpi_summary() TO authenticated;

-- RPC 2: chain × quarter rollup
DROP FUNCTION IF EXISTS founder_r2879_chain_rollup();
CREATE FUNCTION founder_r2879_chain_rollup()
RETURNS TABLE (
  chain_name text,
  hospital_chain_code text,
  asset_classes_covered integer,
  pool_units bigint,
  deployed_units bigint,
  avg_utilization_pct numeric,
  avg_refill_rate_pct numeric,
  best_grade text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    p.hospital_chain_code,
    COUNT(DISTINCT p.asset_class)::int,
    SUM(p.pool_size_units)::bigint,
    SUM(p.deployed_units)::bigint,
    ROUND(AVG(p.utilization_pct), 2),
    ROUND(AVG(p.refill_rate_pct), 2),
    MIN(p.outcome_grade)
  FROM chain_loaner_pool_inventory_r2879 p
  GROUP BY p.chain_name, p.hospital_chain_code
  ORDER BY AVG(p.utilization_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_chain_rollup() TO authenticated;

-- RPC 3: asset class breakdown
DROP FUNCTION IF EXISTS founder_r2879_asset_class_breakdown();
CREATE FUNCTION founder_r2879_asset_class_breakdown()
RETURNS TABLE (
  asset_class text,
  pool_units bigint,
  deployed_units bigint,
  reserve_units bigint,
  avg_utilization_pct numeric,
  avg_refill_rate_pct numeric,
  chains_using integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.asset_class,
    SUM(p.pool_size_units)::bigint,
    SUM(p.deployed_units)::bigint,
    SUM(p.reserve_units)::bigint,
    ROUND(AVG(p.utilization_pct), 2),
    ROUND(AVG(p.refill_rate_pct), 2),
    COUNT(DISTINCT p.hospital_chain_code)::int
  FROM chain_loaner_pool_inventory_r2879 p
  GROUP BY p.asset_class
  ORDER BY SUM(p.deployed_units) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_asset_class_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_asset_class_breakdown() TO authenticated;

-- RPC 4: refill rate watchlist (refill < 80%)
DROP FUNCTION IF EXISTS founder_r2879_refill_watchlist();
CREATE FUNCTION founder_r2879_refill_watchlist()
RETURNS TABLE (
  chain_name text,
  hospital_chain_code text,
  asset_class text,
  fiscal_quarter text,
  refill_target_units integer,
  refill_actual_units integer,
  refill_gap_units integer,
  refill_rate_pct numeric,
  outcome_grade text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    p.hospital_chain_code,
    p.asset_class,
    p.fiscal_quarter,
    p.refill_target_units,
    p.refill_actual_units,
    (p.refill_target_units - p.refill_actual_units),
    p.refill_rate_pct,
    p.outcome_grade
  FROM chain_loaner_pool_inventory_r2879 p
  WHERE p.refill_rate_pct < 80
  ORDER BY p.refill_rate_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_refill_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_refill_watchlist() TO authenticated;

-- RPC 5: high utilization (>= 85%) leaders
DROP FUNCTION IF EXISTS founder_r2879_utilization_leaders();
CREATE FUNCTION founder_r2879_utilization_leaders()
RETURNS TABLE (
  chain_name text,
  hospital_chain_code text,
  asset_class text,
  pool_size_units integer,
  deployed_units integer,
  utilization_pct numeric,
  outcome_grade text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_name,
    p.hospital_chain_code,
    p.asset_class,
    p.pool_size_units,
    p.deployed_units,
    p.utilization_pct,
    p.outcome_grade
  FROM chain_loaner_pool_inventory_r2879 p
  WHERE p.utilization_pct >= 85
  ORDER BY p.utilization_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_utilization_leaders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_utilization_leaders() TO authenticated;

-- RPC 6: recent utilization events
DROP FUNCTION IF EXISTS founder_r2879_recent_events(integer);
CREATE FUNCTION founder_r2879_recent_events(p_limit integer DEFAULT 20)
RETURNS TABLE (
  event_date date,
  hospital_chain_code text,
  asset_class text,
  asset_serial text,
  event_type text,
  utilization_hours numeric,
  uptime_pct numeric,
  outcome text,
  revenue_impact_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.event_date,
    e.hospital_chain_code,
    e.asset_class,
    e.asset_serial,
    e.event_type,
    e.utilization_hours,
    e.uptime_pct,
    e.outcome,
    e.revenue_impact_rupees
  FROM chain_loaner_utilization_events_r2879 e
  ORDER BY e.event_date DESC, e.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_recent_events(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_recent_events(integer) TO authenticated;

-- RPC 7: outcome distribution
DROP FUNCTION IF EXISTS founder_r2879_outcome_distribution();
CREATE FUNCTION founder_r2879_outcome_distribution()
RETURNS TABLE (
  outcome text,
  event_count bigint,
  total_revenue_impact_rupees numeric,
  avg_uptime_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.outcome,
    COUNT(*)::bigint,
    COALESCE(SUM(e.revenue_impact_rupees), 0),
    COALESCE(ROUND(AVG(e.uptime_pct), 2), 0)
  FROM chain_loaner_utilization_events_r2879 e
  GROUP BY e.outcome
  ORDER BY SUM(e.revenue_impact_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_outcome_distribution() TO authenticated;

-- RPC 8: quarter-over-quarter trend
DROP FUNCTION IF EXISTS founder_r2879_quarter_trend();
CREATE FUNCTION founder_r2879_quarter_trend()
RETURNS TABLE (
  fiscal_quarter text,
  total_pool_units bigint,
  total_deployed_units bigint,
  avg_utilization_pct numeric,
  avg_refill_rate_pct numeric,
  records integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.fiscal_quarter,
    SUM(p.pool_size_units)::bigint,
    SUM(p.deployed_units)::bigint,
    ROUND(AVG(p.utilization_pct), 2),
    ROUND(AVG(p.refill_rate_pct), 2),
    COUNT(*)::int
  FROM chain_loaner_pool_inventory_r2879 p
  GROUP BY p.fiscal_quarter
  ORDER BY p.fiscal_quarter ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2879_quarter_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2879_quarter_trend() TO authenticated;

COMMIT;
