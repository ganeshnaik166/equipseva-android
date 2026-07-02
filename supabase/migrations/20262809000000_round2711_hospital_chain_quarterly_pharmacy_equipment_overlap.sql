BEGIN;

-- ============================================================================
-- Round 2711: Hospital Chain Quarterly Pharmacy Equipment Overlap
-- Tracks shared equipment overlap between pharmacy units within chains
-- ============================================================================

DROP TABLE IF EXISTS pharmacy_equipment_overlap_r2711 CASCADE;
DROP TABLE IF EXISTS pharmacy_overlap_integration_r2711 CASCADE;

CREATE TABLE pharmacy_equipment_overlap_r2711 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  pharmacy_unit text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  equipment_category text NOT NULL CHECK (equipment_category IN ('cold_chain','dispensing','compounding','iv_admixture','automation','barcode_scan')),
  shared_units_count int NOT NULL CHECK (shared_units_count >= 0),
  total_units_count int NOT NULL CHECK (total_units_count > 0),
  overlap_value_rupees bigint NOT NULL CHECK (overlap_value_rupees >= 0),
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct BETWEEN 0 AND 100),
  cost_savings_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pharmacy_overlap_integration_r2711 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  pharmacy_unit text NOT NULL,
  integration_type text NOT NULL CHECK (integration_type IN ('inventory_sync','equipment_pool','maintenance_share','procurement_bulk','staff_cross_train')),
  outcome_status text NOT NULL CHECK (outcome_status IN ('planned','active','completed','blocked','expanded')),
  integration_score numeric(5,2) NOT NULL CHECK (integration_score BETWEEN 0 AND 100),
  benefit_realized_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pharmacy_equipment_overlap_r2711 ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_overlap_integration_r2711 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON pharmacy_equipment_overlap_r2711;
CREATE POLICY founder_all ON pharmacy_equipment_overlap_r2711
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON pharmacy_overlap_integration_r2711;
CREATE POLICY founder_all ON pharmacy_overlap_integration_r2711
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Seed data: equipment overlap
INSERT INTO pharmacy_equipment_overlap_r2711 (chain_name, pharmacy_unit, quarter, equipment_category, shared_units_count, total_units_count, overlap_value_rupees, utilization_pct, cost_savings_rupees) VALUES
('Apollo Hospitals', 'Apollo Hyd Pharmacy', 'Q2-2026', 'cold_chain', 8, 12, 4800000, 78.50, 1200000),
('Apollo Hospitals', 'Apollo Chennai Pharmacy', 'Q2-2026', 'dispensing', 6, 10, 3200000, 82.30, 850000),
('Manipal Hospitals', 'Manipal BLR Pharmacy', 'Q2-2026', 'compounding', 4, 8, 5400000, 71.20, 1450000),
('Fortis Healthcare', 'Fortis Gurgaon Pharmacy', 'Q2-2026', 'iv_admixture', 5, 9, 6200000, 88.40, 1680000),
('Max Healthcare', 'Max Saket Pharmacy', 'Q2-2026', 'automation', 7, 11, 8900000, 76.10, 2200000),
('Narayana Health', 'Narayana BLR Pharmacy', 'Q2-2026', 'barcode_scan', 9, 14, 1800000, 91.50, 520000),
('Apollo Hospitals', 'Apollo Hyd Pharmacy', 'Q3-2026', 'cold_chain', 10, 12, 5200000, 84.20, 1450000),
('Manipal Hospitals', 'Manipal Mangalore Pharmacy', 'Q3-2026', 'compounding', 3, 6, 4100000, 68.70, 980000);

