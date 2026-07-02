BEGIN;

-- =====================================================================
-- Round 2771: Hospital Chain Quarterly Equipment Decommission Pipeline
-- chain x asset x age x replacement plan x disposal value x outcome
-- =====================================================================

CREATE TABLE IF NOT EXISTS chain_decommission_assets_r2771 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_branch text NOT NULL,
  asset_tag text NOT NULL UNIQUE,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','life_support','surgical','diagnostic','sterilization','monitoring')),
  manufacturer text NOT NULL,
  model_name text NOT NULL,
  commissioned_at date NOT NULL,
  age_years numeric(4,1) NOT NULL CHECK (age_years >= 0),
  useful_life_years numeric(4,1) NOT NULL CHECK (useful_life_years > 0),
  current_condition text NOT NULL CHECK (current_condition IN ('good','fair','poor','critical','non_operational')),
  utilization_pct numeric(5,2) NOT NULL CHECK (utilization_pct >= 0 AND utilization_pct <= 100),
  ytd_downtime_hours integer NOT NULL CHECK (ytd_downtime_hours >= 0),
  ytd_repair_cost_rupees integer NOT NULL CHECK (ytd_repair_cost_rupees >= 0),
  replacement_plan text NOT NULL CHECK (replacement_plan IN ('retire','replace_new','replace_refurb','redeploy','sell_used','donate')),
  replacement_quarter text NOT NULL CHECK (replacement_quarter IN ('Q1','Q2','Q3','Q4','deferred')),
  replacement_capex_rupees integer NOT NULL CHECK (replacement_capex_rupees >= 0),
  estimated_disposal_value_rupees integer NOT NULL CHECK (estimated_disposal_value_rupees >= 0),
  realized_disposal_value_rupees integer CHECK (realized_disposal_value_rupees IS NULL OR realized_disposal_value_rupees >= 0),
  decommission_outcome text NOT NULL CHECK (decommission_outcome IN ('planned','approved','in_progress','completed','blocked','cancelled')),
  blocker_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_decommission_assets_r2771 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_decommission_assets_r2771;
CREATE POLICY founder_all ON chain_decommission_assets_r2771
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_decommission_assets_r2771 (chain_name, hospital_branch, asset_tag, equipment_category, manufacturer, model_name, commissioned_at, age_years, useful_life_years, current_condition, utilization_pct, ytd_downtime_hours, ytd_repair_cost_rupees, replacement_plan, replacement_quarter, replacement_capex_rupees, estimated_disposal_value_rupees, realized_disposal_value_rupees, decommission_outcome, blocker_note) VALUES
('Apollo Group','Apollo Hyderabad Jubilee Hills','APH-CT-014','imaging','GE Healthcare','BrightSpeed 16','2012-04-15'::date, 14.2, 12.0, 'poor', 42.50, 312, 685000, 'replace_new','Q1', 12500000, 850000, 920000, 'completed', NULL),
('Apollo Group','Apollo Chennai Greams Road','APC-VENT-027','life_support','Drager','Evita V300','2014-08-20'::date, 11.9, 10.0, 'critical', 28.30, 478, 412000, 'replace_refurb','Q2', 3200000, 145000, NULL, 'in_progress', NULL),
('Manipal Hospitals','Manipal Bangalore Old Airport','MBO-MRI-003','imaging','Siemens','Magnetom Aera 1.5T','2010-11-02'::date, 15.6, 14.0, 'fair', 67.80, 198, 1240000, 'replace_new','Q1', 78500000, 4200000, NULL, 'approved', NULL),
('Manipal Hospitals','Manipal Jaipur','MJP-USG-019','diagnostic','Philips','HD11 XE','2013-02-10'::date, 13.3, 10.0, 'poor', 51.20, 142, 218000, 'sell_used','Q3', 0, 95000, NULL, 'planned', NULL),
('Fortis Healthcare','Fortis Gurgaon FMRI','FGM-AUTO-005','sterilization','STERIS','AMSCO 400','2011-06-18'::date, 14.9, 12.0, 'non_operational', 0.00, 1820, 92000, 'retire','Q1', 0, 35000, 38000, 'completed', NULL),
('Fortis Healthcare','Fortis Mohali','FMH-MON-041','monitoring','Mindray','BeneView T8','2015-09-22'::date, 10.8, 8.0, 'fair', 73.50, 88, 78000, 'redeploy','Q4', 0, 0, NULL, 'planned', NULL),
('Max Healthcare','Max Saket','MXS-CARM-011','surgical','Ziehm','Vision RFD','2013-12-01'::date, 12.5, 10.0, 'poor', 38.90, 256, 542000, 'replace_refurb','Q2', 8600000, 480000, NULL, 'blocked', 'awaiting board capex sign-off above 75L threshold'),
('Max Healthcare','Max Patparganj','MXP-DIA-008','life_support','Fresenius','4008S','2012-03-14'::date, 14.3, 10.0, 'critical', 19.40, 612, 318000, 'donate','Q2', 0, 0, NULL, 'approved', NULL),
('Narayana Health','NH Bangalore Bommasandra','NHB-LINAC-002','surgical','Varian','Clinac iX','2009-07-25'::date, 16.9, 15.0, 'poor', 58.70, 412, 2150000, 'replace_new','Q3', 145000000, 6800000, NULL, 'approved', NULL),
('Narayana Health','NH Howrah','NHH-XRAY-022','imaging','Allengers','MARS 15','2014-05-30'::date, 12.1, 10.0, 'fair', 61.30, 124, 165000, 'sell_used','Q4', 0, 78000, NULL, 'planned', NULL);

