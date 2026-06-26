BEGIN;

-- ============================================================================
-- Round 2851 — Hospital Chain Quarterly Equipment Warranty Claim Pattern
-- ============================================================================

-- Table 1: warranty claim records
CREATE TABLE IF NOT EXISTS hospital_chain_warranty_claims_r2851 (
  id BIGSERIAL PRIMARY KEY,
  chain_name TEXT NOT NULL,
  quarter TEXT NOT NULL,
  asset_category TEXT NOT NULL CHECK (asset_category IN ('imaging','life_support','diagnostic','surgical','monitoring','laboratory')),
  asset_model TEXT NOT NULL,
  oem_name TEXT NOT NULL,
  claim_count INT NOT NULL DEFAULT 0 CHECK (claim_count >= 0),
  approved_count INT NOT NULL DEFAULT 0 CHECK (approved_count >= 0),
  rejected_count INT NOT NULL DEFAULT 0 CHECK (rejected_count >= 0),
  pending_count INT NOT NULL DEFAULT 0 CHECK (pending_count >= 0),
  avg_resolution_days NUMERIC(8,2) NOT NULL DEFAULT 0,
  total_claim_value_rupees BIGINT NOT NULL DEFAULT 0,
  primary_failure_cause TEXT NOT NULL CHECK (primary_failure_cause IN ('manufacturing_defect','wear_and_tear','power_surge','user_error','environmental','software_bug','calibration_drift')),
  oem_response_quality TEXT NOT NULL CHECK (oem_response_quality IN ('excellent','good','acceptable','poor','critical')),
  captured_at DATE NOT NULL DEFAULT CURRENT_DATE
);

ALTER TABLE hospital_chain_warranty_claims_r2851 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_warranty_claims_r2851;
CREATE POLICY founder_all ON hospital_chain_warranty_claims_r2851 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_warranty_claims_r2851 (chain_name, quarter, asset_category, asset_model, oem_name, claim_count, approved_count, rejected_count, pending_count, avg_resolution_days, total_claim_value_rupees, primary_failure_cause, oem_response_quality, captured_at) VALUES
('Apollo Hospitals','Q1-2026','imaging','GE Optima MR450w','GE Healthcare',14,11,2,1,9.40,4850000,'calibration_drift','good','2026-04-02'::date),
('Fortis Healthcare','Q1-2026','life_support','Drager Evita V300','Drager',8,6,1,1,7.20,1920000,'wear_and_tear','excellent','2026-04-02'::date),
('Manipal Hospitals','Q1-2026','diagnostic','Roche Cobas 6000','Roche',12,7,4,1,14.80,2640000,'calibration_drift','acceptable','2026-04-02'::date),
('Max Healthcare','Q1-2026','surgical','Stryker NAV3i','Stryker',5,4,1,0,6.60,1450000,'manufacturing_defect','excellent','2026-04-02'::date),
('Narayana Health','Q1-2026','monitoring','Philips IntelliVue MX800','Philips',22,12,8,2,18.30,1560000,'power_surge','poor','2026-04-02'::date),
('Apollo Hospitals','Q4-2025','imaging','GE Optima MR450w','GE Healthcare',11,9,1,1,10.20,3920000,'calibration_drift','good','2026-01-05'::date),
('Fortis Healthcare','Q4-2025','life_support','Drager Evita V300','Drager',6,5,1,0,8.40,1480000,'wear_and_tear','excellent','2026-01-05'::date),
('Manipal Hospitals','Q4-2025','laboratory','Sysmex XN-1000','Sysmex',9,3,5,1,21.60,1880000,'environmental','critical','2026-01-05'::date);

