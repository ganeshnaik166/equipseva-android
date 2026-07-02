BEGIN;

-- =========================================================================
-- Round 2827 — Hospital Chain Quarterly Clinical Vendor Co-Marketing
-- Tracks: chain x vendor x campaign x shared cost x leads x ROI x outcome
-- =========================================================================

-- ---------- Table 1: campaigns ----------
CREATE TABLE IF NOT EXISTS chain_vendor_comarketing_campaigns_r2827 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  vendor_code text NOT NULL,
  vendor_name text NOT NULL,
  campaign_name text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('2026-Q1','2026-Q2','2026-Q3','2026-Q4','2027-Q1')),
  clinical_focus text NOT NULL CHECK (clinical_focus IN ('cardiology','oncology','radiology','orthopedics','neurology','pediatrics','ophthalmology')),
  campaign_type text NOT NULL CHECK (campaign_type IN ('cme_workshop','patient_screening','digital_awareness','equipment_demo','clinical_symposium')),
  shared_cost_rupees numeric(14,2) NOT NULL CHECK (shared_cost_rupees >= 0),
  chain_share_pct numeric(5,2) NOT NULL CHECK (chain_share_pct >= 0 AND chain_share_pct <= 100),
  vendor_share_pct numeric(5,2) NOT NULL CHECK (vendor_share_pct >= 0 AND vendor_share_pct <= 100),
  leads_target int NOT NULL CHECK (leads_target >= 0),
  leads_actual int NOT NULL DEFAULT 0 CHECK (leads_actual >= 0),
  revenue_attributed_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (revenue_attributed_rupees >= 0),
  status text NOT NULL CHECK (status IN ('planned','active','completed','cancelled','review')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  outcome_grade text CHECK (outcome_grade IN ('A','B','C','D','F')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_vendor_comarketing_campaigns_r2827 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_vendor_comarketing_campaigns_r2827;
CREATE POLICY founder_all ON chain_vendor_comarketing_campaigns_r2827
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_vendor_comarketing_campaigns_r2827
  (chain_code, chain_name, vendor_code, vendor_name, campaign_name, quarter, clinical_focus, campaign_type, shared_cost_rupees, chain_share_pct, vendor_share_pct, leads_target, leads_actual, revenue_attributed_rupees, status, start_date, end_date, outcome_grade)
VALUES
  ('APOLLO','Apollo Hospitals','GE_HC','GE Healthcare','Cardiac MRI Awareness Drive','2026-Q2','cardiology','digital_awareness',1850000.00,40.00,60.00,500,612,8400000.00,'completed','2026-04-01'::date,'2026-06-30'::date,'A'),
  ('FORTIS','Fortis Healthcare','SIEMENS','Siemens Healthineers','PET-CT Onco-Symposium','2026-Q2','oncology','clinical_symposium',2600000.00,35.00,65.00,300,278,6200000.00,'completed','2026-05-15'::date,'2026-06-15'::date,'B'),
  ('MAX','Max Healthcare','PHILIPS','Philips Medical','Neuro CT Screening Camps','2026-Q2','neurology','patient_screening',1200000.00,50.00,50.00,800,940,5100000.00,'completed','2026-04-10'::date,'2026-06-25'::date,'A'),
  ('MEDANTA','Medanta','MINDRAY','Mindray Bio-Medical','Pediatric Ultrasound CME','2026-Q3','pediatrics','cme_workshop',680000.00,45.00,55.00,150,142,1900000.00,'active','2026-07-01'::date,'2026-09-30'::date,'B'),
  ('NARAYANA','Narayana Health','CANON','Canon Medical','Ortho Joint-Care Demo','2026-Q3','orthopedics','equipment_demo',920000.00,30.00,70.00,250,210,2400000.00,'active','2026-07-05'::date,'2026-09-20'::date,'C'),
  ('MANIPAL','Manipal Hospitals','GE_HC','GE Healthcare','Ophthalmology OCT Roadshow','2026-Q3','ophthalmology','digital_awareness',1450000.00,40.00,60.00,400,0,0.00,'planned','2026-08-01'::date,'2026-09-30'::date,NULL),
  ('AIIMS_NW','AIIMS Network','SIEMENS','Siemens Healthineers','Cardiology Innovation Day','2026-Q4','cardiology','clinical_symposium',3100000.00,25.00,75.00,600,0,0.00,'planned','2026-10-15'::date,'2026-12-15'::date,NULL),
  ('FORTIS','Fortis Healthcare','PHILIPS','Philips Medical','Radiology AI Demo','2026-Q1','radiology','equipment_demo',1100000.00,40.00,60.00,200,88,1200000.00,'review','2026-01-10'::date,'2026-03-25'::date,'D');

-- ---------- Table 2: lead funnel ----------
CREATE TABLE IF NOT EXISTS chain_vendor_comarketing_leads_r2827 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES chain_vendor_comarketing_campaigns_r2827(id) ON DELETE CASCADE,
  funnel_stage text NOT NULL CHECK (funnel_stage IN ('captured','qualified','demo_done','quoted','closed_won','closed_lost')),
  leads_count int NOT NULL CHECK (leads_count >= 0),
  cost_per_lead_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (cost_per_lead_rupees >= 0),
  conversion_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (conversion_pct >= 0 AND conversion_pct <= 100),
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_vendor_comarketing_leads_r2827 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_vendor_comarketing_leads_r2827;
CREATE POLICY founder_all ON chain_vendor_comarketing_leads_r2827
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'captured', 612, 3023.00, 100.00, 'Apollo cardiac MRI top of funnel'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'Cardiac MRI Awareness Drive';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'qualified', 410, 4512.00, 67.00, 'Apollo cardiac qualified MQL'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'Cardiac MRI Awareness Drive';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'closed_won', 84, 22023.00, 13.70, 'Apollo cardiac wins'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'Cardiac MRI Awareness Drive';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'demo_done', 165, 15757.00, 59.30, 'Fortis PET-CT demos'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'PET-CT Onco-Symposium';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'closed_won', 41, 63414.00, 14.75, 'Fortis onco wins'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'PET-CT Onco-Symposium';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'captured', 940, 1276.00, 100.00, 'Max neuro screening top of funnel'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'Neuro CT Screening Camps';

INSERT INTO chain_vendor_comarketing_leads_r2827
  (campaign_id, funnel_stage, leads_count, cost_per_lead_rupees, conversion_pct, notes)
SELECT id, 'closed_won', 132, 9090.00, 14.04, 'Max neuro wins'
FROM chain_vendor_comarketing_campaigns_r2827 WHERE campaign_name = 'Neuro CT Screening Camps';

-- =========================================================================
-- RPCs (7 minimum)
-- =========================================================================

-- 1. KPI overview
DROP FUNCTION IF EXISTS founder_r2827_kpi_overview();
CREATE OR REPLACE FUNCTION founder_r2827_kpi_overview()
RETURNS TABLE (
  total_campaigns int,
  active_campaigns int,
  total_shared_cost_rupees numeric,
  total_revenue_attributed_rupees numeric,
  blended_roi_multiple numeric,
  total_leads_actual int,
  blended_lead_attainment_pct numeric
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
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'active')::int,
    COALESCE(SUM(shared_cost_rupees),0)::numeric,
    COALESCE(SUM(revenue_attributed_rupees),0)::numeric,
    CASE WHEN COALESCE(SUM(shared_cost_rupees),0) = 0 THEN 0
         ELSE ROUND(SUM(revenue_attributed_rupees) / SUM(shared_cost_rupees), 2) END,
    COALESCE(SUM(leads_actual),0)::int,
    CASE WHEN COALESCE(SUM(leads_target),0) = 0 THEN 0
         ELSE ROUND(SUM(leads_actual)::numeric * 100.0 / SUM(leads_target), 2) END
  FROM chain_vendor_comarketing_campaigns_r2827;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_kpi_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_kpi_overview() TO authenticated;

-- 2. Campaign list
DROP FUNCTION IF EXISTS founder_r2827_campaigns_list();
CREATE OR REPLACE FUNCTION founder_r2827_campaigns_list()
RETURNS TABLE (
  id uuid,
  chain_name text,
  vendor_name text,
  campaign_name text,
  quarter text,
  clinical_focus text,
  campaign_type text,
  shared_cost_rupees numeric,
  leads_actual int,
  leads_target int,
  revenue_attributed_rupees numeric,
  roi_multiple numeric,
  status text,
  outcome_grade text
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
    c.id, c.chain_name, c.vendor_name, c.campaign_name, c.quarter,
    c.clinical_focus, c.campaign_type, c.shared_cost_rupees,
    c.leads_actual, c.leads_target, c.revenue_attributed_rupees,
    CASE WHEN c.shared_cost_rupees = 0 THEN 0
         ELSE ROUND(c.revenue_attributed_rupees / c.shared_cost_rupees, 2) END,
    c.status, c.outcome_grade
  FROM chain_vendor_comarketing_campaigns_r2827 c
  ORDER BY c.start_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_campaigns_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_campaigns_list() TO authenticated;

-- 3. Roll-up by chain
DROP FUNCTION IF EXISTS founder_r2827_chain_rollup();
CREATE OR REPLACE FUNCTION founder_r2827_chain_rollup()
RETURNS TABLE (
  chain_name text,
  campaigns int,
  shared_cost_rupees numeric,
  revenue_attributed_rupees numeric,
  roi_multiple numeric,
  total_leads int
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
    c.chain_name,
    COUNT(*)::int,
    SUM(c.shared_cost_rupees)::numeric,
    SUM(c.revenue_attributed_rupees)::numeric,
    CASE WHEN SUM(c.shared_cost_rupees) = 0 THEN 0
         ELSE ROUND(SUM(c.revenue_attributed_rupees) / SUM(c.shared_cost_rupees), 2) END,
    SUM(c.leads_actual)::int
  FROM chain_vendor_comarketing_campaigns_r2827 c
  GROUP BY c.chain_name
  ORDER BY SUM(c.revenue_attributed_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_chain_rollup() TO authenticated;

-- 4. Roll-up by vendor
DROP FUNCTION IF EXISTS founder_r2827_vendor_rollup();
CREATE OR REPLACE FUNCTION founder_r2827_vendor_rollup()
RETURNS TABLE (
  vendor_name text,
  campaigns int,
  shared_cost_rupees numeric,
  revenue_attributed_rupees numeric,
  roi_multiple numeric,
  total_leads int
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
    c.vendor_name,
    COUNT(*)::int,
    SUM(c.shared_cost_rupees)::numeric,
    SUM(c.revenue_attributed_rupees)::numeric,
    CASE WHEN SUM(c.shared_cost_rupees) = 0 THEN 0
         ELSE ROUND(SUM(c.revenue_attributed_rupees) / SUM(c.shared_cost_rupees), 2) END,
    SUM(c.leads_actual)::int
  FROM chain_vendor_comarketing_campaigns_r2827 c
  GROUP BY c.vendor_name
  ORDER BY SUM(c.revenue_attributed_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_vendor_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_vendor_rollup() TO authenticated;

-- 5. Clinical focus mix
DROP FUNCTION IF EXISTS founder_r2827_clinical_focus_mix();
CREATE OR REPLACE FUNCTION founder_r2827_clinical_focus_mix()
RETURNS TABLE (
  clinical_focus text,
  campaigns int,
  shared_cost_rupees numeric,
  revenue_attributed_rupees numeric,
  roi_multiple numeric
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
    c.clinical_focus,
    COUNT(*)::int,
    SUM(c.shared_cost_rupees)::numeric,
    SUM(c.revenue_attributed_rupees)::numeric,
    CASE WHEN SUM(c.shared_cost_rupees) = 0 THEN 0
         ELSE ROUND(SUM(c.revenue_attributed_rupees) / SUM(c.shared_cost_rupees), 2) END
  FROM chain_vendor_comarketing_campaigns_r2827 c
  GROUP BY c.clinical_focus
  ORDER BY SUM(c.revenue_attributed_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_clinical_focus_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_clinical_focus_mix() TO authenticated;

-- 6. Funnel summary
DROP FUNCTION IF EXISTS founder_r2827_funnel_summary();
CREATE OR REPLACE FUNCTION founder_r2827_funnel_summary()
RETURNS TABLE (
  campaign_name text,
  funnel_stage text,
  leads_count int,
  cost_per_lead_rupees numeric,
  conversion_pct numeric
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
    c.campaign_name,
    l.funnel_stage,
    l.leads_count,
    l.cost_per_lead_rupees,
    l.conversion_pct
  FROM chain_vendor_comarketing_leads_r2827 l
  JOIN chain_vendor_comarketing_campaigns_r2827 c ON c.id = l.campaign_id
  ORDER BY c.campaign_name, l.funnel_stage;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_funnel_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_funnel_summary() TO authenticated;

-- 7. Outcome grade distribution
DROP FUNCTION IF EXISTS founder_r2827_outcome_distribution();
CREATE OR REPLACE FUNCTION founder_r2827_outcome_distribution()
RETURNS TABLE (
  outcome_grade text,
  campaigns int,
  shared_cost_rupees numeric,
  revenue_attributed_rupees numeric
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
    COALESCE(c.outcome_grade,'ungraded') AS outcome_grade,
    COUNT(*)::int,
    SUM(c.shared_cost_rupees)::numeric,
    SUM(c.revenue_attributed_rupees)::numeric
  FROM chain_vendor_comarketing_campaigns_r2827 c
  GROUP BY c.outcome_grade
  ORDER BY outcome_grade NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_outcome_distribution() TO authenticated;

-- 8. Quarter trend
DROP FUNCTION IF EXISTS founder_r2827_quarter_trend();
CREATE OR REPLACE FUNCTION founder_r2827_quarter_trend()
RETURNS TABLE (
  quarter text,
  campaigns int,
  shared_cost_rupees numeric,
  revenue_attributed_rupees numeric,
  roi_multiple numeric
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
    c.quarter,
    COUNT(*)::int,
    SUM(c.shared_cost_rupees)::numeric,
    SUM(c.revenue_attributed_rupees)::numeric,
    CASE WHEN SUM(c.shared_cost_rupees) = 0 THEN 0
         ELSE ROUND(SUM(c.revenue_attributed_rupees) / SUM(c.shared_cost_rupees), 2) END
  FROM chain_vendor_comarketing_campaigns_r2827 c
  GROUP BY c.quarter
  ORDER BY c.quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2827_quarter_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2827_quarter_trend() TO authenticated;

COMMIT;