CREATE TABLE IF NOT EXISTS chain_decommission_quarterly_rollup_r2771 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('Q1','Q2','Q3','Q4')),
  fiscal_year integer NOT NULL CHECK (fiscal_year BETWEEN 2024 AND 2030),
  assets_planned integer NOT NULL DEFAULT 0 CHECK (assets_planned >= 0),
  assets_completed integer NOT NULL DEFAULT 0 CHECK (assets_completed >= 0),
  assets_blocked integer NOT NULL DEFAULT 0 CHECK (assets_blocked >= 0),
  total_capex_rupees bigint NOT NULL DEFAULT 0 CHECK (total_capex_rupees >= 0),
  total_disposal_realized_rupees bigint NOT NULL DEFAULT 0 CHECK (total_disposal_realized_rupees >= 0),
  net_capex_rupees bigint NOT NULL DEFAULT 0,
  capex_variance_pct numeric(6,2) NOT NULL DEFAULT 0,
  pipeline_health text NOT NULL CHECK (pipeline_health IN ('on_track','at_risk','off_track','blocked')),
  board_review_status text NOT NULL CHECK (board_review_status IN ('pending','reviewed','approved','rejected')),
  reviewed_at timestamptz,
  reviewer_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_name, fiscal_quarter, fiscal_year)
);