-- Table 2: OEM response benchmark
CREATE TABLE IF NOT EXISTS oem_warranty_response_benchmarks_r2851 (
  id BIGSERIAL PRIMARY KEY,
  oem_name TEXT NOT NULL,
  asset_category TEXT NOT NULL CHECK (asset_category IN ('imaging','life_support','diagnostic','surgical','monitoring','laboratory')),
  sla_response_hours INT NOT NULL CHECK (sla_response_hours > 0),
  actual_avg_response_hours NUMERIC(8,2) NOT NULL,
  approval_rate_pct NUMERIC(5,2) NOT NULL CHECK (approval_rate_pct >= 0 AND approval_rate_pct <= 100),
  first_resolution_pct NUMERIC(5,2) NOT NULL CHECK (first_resolution_pct >= 0 AND first_resolution_pct <= 100),
  parts_availability_score NUMERIC(4,2) NOT NULL CHECK (parts_availability_score >= 0 AND parts_availability_score <= 10),
  escalation_count INT NOT NULL DEFAULT 0,
  rating TEXT NOT NULL CHECK (rating IN ('tier_1','tier_2','tier_3','watchlist')),
  recorded_at DATE NOT NULL DEFAULT CURRENT_DATE
);

ALTER TABLE oem_warranty_response_benchmarks_r2851 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON oem_warranty_response_benchmarks_r2851;
CREATE POLICY founder_all ON oem_warranty_response_benchmarks_r2851 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO oem_warranty_response_benchmarks_r2851 (oem_name, asset_category, sla_response_hours, actual_avg_response_hours, approval_rate_pct, first_resolution_pct, parts_availability_score, escalation_count, rating, recorded_at) VALUES
('GE Healthcare','imaging',24,18.40,82.00,71.00,8.80,3,'tier_1','2026-04-05'::date),
('Drager','life_support',12,9.60,88.00,79.00,9.20,1,'tier_1','2026-04-05'::date),
('Roche','diagnostic',24,28.40,68.00,54.00,7.10,6,'tier_2','2026-04-05'::date),
('Stryker','surgical',48,36.20,90.00,82.00,8.40,2,'tier_1','2026-04-05'::date),
('Philips','monitoring',24,42.80,58.00,41.00,5.40,14,'watchlist','2026-04-05'::date),
('Sysmex','laboratory',48,68.20,42.00,32.00,4.80,18,'watchlist','2026-04-05'::date),
('Mindray','monitoring',24,22.00,76.00,68.00,7.80,4,'tier_2','2026-04-05'::date);

-- ============================================================================
-- RPCs (7 total)
-- ============================================================================

