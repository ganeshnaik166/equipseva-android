BEGIN;

-- =========================================================
-- Round 2780: Customer Monthly Equipment Life-Cycle Cost Tracking
-- Two tables tracking equipment LCC (purchase, ops, maintenance, resale)
-- and monthly decision snapshots (keep / refurbish / replace / retire)
-- =========================================================

CREATE TABLE IF NOT EXISTS equipment_lcc_ledger_r2780 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  equipment_name text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','dental','icu','lab','surgery','sterilization')),
  install_date date NOT NULL,
  expected_life_months integer NOT NULL CHECK (expected_life_months BETWEEN 12 AND 240),
  age_months integer NOT NULL CHECK (age_months >= 0),
  purchase_price_rupees numeric(14,2) NOT NULL CHECK (purchase_price_rupees >= 0),
  cumulative_ops_cost_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (cumulative_ops_cost_rupees >= 0),
  cumulative_maintenance_cost_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (cumulative_maintenance_cost_rupees >= 0),
  estimated_resale_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (estimated_resale_rupees >= 0),
  total_lcc_rupees numeric(14,2) NOT NULL DEFAULT 0,
  monthly_lcc_rupees numeric(14,2) NOT NULL DEFAULT 0,
  decision_band text NOT NULL CHECK (decision_band IN ('keep','monitor','refurbish','replace','retire')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_lcc_ledger_r2780 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON equipment_lcc_ledger_r2780;
CREATE POLICY founder_all ON equipment_lcc_ledger_r2780
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS equipment_lcc_monthly_snapshots_r2780 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id uuid NOT NULL REFERENCES equipment_lcc_ledger_r2780(id) ON DELETE CASCADE,
  snapshot_month date NOT NULL,
  ops_cost_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (ops_cost_rupees >= 0),
  maintenance_cost_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (maintenance_cost_rupees >= 0),
  downtime_hours numeric(8,2) NOT NULL DEFAULT 0 CHECK (downtime_hours >= 0),
  revenue_loss_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (revenue_loss_rupees >= 0),
  resale_estimate_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (resale_estimate_rupees >= 0),
  recommended_action text NOT NULL CHECK (recommended_action IN ('keep','monitor','refurbish','replace','retire')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE equipment_lcc_monthly_snapshots_r2780 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON equipment_lcc_monthly_snapshots_r2780;
CREATE POLICY founder_all ON equipment_lcc_monthly_snapshots_r2780
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================
-- Seed: equipment_lcc_ledger_r2780
-- =========================================================

INSERT INTO equipment_lcc_ledger_r2780 (
  customer_org_name, equipment_name, equipment_category, install_date, expected_life_months,
  age_months, purchase_price_rupees, cumulative_ops_cost_rupees, cumulative_maintenance_cost_rupees,
  estimated_resale_rupees, total_lcc_rupees, monthly_lcc_rupees, decision_band
) VALUES
  ('Apollo Banjara', 'GE Revolution CT 64', 'imaging', '2021-04-10'::date, 120, 62,
    18500000.00, 4200000.00, 1850000.00, 7500000.00,
    17050000.00, 275000.00, 'monitor'),
  ('Yashoda Hitec City', 'Siemens MAGNETOM Sola 1.5T', 'imaging', '2019-11-20'::date, 144, 79,
    62500000.00, 9800000.00, 6200000.00, 18500000.00,
    60000000.00, 759493.67, 'refurbish'),
  ('CARE Outpatient Banjara', 'Planmeca ProMax 3D Mid', 'dental', '2022-07-15'::date, 96, 47,
    3850000.00, 220000.00, 145000.00, 1850000.00,
    2365000.00, 50319.15, 'keep'),
  ('Sunshine Secunderabad', 'Drager Evita V500 ICU Vent', 'icu', '2018-02-05'::date, 120, 100,
    1850000.00, 380000.00, 720000.00, 95000.00,
    2855000.00, 28550.00, 'replace'),
  ('KIMS Kondapur', 'Roche Cobas 8000 Chemistry', 'lab', '2020-09-12'::date, 144, 69,
    24500000.00, 5600000.00, 2200000.00, 9800000.00,
    22500000.00, 326086.96, 'monitor'),
  ('Citizens Nallagandla', 'Stryker iSuite Endo Tower', 'surgery', '2017-06-22'::date, 108, 108,
    8400000.00, 2100000.00, 2850000.00, 250000.00,
    13100000.00, 121296.30, 'retire'),
  ('Continental Gachibowli', 'Getinge HS 6606 Steam Sterilizer', 'sterilization', '2023-01-18'::date, 144, 41,
    2150000.00, 185000.00, 92000.00, 1450000.00,
    977000.00, 23829.27, 'keep');

-- =========================================================
-- Seed: equipment_lcc_monthly_snapshots_r2780
-- =========================================================

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 72000.00, 38000.00, 4.5, 95000.00, 7500000.00, 'monitor',
  'CT tube near 80% lifetime; flag for replacement budget'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'GE Revolution CT 64' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 145000.00, 220000.00, 18.0, 380000.00, 18500000.00, 'refurbish',
  'Coil intermittent fault; refurb quote vs trade-in modeled'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Siemens MAGNETOM Sola 1.5T' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 8500.00, 4200.00, 0.0, 0.00, 1850000.00, 'keep',
  'Healthy AMC; zero downtime this month'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Planmeca ProMax 3D Mid' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 12000.00, 48000.00, 12.0, 180000.00, 95000.00, 'replace',
  'Past expected life; failure rate exceeds threshold'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Drager Evita V500 ICU Vent' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 92000.00, 34000.00, 2.5, 65000.00, 9800000.00, 'monitor',
  'Throughput stable; reagent OEM contract renewed'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Roche Cobas 8000 Chemistry' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 18500.00, 92000.00, 38.0, 420000.00, 250000.00, 'retire',
  'End of life. Parts EOL by OEM. Plan retirement Q3'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Stryker iSuite Endo Tower' LIMIT 1;

INSERT INTO equipment_lcc_monthly_snapshots_r2780 (
  ledger_id, snapshot_month, ops_cost_rupees, maintenance_cost_rupees, downtime_hours,
  revenue_loss_rupees, resale_estimate_rupees, recommended_action, note
)
SELECT id, '2026-06-01'::date, 7200.00, 3100.00, 0.0, 0.00, 1450000.00, 'keep',
  'Under warranty; preventive sweep on schedule'
FROM equipment_lcc_ledger_r2780 WHERE equipment_name = 'Getinge HS 6606 Steam Sterilizer' LIMIT 1;

-- =========================================================
-- RPCs
-- =========================================================

DROP FUNCTION IF EXISTS founder_r2780_lcc_kpis();
CREATE OR REPLACE FUNCTION founder_r2780_lcc_kpis()
RETURNS TABLE (
  tracked_assets bigint,
  total_lcc_rupees numeric,
  avg_monthly_lcc_rupees numeric,
  replace_or_retire bigint,
  refurbish bigint,
  healthy_keep bigint,
  est_resale_pool_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(total_lcc_rupees),0)::numeric,
    COALESCE(AVG(monthly_lcc_rupees),0)::numeric,
    COUNT(*) FILTER (WHERE decision_band IN ('replace','retire'))::bigint,
    COUNT(*) FILTER (WHERE decision_band = 'refurbish')::bigint,
    COUNT(*) FILTER (WHERE decision_band IN ('keep','monitor'))::bigint,
    COALESCE(SUM(estimated_resale_rupees),0)::numeric
  FROM equipment_lcc_ledger_r2780;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_lcc_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_lcc_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_list_ledger();
CREATE OR REPLACE FUNCTION founder_r2780_list_ledger()
RETURNS SETOF equipment_lcc_ledger_r2780
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM equipment_lcc_ledger_r2780 ORDER BY total_lcc_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_list_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_list_ledger() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_list_snapshots();
CREATE OR REPLACE FUNCTION founder_r2780_list_snapshots()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  customer_org_name text,
  snapshot_month date,
  ops_cost_rupees numeric,
  maintenance_cost_rupees numeric,
  downtime_hours numeric,
  revenue_loss_rupees numeric,
  resale_estimate_rupees numeric,
  recommended_action text,
  note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, l.equipment_name, l.customer_org_name, s.snapshot_month,
         s.ops_cost_rupees, s.maintenance_cost_rupees, s.downtime_hours,
         s.revenue_loss_rupees, s.resale_estimate_rupees,
         s.recommended_action, s.note
  FROM equipment_lcc_monthly_snapshots_r2780 s
  JOIN equipment_lcc_ledger_r2780 l ON l.id = s.ledger_id
  ORDER BY s.snapshot_month DESC, s.maintenance_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_list_snapshots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_list_snapshots() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_by_category();
CREATE OR REPLACE FUNCTION founder_r2780_by_category()
RETURNS TABLE (
  equipment_category text,
  assets bigint,
  total_lcc_rupees numeric,
  avg_monthly_lcc_rupees numeric,
  replace_or_retire bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.equipment_category,
         COUNT(*)::bigint,
         COALESCE(SUM(l.total_lcc_rupees),0)::numeric,
         COALESCE(AVG(l.monthly_lcc_rupees),0)::numeric,
         COUNT(*) FILTER (WHERE l.decision_band IN ('replace','retire'))::bigint
  FROM equipment_lcc_ledger_r2780 l
  GROUP BY l.equipment_category
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_by_category() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_top_replace_candidates();
CREATE OR REPLACE FUNCTION founder_r2780_top_replace_candidates()
RETURNS TABLE (
  equipment_name text,
  customer_org_name text,
  age_months integer,
  expected_life_months integer,
  monthly_lcc_rupees numeric,
  decision_band text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.equipment_name, l.customer_org_name, l.age_months,
         l.expected_life_months, l.monthly_lcc_rupees, l.decision_band
  FROM equipment_lcc_ledger_r2780 l
  WHERE l.decision_band IN ('replace','retire','refurbish')
  ORDER BY l.monthly_lcc_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_top_replace_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_top_replace_candidates() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_age_distribution();
CREATE OR REPLACE FUNCTION founder_r2780_age_distribution()
RETURNS TABLE (
  age_bucket text,
  assets bigint,
  avg_monthly_lcc_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT bucket,
         COUNT(*)::bigint,
         COALESCE(AVG(monthly_lcc_rupees),0)::numeric
  FROM (
    SELECT
      CASE
        WHEN age_months < 24 THEN '0-2y'
        WHEN age_months < 60 THEN '2-5y'
        WHEN age_months < 96 THEN '5-8y'
        ELSE '8y+'
      END AS bucket,
      monthly_lcc_rupees
    FROM equipment_lcc_ledger_r2780
  ) q
  GROUP BY bucket
  ORDER BY bucket;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_age_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_age_distribution() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_downtime_leaders();
CREATE OR REPLACE FUNCTION founder_r2780_downtime_leaders()
RETURNS TABLE (
  equipment_name text,
  customer_org_name text,
  total_downtime_hours numeric,
  total_revenue_loss_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.equipment_name, l.customer_org_name,
         COALESCE(SUM(s.downtime_hours),0)::numeric,
         COALESCE(SUM(s.revenue_loss_rupees),0)::numeric
  FROM equipment_lcc_ledger_r2780 l
  JOIN equipment_lcc_monthly_snapshots_r2780 s ON s.ledger_id = l.id
  GROUP BY l.equipment_name, l.customer_org_name
  ORDER BY 4 DESC, 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_downtime_leaders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_downtime_leaders() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2780_recompute_decisions();
CREATE OR REPLACE FUNCTION founder_r2780_recompute_decisions()
RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  updated_rows bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE equipment_lcc_ledger_r2780
  SET decision_band = CASE
        WHEN age_months >= expected_life_months THEN 'retire'
        WHEN monthly_lcc_rupees > (purchase_price_rupees / NULLIF(expected_life_months,0)) * 1.5 THEN 'replace'
        WHEN age_months >= (expected_life_months * 0.75) THEN 'refurbish'
        WHEN age_months >= (expected_life_months * 0.5) THEN 'monitor'
        ELSE 'keep'
      END;

  GET DIAGNOSTICS updated_rows = ROW_COUNT;
  RETURN updated_rows;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2780_recompute_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2780_recompute_decisions() TO authenticated;

COMMIT;