ALTER TABLE chain_decommission_quarterly_rollup_r2771 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_decommission_quarterly_rollup_r2771;
CREATE POLICY founder_all ON chain_decommission_quarterly_rollup_r2771
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_decommission_quarterly_rollup_r2771 (chain_name, fiscal_quarter, fiscal_year, assets_planned, assets_completed, assets_blocked, total_capex_rupees, total_disposal_realized_rupees, net_capex_rupees, capex_variance_pct, pipeline_health, board_review_status, reviewed_at, reviewer_note) VALUES
('Apollo Group','Q1', 2026, 8, 6, 0, 92500000, 1840000, 90660000, -3.20, 'on_track','approved', now() - interval '14 days', 'tracking ahead on Q1 imaging refresh'),
('Apollo Group','Q2', 2026, 6, 1, 0, 18400000, 0, 18400000, 1.80, 'on_track','reviewed', now() - interval '4 days', 'Q2 mid-quarter review clean'),
('Manipal Hospitals','Q1', 2026, 5, 4, 0, 124000000, 6200000, 117800000, 8.40, 'at_risk','approved', now() - interval '20 days', 'MRI replacement capex 8.4% over budget'),
('Manipal Hospitals','Q3', 2026, 4, 0, 0, 16800000, 0, 16800000, 0.00, 'on_track','pending', NULL, NULL),
('Fortis Healthcare','Q1', 2026, 3, 3, 0, 4200000, 73000, 4127000, -1.50, 'on_track','approved', now() - interval '18 days', 'Fortis Q1 sterilization wave closed'),
('Fortis Healthcare','Q4', 2026, 2, 0, 0, 0, 0, 0, 0.00, 'on_track','pending', NULL, NULL),
('Max Healthcare','Q2', 2026, 4, 1, 1, 12800000, 0, 12800000, 12.50, 'at_risk','reviewed', now() - interval '2 days', 'C-arm refurb blocked on board sign-off'),
('Max Healthcare','Q3', 2026, 3, 0, 0, 22400000, 0, 22400000, 0.00, 'on_track','pending', NULL, NULL),
('Narayana Health','Q3', 2026, 4, 0, 0, 152000000, 0, 152000000, 4.20, 'at_risk','reviewed', now() - interval '6 days', 'LINAC replacement 4.2% above plan'),
('Narayana Health','Q4', 2026, 2, 0, 0, 0, 78000, -78000, 0.00, 'on_track','pending', NULL, NULL);

-- ============================== RPC 1 ==============================
DROP FUNCTION IF EXISTS r2771_pipeline_kpis();
CREATE OR REPLACE FUNCTION r2771_pipeline_kpis()
RETURNS TABLE(
  total_assets integer,
  assets_blocked integer,
  total_capex_rupees bigint,
  total_disposal_realized_rupees bigint,
  avg_age_years numeric,
  chains_in_pipeline integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE decommission_outcome = 'blocked')::int,
    COALESCE(SUM(replacement_capex_rupees),0)::bigint,
    COALESCE(SUM(realized_disposal_value_rupees),0)::bigint,
    COALESCE(ROUND(AVG(age_years)::numeric, 1), 0),
    COUNT(DISTINCT chain_name)::int
  FROM chain_decommission_assets_r2771;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_pipeline_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_pipeline_kpis() TO authenticated;

-- ============================== RPC 2 ==============================
DROP FUNCTION IF EXISTS r2771_assets_by_chain();
CREATE OR REPLACE FUNCTION r2771_assets_by_chain()
RETURNS TABLE(
  chain_name text,
  asset_count integer,
  blocked_count integer,
  total_capex bigint,
  realized_disposal bigint,
  avg_age_years numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.chain_name,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE a.decommission_outcome = 'blocked')::int,
    COALESCE(SUM(a.replacement_capex_rupees),0)::bigint,
    COALESCE(SUM(a.realized_disposal_value_rupees),0)::bigint,
    ROUND(AVG(a.age_years)::numeric, 1)
  FROM chain_decommission_assets_r2771 a
  GROUP BY a.chain_name
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_assets_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_assets_by_chain() TO authenticated;

