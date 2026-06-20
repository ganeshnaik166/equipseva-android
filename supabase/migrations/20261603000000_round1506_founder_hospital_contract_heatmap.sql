BEGIN;

-- ============================================================================
-- r1506: Founder Hospital Contract Heatmap
-- Plot every active AMC by hospital x equipment-category x contract value
-- Surface concentration risk + diversification gaps
-- ============================================================================

-- Snapshot table: per-hospital aggregated contract footprint
CREATE TABLE IF NOT EXISTS founder_hospital_contract_heatmap_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at timestamptz NOT NULL DEFAULT now(),
  hospital_org_id uuid NOT NULL,
  hospital_name text,
  hospital_city text,
  equipment_category text NOT NULL,
  active_contract_count integer NOT NULL DEFAULT 0,
  total_monthly_value_rupees bigint NOT NULL DEFAULT 0,
  total_annualized_value_rupees bigint NOT NULL DEFAULT 0,
  tier_mix jsonb NOT NULL DEFAULT '{}'::jsonb,
  concentration_pct numeric(6,3) NOT NULL DEFAULT 0,
  diversification_score numeric(6,3) NOT NULL DEFAULT 0,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_fhchs_captured ON founder_hospital_contract_heatmap_snapshots(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhchs_hospital ON founder_hospital_contract_heatmap_snapshots(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhchs_category ON founder_hospital_contract_heatmap_snapshots(equipment_category);

ALTER TABLE founder_hospital_contract_heatmap_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fhchs_founder_all ON founder_hospital_contract_heatmap_snapshots;
CREATE POLICY p_fhchs_founder_all ON founder_hospital_contract_heatmap_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Concentration risk alerts table
CREATE TABLE IF NOT EXISTS founder_hospital_concentration_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_org_id uuid NOT NULL,
  alert_kind text NOT NULL,
  severity text NOT NULL DEFAULT 'p2',
  revenue_share_pct numeric(6,3),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  acknowledged_at timestamptz,
  acknowledged_by uuid
);

CREATE INDEX IF NOT EXISTS idx_fhca_created ON founder_hospital_concentration_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhca_unack ON founder_hospital_concentration_alerts(acknowledged_at) WHERE acknowledged_at IS NULL;

ALTER TABLE founder_hospital_concentration_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fhca_founder_all ON founder_hospital_concentration_alerts;
CREATE POLICY p_fhca_founder_all ON founder_hospital_concentration_alerts
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- Helper: log_founder_heatmap_view
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_heatmap_view(p_section text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_view', jsonb_build_object('section', p_section));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_heatmap_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_heatmap_view(text) TO authenticated;

-- ============================================================================
-- Helper: log_founder_heatmap_snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_heatmap_snapshot(p_snapshot_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_snapshot', jsonb_build_object('snapshot_id', p_snapshot_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_heatmap_snapshot(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_heatmap_snapshot(uuid) TO authenticated;

-- ============================================================================
-- Helper: log_founder_heatmap_alert_ack
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_heatmap_alert_ack(p_alert_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_alert_ack', jsonb_build_object('alert_id', p_alert_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_heatmap_alert_ack(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_heatmap_alert_ack(uuid) TO authenticated;

-- ============================================================================
-- Helper: log_founder_heatmap_export
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_heatmap_export(p_format text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_export', jsonb_build_object('format', p_format));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_heatmap_export(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_heatmap_export(text) TO authenticated;

-- ============================================================================
-- RPC 1: founder_heatmap_kpis (READ, STABLE)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_kpis()
RETURNS TABLE(
  total_active_contracts bigint,
  total_hospitals bigint,
  total_monthly_revenue_rupees bigint,
  total_annual_revenue_rupees bigint,
  top1_hospital_share_pct numeric,
  top5_hospital_share_pct numeric,
  top10_hospital_share_pct numeric,
  herfindahl_index numeric,
  distinct_categories bigint,
  distinct_cities bigint,
  open_concentration_alerts bigint,
  largest_single_contract_rupees bigint,
  median_contract_rupees bigint,
  hospitals_with_single_category bigint,
  hospitals_with_three_plus_categories bigint,
  diversification_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_monthly bigint := 0;
  v_total_contracts bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0), COUNT(*)
    INTO v_total_monthly, v_total_contracts
    FROM amc_contracts
   WHERE status = 'active';

  RETURN QUERY
  WITH hosp AS (
    SELECT p.organization_id AS hospital_org_id,
           SUM(ac.monthly_fee_rupees) AS monthly_value
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
     WHERE ac.status = 'active'
     GROUP BY p.organization_id
  ),
  ranked AS (
    SELECT hospital_org_id, monthly_value,
           ROW_NUMBER() OVER (ORDER BY monthly_value DESC NULLS LAST) AS rn
      FROM hosp
  ),
  cat_per_hosp AS (
    SELECT p.organization_id AS hospital_org_id,
           COUNT(DISTINCT ac.equipment_category) AS cat_count
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
     WHERE ac.status = 'active'
     GROUP BY p.organization_id
  )
  SELECT
    v_total_contracts,
    (SELECT COUNT(*) FROM hosp),
    v_total_monthly,
    v_total_monthly * 12,
    COALESCE((SELECT ROUND(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn = 1), 0),
    COALESCE((SELECT ROUND(SUM(monthly_value)::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn <= 5), 0),
    COALESCE((SELECT ROUND(SUM(monthly_value)::numeric / NULLIF(v_total_monthly,0) * 100, 2) FROM ranked WHERE rn <= 10), 0),
    COALESCE((SELECT ROUND(SUM(POWER(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2)), 2) FROM ranked), 0),
    (SELECT COUNT(DISTINCT equipment_category) FROM amc_contracts WHERE status = 'active'),
    (SELECT COUNT(DISTINCT o.city) FROM amc_contracts ac
        JOIN profiles p ON p.id = ac.hospital_user_id
        JOIN organizations o ON o.id = p.organization_id
       WHERE ac.status = 'active'),
    (SELECT COUNT(*) FROM founder_hospital_concentration_alerts WHERE acknowledged_at IS NULL),
    COALESCE((SELECT MAX(monthly_fee_rupees) FROM amc_contracts WHERE status='active'), 0),
    COALESCE((SELECT (percentile_cont(0.5) WITHIN GROUP (ORDER BY monthly_fee_rupees))::bigint
                FROM amc_contracts WHERE status='active'), 0),
    (SELECT COUNT(*) FROM cat_per_hosp WHERE cat_count = 1),
    (SELECT COUNT(*) FROM cat_per_hosp WHERE cat_count >= 3),
    COALESCE((SELECT ROUND(100 - SUM(POWER(monthly_value::numeric / NULLIF(v_total_monthly,0) * 100, 2)) / 100.0, 2) FROM ranked), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: founder_heatmap_by_hospital (READ, STABLE)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_by_hospital()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  hospital_city text,
  active_contracts bigint,
  distinct_categories bigint,
  monthly_value_rupees bigint,
  annual_value_rupees bigint,
  revenue_share_pct numeric,
  rn bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  RETURN QUERY
  SELECT o.id,
         o.name,
         o.city,
         COUNT(ac.id),
         COUNT(DISTINCT ac.equipment_category),
         COALESCE(SUM(ac.monthly_fee_rupees),0),
         COALESCE(SUM(ac.monthly_fee_rupees),0) * 12,
         ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3),
         ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(ac.monthly_fee_rupees),0) DESC)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
   WHERE ac.status = 'active'
   GROUP BY o.id, o.name, o.city
   ORDER BY 6 DESC
   LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_by_hospital() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_by_hospital() TO authenticated;

-- ============================================================================
-- RPC 3: founder_heatmap_by_category (READ, STABLE)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_by_category()
RETURNS TABLE(
  equipment_category text,
  contracts bigint,
  hospitals bigint,
  monthly_value_rupees bigint,
  annual_value_rupees bigint,
  avg_contract_rupees bigint,
  share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  RETURN QUERY
  SELECT ac.equipment_category,
         COUNT(*),
         COUNT(DISTINCT p.organization_id),
         COALESCE(SUM(ac.monthly_fee_rupees),0),
         COALESCE(SUM(ac.monthly_fee_rupees),0) * 12,
         COALESCE(AVG(ac.monthly_fee_rupees)::bigint, 0),
         ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
   WHERE ac.status = 'active'
   GROUP BY ac.equipment_category
   ORDER BY 4 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_by_category() TO authenticated;

-- ============================================================================
-- RPC 4: founder_heatmap_cells (READ, STABLE) -- hospital x category grid
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_cells()
RETURNS TABLE(
  id text,
  hospital_org_id uuid,
  hospital_name text,
  equipment_category text,
  contract_count bigint,
  monthly_value_rupees bigint,
  amc_tier_mix text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT (o.id::text || ':' || ac.equipment_category),
         o.id,
         o.name,
         ac.equipment_category,
         COUNT(*),
         COALESCE(SUM(ac.monthly_fee_rupees),0),
         string_agg(DISTINCT ac.amc_tier::text, ',' ORDER BY ac.amc_tier::text)
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
   WHERE ac.status = 'active'
   GROUP BY o.id, o.name, ac.equipment_category
   ORDER BY 6 DESC
   LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_cells() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_cells() TO authenticated;

-- ============================================================================
-- RPC 5: founder_heatmap_gaps (READ, STABLE) -- diversification gaps
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_gaps()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  hospital_city text,
  current_categories bigint,
  missing_categories text,
  monthly_value_rupees bigint,
  upsell_priority text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH all_cats AS (
    SELECT DISTINCT equipment_category FROM amc_contracts WHERE status='active'
  ),
  hosp_cats AS (
    SELECT p.organization_id AS hospital_org_id,
           array_agg(DISTINCT ac.equipment_category) AS cats,
           COUNT(DISTINCT ac.equipment_category) AS cat_count,
           SUM(ac.monthly_fee_rupees) AS monthly_value
      FROM amc_contracts ac
      JOIN profiles p ON p.id = ac.hospital_user_id
     WHERE ac.status='active'
     GROUP BY p.organization_id
  )
  SELECT o.id,
         o.name,
         o.city,
         hc.cat_count,
         (SELECT string_agg(equipment_category, ', ')
            FROM all_cats WHERE equipment_category != ALL(hc.cats)),
         COALESCE(hc.monthly_value,0)::bigint,
         CASE WHEN hc.monthly_value > 50000 THEN 'high'
              WHEN hc.monthly_value > 20000 THEN 'medium'
              ELSE 'low' END
    FROM hosp_cats hc
    JOIN organizations o ON o.id = hc.hospital_org_id
   WHERE hc.cat_count < (SELECT COUNT(*) FROM all_cats)
   ORDER BY hc.monthly_value DESC NULLS LAST
   LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_gaps() TO authenticated;

-- ============================================================================
-- RPC 6: founder_heatmap_alerts_list (READ, STABLE)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_alerts_list()
RETURNS TABLE(
  id uuid,
  created_at timestamptz,
  hospital_org_id uuid,
  hospital_name text,
  alert_kind text,
  severity text,
  revenue_share_pct numeric,
  acknowledged_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT a.id, a.created_at, a.hospital_org_id, o.name,
         a.alert_kind, a.severity, a.revenue_share_pct, a.acknowledged_at
    FROM founder_hospital_concentration_alerts a
    LEFT JOIN organizations o ON o.id = a.hospital_org_id
   ORDER BY a.acknowledged_at NULLS FIRST, a.created_at DESC
   LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_alerts_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_alerts_list() TO authenticated;

-- ============================================================================
-- RPC 7: founder_heatmap_capture_snapshot (WRITE, VOLATILE)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_heatmap_capture_snapshot()
RETURNS bigint
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total bigint := 0;
  v_rows bigint := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(SUM(monthly_fee_rupees),0) INTO v_total
    FROM amc_contracts WHERE status = 'active';

  INSERT INTO founder_hospital_contract_heatmap_snapshots(
    hospital_org_id, hospital_name, hospital_city, equipment_category,
    active_contract_count, total_monthly_value_rupees, total_annualized_value_rupees,
    tier_mix, concentration_pct, diversification_score)
  SELECT o.id, o.name, o.city, ac.equipment_category,
         COUNT(*),
         COALESCE(SUM(ac.monthly_fee_rupees),0),
         COALESCE(SUM(ac.monthly_fee_rupees),0) * 12,
         jsonb_object_agg(COALESCE(ac.amc_tier::text,'unknown'), 1),
         ROUND(COALESCE(SUM(ac.monthly_fee_rupees),0)::numeric / NULLIF(v_total,0) * 100, 3),
         0
    FROM amc_contracts ac
    JOIN profiles p ON p.id = ac.hospital_user_id
    JOIN organizations o ON o.id = p.organization_id
   WHERE ac.status = 'active'
   GROUP BY o.id, o.name, o.city, ac.equipment_category;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'heatmap_capture_snapshot', jsonb_build_object('rows', v_rows));

  RETURN v_rows;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_heatmap_capture_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_heatmap_capture_snapshot() TO authenticated;

COMMIT;