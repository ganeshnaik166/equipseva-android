BEGIN;

-- ============================================================
-- Round 2855: Hospital Chain Quarterly Equipment EOL Replacement
-- ============================================================

CREATE TABLE IF NOT EXISTS hospital_chain_eol_assets_r2855 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_branch text NOT NULL,
  asset_serial text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('ventilator','dialysis','xray','ct_scan','mri','ultrasound','ecg','defib','infusion_pump','monitor','autoclave','anesthesia')),
  asset_make text NOT NULL,
  asset_model text NOT NULL,
  install_date date NOT NULL,
  expected_eol_date date NOT NULL,
  current_age_months integer NOT NULL CHECK (current_age_months >= 0),
  remaining_life_months integer NOT NULL,
  condition_grade text NOT NULL CHECK (condition_grade IN ('excellent','good','fair','poor','critical')),
  current_book_value_rupees bigint NOT NULL CHECK (current_book_value_rupees >= 0),
  replacement_quarter text NOT NULL CHECK (replacement_quarter IN ('Q1','Q2','Q3','Q4')),
  replacement_year integer NOT NULL,
  replacement_status text NOT NULL CHECK (replacement_status IN ('planned','procurement','approved','ordered','delivered','installed','deferred')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_eol_assets_r2855 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_eol_assets_r2855;
CREATE POLICY founder_all ON hospital_chain_eol_assets_r2855 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_eol_assets_r2855 (chain_name, hospital_branch, asset_serial, asset_category, asset_make, asset_model, install_date, expected_eol_date, current_age_months, remaining_life_months, condition_grade, current_book_value_rupees, replacement_quarter, replacement_year, replacement_status) VALUES
('Apollo Group','Apollo Hyderabad Jubilee Hills','VENT-AP-J-0341','ventilator','Drager','Evita V500','2017-04-15'::date,'2026-09-30'::date,110,3,'fair',180000,'Q3',2026,'procurement'),
('Yashoda Chain','Yashoda Somajiguda','DIAL-YS-S-0117','dialysis','Fresenius','4008S','2016-08-20'::date,'2026-10-15'::date,118,4,'poor',95000,'Q3',2026,'approved'),
('KIMS Network','KIMS Secunderabad','CT-KM-S-0029','ct_scan','Siemens','Somatom Definition','2014-02-10'::date,'2026-12-31'::date,148,6,'poor',1850000,'Q4',2026,'planned'),
('Continental Hospitals','Continental Gachibowli','MRI-CT-G-0011','mri','GE Healthcare','Signa HDxt 1.5T','2013-11-05'::date,'2026-11-30'::date,151,5,'critical',2400000,'Q4',2026,'ordered'),
('Care Hospitals','Care Banjara Hills','XR-CR-B-0258','xray','Philips','DigitalDiagnost C90','2018-06-12'::date,'2027-01-31'::date,96,7,'fair',320000,'Q1',2027,'planned'),
('AIG Hospitals','AIG Gachibowli','ULT-AI-G-0445','ultrasound','GE Healthcare','LOGIQ E9','2017-09-25'::date,'2027-02-28'::date,93,8,'good',280000,'Q1',2027,'planned'),
('Sunshine Hospitals','Sunshine Paradise','AUT-SS-P-0772','autoclave','Getinge','Quadro 446','2015-12-08'::date,'2026-09-15'::date,114,3,'critical',75000,'Q3',2026,'approved'),
('Apollo Group','Apollo Health City','ECG-AP-HC-0509','ecg','Schiller','Cardiovit AT-102','2016-03-18'::date,'2026-12-20'::date,123,6,'poor',45000,'Q4',2026,'procurement');

CREATE INDEX IF NOT EXISTS hospital_chain_eol_assets_r2855_chain_idx ON hospital_chain_eol_assets_r2855(chain_name);
CREATE INDEX IF NOT EXISTS hospital_chain_eol_assets_r2855_quarter_idx ON hospital_chain_eol_assets_r2855(replacement_year, replacement_quarter);

CREATE TABLE IF NOT EXISTS hospital_chain_eol_procurement_r2855 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  replacement_quarter text NOT NULL CHECK (replacement_quarter IN ('Q1','Q2','Q3','Q4')),
  replacement_year integer NOT NULL,
  asset_category text NOT NULL,
  units_to_replace integer NOT NULL CHECK (units_to_replace > 0),
  budget_allocated_rupees bigint NOT NULL CHECK (budget_allocated_rupees >= 0),
  estimated_capex_rupees bigint NOT NULL CHECK (estimated_capex_rupees >= 0),
  vendor_shortlisted text NOT NULL,
  po_status text NOT NULL CHECK (po_status IN ('rfq_open','quoted','negotiation','po_issued','dispatched','received','installed')),
  service_revenue_impact_rupees bigint NOT NULL,
  amc_renewal_value_rupees bigint NOT NULL CHECK (amc_renewal_value_rupees >= 0),
  decision_owner text NOT NULL,
  decision_due_date date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_eol_procurement_r2855 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_eol_procurement_r2855;
CREATE POLICY founder_all ON hospital_chain_eol_procurement_r2855 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_eol_procurement_r2855 (chain_name, replacement_quarter, replacement_year, asset_category, units_to_replace, budget_allocated_rupees, estimated_capex_rupees, vendor_shortlisted, po_status, service_revenue_impact_rupees, amc_renewal_value_rupees, decision_owner, decision_due_date, notes) VALUES
('Apollo Group','Q3',2026,'ventilator',4,2400000,2280000,'Drager Medical India','negotiation',1800000,720000,'Apollo CFO Mr. Krishnan','2026-07-15'::date,'Bundled deal with 3-yr CMC negotiated'),
('Yashoda Chain','Q3',2026,'dialysis',6,3600000,3480000,'Fresenius Medical Care','po_issued',2400000,1080000,'Yashoda COO Dr. Reddy','2026-07-20'::date,'Replacement linked to dialysis-day expansion'),
('KIMS Network','Q4',2026,'ct_scan',2,40000000,38500000,'Siemens Healthineers','rfq_open',12000000,4500000,'KIMS MD Dr. Murali','2026-08-31'::date,'CT-scan tariff revision pending'),
('Continental Hospitals','Q4',2026,'mri',1,55000000,52000000,'GE Healthcare India','quoted',18000000,6500000,'Continental CMO Dr. Gupta','2026-09-15'::date,'1.5T to 3T upgrade requested'),
('Care Hospitals','Q1',2027,'xray',8,4800000,4640000,'Philips India','rfq_open',1600000,960000,'Care VP Procurement Mr. Iyer','2026-10-30'::date,'Bundled with PACS upgrade'),
('AIG Hospitals','Q1',2027,'ultrasound',5,3500000,3380000,'GE Healthcare India','rfq_open',2000000,840000,'AIG Procurement Head Mr. Naidu','2026-11-15'::date,'4D probes requested for obstetrics expansion'),
('Sunshine Hospitals','Q3',2026,'autoclave',3,1500000,1410000,'Getinge India','received',0,360000,'Sunshine GM Mr. Rao','2026-07-10'::date,'OT compliance critical');

CREATE INDEX IF NOT EXISTS hospital_chain_eol_procurement_r2855_chain_idx ON hospital_chain_eol_procurement_r2855(chain_name);

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2855_eol_overview();
CREATE OR REPLACE FUNCTION founder_r2855_eol_overview()
RETURNS TABLE (
  total_assets bigint,
  critical_grade bigint,
  poor_grade bigint,
  total_book_value_rupees bigint,
  total_estimated_capex_rupees bigint,
  total_amc_renewal_rupees bigint,
  total_service_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM hospital_chain_eol_assets_r2855)::bigint,
    (SELECT count(*) FROM hospital_chain_eol_assets_r2855 WHERE condition_grade = 'critical')::bigint,
    (SELECT count(*) FROM hospital_chain_eol_assets_r2855 WHERE condition_grade = 'poor')::bigint,
    (SELECT coalesce(sum(current_book_value_rupees),0) FROM hospital_chain_eol_assets_r2855)::bigint,
    (SELECT coalesce(sum(estimated_capex_rupees),0) FROM hospital_chain_eol_procurement_r2855)::bigint,
    (SELECT coalesce(sum(amc_renewal_value_rupees),0) FROM hospital_chain_eol_procurement_r2855)::bigint,
    (SELECT coalesce(sum(service_revenue_impact_rupees),0) FROM hospital_chain_eol_procurement_r2855)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_eol_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_eol_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_eol_assets_list();
CREATE OR REPLACE FUNCTION founder_r2855_eol_assets_list()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_branch text,
  asset_serial text,
  asset_category text,
  asset_make text,
  asset_model text,
  install_date date,
  expected_eol_date date,
  current_age_months integer,
  remaining_life_months integer,
  condition_grade text,
  current_book_value_rupees bigint,
  replacement_quarter text,
  replacement_year integer,
  replacement_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_branch, a.asset_serial, a.asset_category, a.asset_make, a.asset_model,
         a.install_date, a.expected_eol_date, a.current_age_months, a.remaining_life_months,
         a.condition_grade, a.current_book_value_rupees, a.replacement_quarter, a.replacement_year, a.replacement_status
  FROM hospital_chain_eol_assets_r2855 a
  ORDER BY a.expected_eol_date ASC, a.condition_grade DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_eol_assets_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_eol_assets_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_procurement_pipeline();
CREATE OR REPLACE FUNCTION founder_r2855_procurement_pipeline()
RETURNS TABLE (
  id uuid,
  chain_name text,
  replacement_quarter text,
  replacement_year integer,
  asset_category text,
  units_to_replace integer,
  budget_allocated_rupees bigint,
  estimated_capex_rupees bigint,
  vendor_shortlisted text,
  po_status text,
  service_revenue_impact_rupees bigint,
  amc_renewal_value_rupees bigint,
  decision_owner text,
  decision_due_date date,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.chain_name, p.replacement_quarter, p.replacement_year, p.asset_category,
         p.units_to_replace, p.budget_allocated_rupees, p.estimated_capex_rupees, p.vendor_shortlisted,
         p.po_status, p.service_revenue_impact_rupees, p.amc_renewal_value_rupees,
         p.decision_owner, p.decision_due_date, p.notes
  FROM hospital_chain_eol_procurement_r2855 p
  ORDER BY p.replacement_year, p.replacement_quarter, p.estimated_capex_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_procurement_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_procurement_pipeline() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_chain_rollup();
CREATE OR REPLACE FUNCTION founder_r2855_chain_rollup()
RETURNS TABLE (
  chain_name text,
  asset_count bigint,
  critical_count bigint,
  total_book_value_rupees bigint,
  total_capex_planned_rupees bigint,
  total_amc_renewal_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.chain_name,
    count(*)::bigint AS asset_count,
    count(*) FILTER (WHERE a.condition_grade = 'critical')::bigint AS critical_count,
    coalesce(sum(a.current_book_value_rupees),0)::bigint AS total_book_value_rupees,
    coalesce((SELECT sum(p.estimated_capex_rupees) FROM hospital_chain_eol_procurement_r2855 p WHERE p.chain_name = a.chain_name),0)::bigint AS total_capex_planned_rupees,
    coalesce((SELECT sum(p.amc_renewal_value_rupees) FROM hospital_chain_eol_procurement_r2855 p WHERE p.chain_name = a.chain_name),0)::bigint AS total_amc_renewal_rupees
  FROM hospital_chain_eol_assets_r2855 a
  GROUP BY a.chain_name
  ORDER BY total_capex_planned_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_chain_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_quarter_rollup();
CREATE OR REPLACE FUNCTION founder_r2855_quarter_rollup()
RETURNS TABLE (
  replacement_year integer,
  replacement_quarter text,
  asset_count bigint,
  units_to_replace bigint,
  total_capex_rupees bigint,
  total_amc_renewal_rupees bigint,
  total_service_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.replacement_year,
    p.replacement_quarter,
    coalesce((SELECT count(*) FROM hospital_chain_eol_assets_r2855 a WHERE a.replacement_year = p.replacement_year AND a.replacement_quarter = p.replacement_quarter),0)::bigint AS asset_count,
    coalesce(sum(p.units_to_replace),0)::bigint AS units_to_replace,
    coalesce(sum(p.estimated_capex_rupees),0)::bigint AS total_capex_rupees,
    coalesce(sum(p.amc_renewal_value_rupees),0)::bigint AS total_amc_renewal_rupees,
    coalesce(sum(p.service_revenue_impact_rupees),0)::bigint AS total_service_revenue_impact_rupees
  FROM hospital_chain_eol_procurement_r2855 p
  GROUP BY p.replacement_year, p.replacement_quarter
  ORDER BY p.replacement_year, p.replacement_quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_quarter_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_quarter_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_critical_assets();
CREATE OR REPLACE FUNCTION founder_r2855_critical_assets()
RETURNS TABLE (
  chain_name text,
  hospital_branch text,
  asset_serial text,
  asset_category text,
  remaining_life_months integer,
  condition_grade text,
  replacement_status text,
  expected_eol_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name, a.hospital_branch, a.asset_serial, a.asset_category,
         a.remaining_life_months, a.condition_grade, a.replacement_status, a.expected_eol_date
  FROM hospital_chain_eol_assets_r2855 a
  WHERE a.condition_grade IN ('critical','poor') OR a.remaining_life_months <= 6
  ORDER BY a.remaining_life_months ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_critical_assets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_critical_assets() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_po_status_breakdown();
CREATE OR REPLACE FUNCTION founder_r2855_po_status_breakdown()
RETURNS TABLE (
  po_status text,
  pipeline_count bigint,
  total_capex_rupees bigint,
  total_amc_renewal_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.po_status,
    count(*)::bigint AS pipeline_count,
    coalesce(sum(p.estimated_capex_rupees),0)::bigint AS total_capex_rupees,
    coalesce(sum(p.amc_renewal_value_rupees),0)::bigint AS total_amc_renewal_rupees
  FROM hospital_chain_eol_procurement_r2855 p
  GROUP BY p.po_status
  ORDER BY total_capex_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_po_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_po_status_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2855_category_rollup();
CREATE OR REPLACE FUNCTION founder_r2855_category_rollup()
RETURNS TABLE (
  asset_category text,
  asset_count bigint,
  total_book_value_rupees bigint,
  total_capex_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.asset_category,
    count(*)::bigint AS asset_count,
    coalesce(sum(a.current_book_value_rupees),0)::bigint AS total_book_value_rupees,
    coalesce((SELECT sum(p.estimated_capex_rupees) FROM hospital_chain_eol_procurement_r2855 p WHERE p.asset_category = a.asset_category),0)::bigint AS total_capex_rupees
  FROM hospital_chain_eol_assets_r2855 a
  GROUP BY a.asset_category
  ORDER BY total_capex_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2855_category_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2855_category_rollup() TO authenticated;

COMMIT;