-- ============================== RPC 3 ==============================
DROP FUNCTION IF EXISTS r2771_assets_by_category();
CREATE OR REPLACE FUNCTION r2771_assets_by_category()
RETURNS TABLE(
  equipment_category text,
  asset_count integer,
  avg_age numeric,
  avg_utilization numeric,
  total_repair_cost bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.equipment_category,
    COUNT(*)::int,
    ROUND(AVG(a.age_years)::numeric, 1),
    ROUND(AVG(a.utilization_pct)::numeric, 1),
    COALESCE(SUM(a.ytd_repair_cost_rupees),0)::bigint
  FROM chain_decommission_assets_r2771 a
  GROUP BY a.equipment_category
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_assets_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_assets_by_category() TO authenticated;

-- ============================== RPC 4 ==============================
DROP FUNCTION IF EXISTS r2771_replacement_plan_mix();
CREATE OR REPLACE FUNCTION r2771_replacement_plan_mix()
RETURNS TABLE(
  replacement_plan text,
  asset_count integer,
  total_capex bigint,
  total_disposal_value bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.replacement_plan,
    COUNT(*)::int,
    COALESCE(SUM(a.replacement_capex_rupees),0)::bigint,
    COALESCE(SUM(a.estimated_disposal_value_rupees),0)::bigint
  FROM chain_decommission_assets_r2771 a
  GROUP BY a.replacement_plan
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_replacement_plan_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_replacement_plan_mix() TO authenticated;

-- ============================== RPC 5 ==============================
DROP FUNCTION IF EXISTS r2771_blocked_assets();
CREATE OR REPLACE FUNCTION r2771_blocked_assets()
RETURNS TABLE(
  asset_tag text,
  chain_name text,
  hospital_branch text,
  equipment_category text,
  age_years numeric,
  replacement_capex_rupees integer,
  blocker_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.chain_name, a.hospital_branch, a.equipment_category,
         a.age_years, a.replacement_capex_rupees, a.blocker_note
  FROM chain_decommission_assets_r2771 a
  WHERE a.decommission_outcome = 'blocked'
  ORDER BY a.replacement_capex_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_blocked_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_blocked_assets() TO authenticated;

-- ============================== RPC 6 ==============================
DROP FUNCTION IF EXISTS r2771_quarterly_rollups();
CREATE OR REPLACE FUNCTION r2771_quarterly_rollups()
RETURNS TABLE(
  chain_name text,
  fiscal_quarter text,
  fiscal_year integer,
  assets_planned integer,
  assets_completed integer,
  assets_blocked integer,
  net_capex_rupees bigint,
  capex_variance_pct numeric,
  pipeline_health text,
  board_review_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.fiscal_quarter, r.fiscal_year, r.assets_planned, r.assets_completed,
         r.assets_blocked, r.net_capex_rupees, r.capex_variance_pct, r.pipeline_health, r.board_review_status
  FROM chain_decommission_quarterly_rollup_r2771 r
  ORDER BY r.fiscal_year DESC, r.fiscal_quarter, r.chain_name;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_quarterly_rollups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_quarterly_rollups() TO authenticated;

-- ============================== RPC 7 ==============================
DROP FUNCTION IF EXISTS r2771_outcome_mix();
CREATE OR REPLACE FUNCTION r2771_outcome_mix()
RETURNS TABLE(
  decommission_outcome text,
  asset_count integer,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM chain_decommission_assets_r2771;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT a.decommission_outcome, COUNT(*)::int,
         ROUND((COUNT(*)::numeric * 100 / v_total), 1)
  FROM chain_decommission_assets_r2771 a
  GROUP BY a.decommission_outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_outcome_mix() TO authenticated;

-- ============================== RPC 8 ==============================
DROP FUNCTION IF EXISTS r2771_top_capex_assets();
CREATE OR REPLACE FUNCTION r2771_top_capex_assets()
RETURNS TABLE(
  asset_tag text,
  chain_name text,
  equipment_category text,
  age_years numeric,
  replacement_capex_rupees integer,
  estimated_disposal_value_rupees integer,
  decommission_outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.asset_tag, a.chain_name, a.equipment_category, a.age_years,
         a.replacement_capex_rupees, a.estimated_disposal_value_rupees, a.decommission_outcome
  FROM chain_decommission_assets_r2771 a
  ORDER BY a.replacement_capex_rupees DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION r2771_top_capex_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2771_top_capex_assets() TO authenticated;

COMMIT;