DROP FUNCTION IF EXISTS r2851_chain_claim_summary();
CREATE OR REPLACE FUNCTION r2851_chain_claim_summary()
RETURNS TABLE(chain_name TEXT, total_claims BIGINT, approved BIGINT, rejected BIGINT, pending BIGINT, success_rate_pct NUMERIC, total_value_rupees BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name,
         SUM(t.claim_count)::BIGINT,
         SUM(t.approved_count)::BIGINT,
         SUM(t.rejected_count)::BIGINT,
         SUM(t.pending_count)::BIGINT,
         ROUND((SUM(t.approved_count)::NUMERIC / NULLIF(SUM(t.claim_count),0)) * 100, 2),
         SUM(t.total_claim_value_rupees)::BIGINT
  FROM hospital_chain_warranty_claims_r2851 t
  GROUP BY t.chain_name
  ORDER BY SUM(t.claim_count) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_chain_claim_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_chain_claim_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2851_quarter_trend();
CREATE OR REPLACE FUNCTION r2851_quarter_trend()
RETURNS TABLE(quarter TEXT, claim_count BIGINT, approved BIGINT, avg_resolution_days NUMERIC, total_value BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter,
         SUM(t.claim_count)::BIGINT,
         SUM(t.approved_count)::BIGINT,
         ROUND(AVG(t.avg_resolution_days), 2),
         SUM(t.total_claim_value_rupees)::BIGINT
  FROM hospital_chain_warranty_claims_r2851 t
  GROUP BY t.quarter
  ORDER BY t.quarter DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_quarter_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_quarter_trend() TO authenticated;

DROP FUNCTION IF EXISTS r2851_failure_cause_breakdown();
CREATE OR REPLACE FUNCTION r2851_failure_cause_breakdown()
RETURNS TABLE(primary_failure_cause TEXT, claim_count BIGINT, approved BIGINT, success_rate_pct NUMERIC, avg_resolution_days NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.primary_failure_cause,
         SUM(t.claim_count)::BIGINT,
         SUM(t.approved_count)::BIGINT,
         ROUND((SUM(t.approved_count)::NUMERIC / NULLIF(SUM(t.claim_count),0)) * 100, 2),
         ROUND(AVG(t.avg_resolution_days), 2)
  FROM hospital_chain_warranty_claims_r2851 t
  GROUP BY t.primary_failure_cause
  ORDER BY SUM(t.claim_count) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_failure_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_failure_cause_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2851_oem_response_table();
CREATE OR REPLACE FUNCTION r2851_oem_response_table()
RETURNS TABLE(oem_name TEXT, asset_category TEXT, sla_response_hours INT, actual_avg_response_hours NUMERIC, approval_rate_pct NUMERIC, first_resolution_pct NUMERIC, parts_availability_score NUMERIC, escalation_count INT, rating TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.oem_name, b.asset_category, b.sla_response_hours, b.actual_avg_response_hours,
         b.approval_rate_pct, b.first_resolution_pct, b.parts_availability_score,
         b.escalation_count, b.rating
  FROM oem_warranty_response_benchmarks_r2851 b
  ORDER BY b.rating, b.escalation_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_oem_response_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_oem_response_table() TO authenticated;

DROP FUNCTION IF EXISTS r2851_asset_category_pattern();
CREATE OR REPLACE FUNCTION r2851_asset_category_pattern()
RETURNS TABLE(asset_category TEXT, claim_count BIGINT, approved BIGINT, rejected BIGINT, success_rate_pct NUMERIC, avg_value_per_claim BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.asset_category,
         SUM(t.claim_count)::BIGINT,
         SUM(t.approved_count)::BIGINT,
         SUM(t.rejected_count)::BIGINT,
         ROUND((SUM(t.approved_count)::NUMERIC / NULLIF(SUM(t.claim_count),0)) * 100, 2),
         (SUM(t.total_claim_value_rupees) / NULLIF(SUM(t.claim_count),0))::BIGINT
  FROM hospital_chain_warranty_claims_r2851 t
  GROUP BY t.asset_category
  ORDER BY SUM(t.claim_count) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_asset_category_pattern() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_asset_category_pattern() TO authenticated;

DROP FUNCTION IF EXISTS r2851_watchlist_oems();
CREATE OR REPLACE FUNCTION r2851_watchlist_oems()
RETURNS TABLE(oem_name TEXT, asset_category TEXT, sla_breach_hours NUMERIC, approval_rate_pct NUMERIC, escalation_count INT, rating TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.oem_name, b.asset_category,
         (b.actual_avg_response_hours - b.sla_response_hours),
         b.approval_rate_pct, b.escalation_count, b.rating
  FROM oem_warranty_response_benchmarks_r2851 b
  WHERE b.rating IN ('tier_3','watchlist') OR b.actual_avg_response_hours > b.sla_response_hours
  ORDER BY b.escalation_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_watchlist_oems() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_watchlist_oems() TO authenticated;

DROP FUNCTION IF EXISTS r2851_kpi_overview();
CREATE OR REPLACE FUNCTION r2851_kpi_overview()
RETURNS TABLE(total_claims BIGINT, total_approved BIGINT, total_rejected BIGINT, total_pending BIGINT, overall_success_pct NUMERIC, total_claim_value BIGINT, avg_resolution_days NUMERIC, watchlist_oem_count BIGINT, tracked_chains BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(t.claim_count),0)::BIGINT,
    COALESCE(SUM(t.approved_count),0)::BIGINT,
    COALESCE(SUM(t.rejected_count),0)::BIGINT,
    COALESCE(SUM(t.pending_count),0)::BIGINT,
    ROUND((COALESCE(SUM(t.approved_count),0)::NUMERIC / NULLIF(SUM(t.claim_count),0)) * 100, 2),
    COALESCE(SUM(t.total_claim_value_rupees),0)::BIGINT,
    ROUND(AVG(t.avg_resolution_days), 2),
    (SELECT COUNT(*) FROM oem_warranty_response_benchmarks_r2851 WHERE rating = 'watchlist')::BIGINT,
    (SELECT COUNT(DISTINCT chain_name) FROM hospital_chain_warranty_claims_r2851)::BIGINT
  FROM hospital_chain_warranty_claims_r2851 t;
END $$;
REVOKE EXECUTE ON FUNCTION r2851_kpi_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2851_kpi_overview() TO authenticated;

COMMIT;