-- Seed data: integration outcomes
INSERT INTO pharmacy_overlap_integration_r2711 (chain_name, pharmacy_unit, integration_type, outcome_status, integration_score, benefit_realized_rupees, notes) VALUES
('Apollo Hospitals', 'Apollo Hyd Pharmacy', 'inventory_sync', 'active', 87.50, 2400000, 'Cold chain sync between Hyd + Chennai units saving 18% inventory cost'),
('Manipal Hospitals', 'Manipal BLR Pharmacy', 'equipment_pool', 'expanded', 92.30, 3100000, 'Compounding equipment shared across 4 Manipal pharmacies'),
('Fortis Healthcare', 'Fortis Gurgaon Pharmacy', 'maintenance_share', 'completed', 78.90, 1850000, 'Single AMC contract covering 5 Fortis IV admixture stations'),
('Max Healthcare', 'Max Saket Pharmacy', 'procurement_bulk', 'active', 84.60, 4200000, 'Bulk procurement of automation units negotiated 22% discount'),
('Narayana Health', 'Narayana BLR Pharmacy', 'staff_cross_train', 'planned', 65.40, 0, 'Cross-training scheduled for Q3-2026 barcode scan operators'),
('Apollo Hospitals', 'Apollo Chennai Pharmacy', 'inventory_sync', 'active', 81.20, 1950000, 'Dispensing inventory shared with Bangalore unit'),
('Manipal Hospitals', 'Manipal Mangalore Pharmacy', 'equipment_pool', 'blocked', 42.10, 0, 'Blocked on regulatory approval for inter-state equipment transfer');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2711_kpis();
CREATE FUNCTION founder_r2711_kpis()
RETURNS TABLE(
  total_chains int,
  total_pharmacy_units int,
  total_overlap_value_rupees bigint,
  total_cost_savings_rupees bigint,
  avg_utilization_pct numeric,
  active_integrations int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT chain_name)::int FROM pharmacy_equipment_overlap_r2711),
    (SELECT COUNT(DISTINCT pharmacy_unit)::int FROM pharmacy_equipment_overlap_r2711),
    COALESCE((SELECT SUM(overlap_value_rupees) FROM pharmacy_equipment_overlap_r2711), 0)::bigint,
    COALESCE((SELECT SUM(cost_savings_rupees) FROM pharmacy_equipment_overlap_r2711), 0)::bigint,
    COALESCE((SELECT AVG(utilization_pct) FROM pharmacy_equipment_overlap_r2711), 0)::numeric,
    (SELECT COUNT(*)::int FROM pharmacy_overlap_integration_r2711 WHERE outcome_status IN ('active','expanded'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_by_chain();
CREATE FUNCTION founder_r2711_by_chain()
RETURNS TABLE(
  chain_name text,
  units_count int,
  total_overlap_value_rupees bigint,
  total_savings_rupees bigint,
  avg_utilization_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.chain_name,
    COUNT(DISTINCT e.pharmacy_unit)::int,
    SUM(e.overlap_value_rupees)::bigint,
    SUM(e.cost_savings_rupees)::bigint,
    AVG(e.utilization_pct)::numeric
  FROM pharmacy_equipment_overlap_r2711 e
  GROUP BY e.chain_name
  ORDER BY SUM(e.overlap_value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_by_category();
CREATE FUNCTION founder_r2711_by_category()
RETURNS TABLE(
  equipment_category text,
  shared_units_total int,
  total_units int,
  overlap_value_rupees bigint,
  avg_utilization_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.equipment_category,
    SUM(e.shared_units_count)::int,
    SUM(e.total_units_count)::int,
    SUM(e.overlap_value_rupees)::bigint,
    AVG(e.utilization_pct)::numeric
  FROM pharmacy_equipment_overlap_r2711 e
  GROUP BY e.equipment_category
  ORDER BY SUM(e.overlap_value_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_by_category() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_by_quarter();
CREATE FUNCTION founder_r2711_by_quarter()
RETURNS TABLE(
  quarter text,
  rows_count int,
  overlap_value_rupees bigint,
  savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.quarter,
    COUNT(*)::int,
    SUM(e.overlap_value_rupees)::bigint,
    SUM(e.cost_savings_rupees)::bigint
  FROM pharmacy_equipment_overlap_r2711 e
  GROUP BY e.quarter
  ORDER BY e.quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_by_quarter() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_top_overlaps();
CREATE FUNCTION founder_r2711_top_overlaps()
RETURNS TABLE(
  chain_name text,
  pharmacy_unit text,
  equipment_category text,
  quarter text,
  overlap_value_rupees bigint,
  utilization_pct numeric,
  cost_savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.chain_name,
    e.pharmacy_unit,
    e.equipment_category,
    e.quarter,
    e.overlap_value_rupees,
    e.utilization_pct,
    e.cost_savings_rupees
  FROM pharmacy_equipment_overlap_r2711 e
  ORDER BY e.overlap_value_rupees DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_top_overlaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_top_overlaps() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_integration_outcomes();
CREATE FUNCTION founder_r2711_integration_outcomes()
RETURNS TABLE(
  outcome_status text,
  count_total int,
  benefit_realized_rupees bigint,
  avg_integration_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.outcome_status,
    COUNT(*)::int,
    SUM(i.benefit_realized_rupees)::bigint,
    AVG(i.integration_score)::numeric
  FROM pharmacy_overlap_integration_r2711 i
  GROUP BY i.outcome_status
  ORDER BY SUM(i.benefit_realized_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_integration_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_integration_outcomes() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_integration_rows();
CREATE FUNCTION founder_r2711_integration_rows()
RETURNS TABLE(
  id uuid,
  chain_name text,
  pharmacy_unit text,
  integration_type text,
  outcome_status text,
  integration_score numeric,
  benefit_realized_rupees bigint,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.chain_name, i.pharmacy_unit, i.integration_type,
    i.outcome_status, i.integration_score, i.benefit_realized_rupees, i.notes
  FROM pharmacy_overlap_integration_r2711 i
  ORDER BY i.integration_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_integration_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_integration_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2711_overlap_rows();
CREATE FUNCTION founder_r2711_overlap_rows()
RETURNS TABLE(
  id uuid,
  chain_name text,
  pharmacy_unit text,
  quarter text,
  equipment_category text,
  shared_units_count int,
  total_units_count int,
  overlap_value_rupees bigint,
  utilization_pct numeric,
  cost_savings_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id, e.chain_name, e.pharmacy_unit, e.quarter, e.equipment_category,
    e.shared_units_count, e.total_units_count, e.overlap_value_rupees,
    e.utilization_pct, e.cost_savings_rupees
  FROM pharmacy_equipment_overlap_r2711 e
  ORDER BY e.overlap_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2711_overlap_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2711_overlap_rows() TO authenticated;

COMMIT;
