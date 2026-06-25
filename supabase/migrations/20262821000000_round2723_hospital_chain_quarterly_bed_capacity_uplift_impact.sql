BEGIN;

-- =========================================================================
-- Round 2723: Hospital Chain Quarterly Bed Capacity Uplift Impact
-- HEAVY ★★★★ founder console
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: chain quarterly bed capacity uplift records
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS chain_quarterly_bed_uplift_r2723 CASCADE;
CREATE TABLE chain_quarterly_bed_uplift_r2723 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name      text NOT NULL,
  region          text NOT NULL CHECK (region IN ('south','west','north','east','central')),
  quarter_label   text NOT NULL CHECK (quarter_label IN ('Q1','Q2','Q3','Q4')),
  fiscal_year     int  NOT NULL CHECK (fiscal_year BETWEEN 2024 AND 2030),
  beds_start      int  NOT NULL CHECK (beds_start >= 0),
  beds_end        int  NOT NULL CHECK (beds_end   >= 0),
  uplift_beds     int  NOT NULL CHECK (uplift_beds >= 0),
  uplift_pct      numeric(6,2) NOT NULL CHECK (uplift_pct >= 0),
  our_role        text NOT NULL CHECK (our_role IN ('exclusive_amc','primary_amc','co_vendor','spot_repair')),
  equipment_units int  NOT NULL CHECK (equipment_units >= 0),
  amc_rev_rupees  bigint NOT NULL CHECK (amc_rev_rupees >= 0),
  repair_rev_rupees bigint NOT NULL CHECK (repair_rev_rupees >= 0),
  story_snippet   text NOT NULL,
  recorded_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_quarterly_bed_uplift_r2723 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_quarterly_bed_uplift_r2723;
CREATE POLICY founder_all ON chain_quarterly_bed_uplift_r2723
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_quarterly_bed_uplift_r2723
  (chain_name, region, quarter_label, fiscal_year, beds_start, beds_end, uplift_beds, uplift_pct, our_role, equipment_units, amc_rev_rupees, repair_rev_rupees, story_snippet)
VALUES
  ('Apollo South Cluster','south','Q1',2026, 1800, 1980, 180, 10.00, 'exclusive_amc', 142, 4820000, 1240000,
   'Apollo opened a 180-bed cardiac wing in Chennai; our exclusive AMC covered 142 new units at sign-off.'),
  ('Yashoda Hyd Network','south','Q2',2026, 1450, 1610, 160, 11.03, 'primary_amc', 118, 3960000, 982000,
   'Yashoda added a Secunderabad oncology block; we onboarded 118 units within 30 days of opening.'),
  ('Manipal West India','west','Q2',2026, 2100, 2240, 140, 6.67, 'co_vendor', 86, 2410000, 670000,
   'Manipal Pune campus uplift; we hold co-vendor share alongside Siemens-CS — pushing for AMC exclusivity.'),
  ('Fortis NCR','north','Q3',2026, 2400, 2520, 120, 5.00, 'spot_repair', 34, 0, 1850000,
   'Fortis Gurgaon expanded ICU by 120 beds; we are spot-only — must convert to AMC before Q4 RFP.'),
  ('AIG Hospitals','south','Q3',2026, 1100, 1280, 180, 16.36, 'exclusive_amc', 156, 5240000, 1410000,
   'AIG Gachibowli liver-transplant block opening; 156 units entered AMC on Day 1 thanks to founder relationship.'),
  ('KIMS Sunshine','south','Q4',2026, 1600, 1740, 140, 8.75, 'primary_amc', 102, 3180000, 820000,
   'KIMS Begumpet ortho expansion; we won AMC against Philips on response-SLA proof.'),
  ('Care Hospitals','central','Q4',2026, 1300, 1420, 120, 9.23, 'exclusive_amc', 94, 2980000, 740000,
   'Care Banjara Hills NICU expansion; exclusive AMC renewed for 3 years on the back of zero-downtime track record.');

-- -------------------------------------------------------------------------
-- Table 2: chain narrative talking points (story spine)
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS chain_uplift_storyboard_r2723 CASCADE;
CREATE TABLE chain_uplift_storyboard_r2723 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name      text NOT NULL,
  pitch_audience  text NOT NULL CHECK (pitch_audience IN ('board','investor','customer','press')),
  headline        text NOT NULL,
  body            text NOT NULL,
  proof_metric    text NOT NULL,
  status          text NOT NULL CHECK (status IN ('draft','approved','published','archived')),
  approved_by     text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_uplift_storyboard_r2723 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_uplift_storyboard_r2723;
CREATE POLICY founder_all ON chain_uplift_storyboard_r2723
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO chain_uplift_storyboard_r2723
  (chain_name, pitch_audience, headline, body, proof_metric, status, approved_by)
VALUES
  ('Apollo South Cluster','investor','We grew with Apollo bed-for-bed',
   'Apollo South opened 180 new beds this quarter; we captured 142 equipment units inside AMC on day zero.',
   '142 units · 4.82L AMC · 1.24L repair','approved','Ganesh'),
  ('AIG Hospitals','board','AIG day-zero AMC win',
   'AIG transplant block live; we activated 156-unit AMC on opening day — fastest onboarding in segment.',
   '156 units · 5.24L AMC','approved','Ganesh'),
  ('Yashoda Hyd Network','customer','30-day onboarding promise kept',
   'Yashoda oncology block went live; 118 units fully AMC-covered inside 30 days — zero downtime.',
   '118 units · 30 days','published','Ganesh'),
  ('Fortis NCR','board','Fortis conversion at risk',
   'Fortis added 120 beds, we are spot-only. Need exclusive-AMC conversion before Q4 RFP closes.',
   '34 units spot only — 0 AMC','draft',NULL),
  ('Manipal West India','press','Manipal Pune co-vendor share growing',
   'Manipal Pune campus uplift saw our co-vendor share grow to 86 units, displacing Siemens-CS in 3 ICUs.',
   '86 units co-vendor','approved','Ganesh'),
  ('KIMS Sunshine','investor','SLA wins against Philips',
   'KIMS picked us over Philips for the Begumpet ortho block — response-SLA proof was the deciding factor.',
   '102 units AMC win','approved','Ganesh');

-- =========================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated, search_path locked)
-- =========================================================================

-- 1. KPI rollup
DROP FUNCTION IF EXISTS founder_chain_uplift_kpi_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_kpi_r2723()
RETURNS TABLE (
  chains_tracked     int,
  total_uplift_beds  bigint,
  total_units_won    bigint,
  total_amc_rupees   bigint,
  total_repair_rupees bigint,
  avg_uplift_pct     numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_name)::int,
    COALESCE(SUM(uplift_beds),0)::bigint,
    COALESCE(SUM(equipment_units),0)::bigint,
    COALESCE(SUM(amc_rev_rupees),0)::bigint,
    COALESCE(SUM(repair_rev_rupees),0)::bigint,
    COALESCE(ROUND(AVG(uplift_pct),2),0)::numeric
  FROM chain_quarterly_bed_uplift_r2723;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_kpi_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_kpi_r2723() TO authenticated;

-- 2. All chain rows
DROP FUNCTION IF EXISTS founder_chain_uplift_list_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_list_r2723()
RETURNS SETOF chain_quarterly_bed_uplift_r2723
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM chain_quarterly_bed_uplift_r2723
  ORDER BY fiscal_year DESC, quarter_label DESC, amc_rev_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_list_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_list_r2723() TO authenticated;

-- 3. Group by chain
DROP FUNCTION IF EXISTS founder_chain_uplift_by_chain_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_by_chain_r2723()
RETURNS TABLE (
  chain_name text,
  quarters_count int,
  total_uplift_beds bigint,
  total_units bigint,
  total_amc bigint,
  total_repair bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.chain_name,
    COUNT(*)::int,
    SUM(c.uplift_beds)::bigint,
    SUM(c.equipment_units)::bigint,
    SUM(c.amc_rev_rupees)::bigint,
    SUM(c.repair_rev_rupees)::bigint
  FROM chain_quarterly_bed_uplift_r2723 c
  GROUP BY c.chain_name
  ORDER BY SUM(c.amc_rev_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_by_chain_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_by_chain_r2723() TO authenticated;

-- 4. Region breakdown
DROP FUNCTION IF EXISTS founder_chain_uplift_by_region_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_by_region_r2723()
RETURNS TABLE (
  region text,
  chains_count int,
  total_uplift_beds bigint,
  total_amc bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.region,
    COUNT(DISTINCT c.chain_name)::int,
    SUM(c.uplift_beds)::bigint,
    SUM(c.amc_rev_rupees)::bigint
  FROM chain_quarterly_bed_uplift_r2723 c
  GROUP BY c.region
  ORDER BY SUM(c.amc_rev_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_by_region_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_by_region_r2723() TO authenticated;

-- 5. Role breakdown
DROP FUNCTION IF EXISTS founder_chain_uplift_by_role_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_by_role_r2723()
RETURNS TABLE (
  our_role text,
  rows_count int,
  total_units bigint,
  total_amc bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.our_role,
    COUNT(*)::int,
    SUM(c.equipment_units)::bigint,
    SUM(c.amc_rev_rupees)::bigint
  FROM chain_quarterly_bed_uplift_r2723 c
  GROUP BY c.our_role
  ORDER BY SUM(c.amc_rev_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_by_role_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_by_role_r2723() TO authenticated;

-- 6. Top uplift quarters
DROP FUNCTION IF EXISTS founder_chain_uplift_top_quarters_r2723(int);
CREATE OR REPLACE FUNCTION founder_chain_uplift_top_quarters_r2723(p_limit int DEFAULT 5)
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  fiscal_year int,
  uplift_beds int,
  uplift_pct numeric,
  amc_rev_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.chain_name,
    c.quarter_label,
    c.fiscal_year,
    c.uplift_beds,
    c.uplift_pct,
    c.amc_rev_rupees
  FROM chain_quarterly_bed_uplift_r2723 c
  ORDER BY c.uplift_pct DESC, c.amc_rev_rupees DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_top_quarters_r2723(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_top_quarters_r2723(int) TO authenticated;

-- 7. Storyboard list
DROP FUNCTION IF EXISTS founder_chain_uplift_storyboard_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_storyboard_r2723()
RETURNS SETOF chain_uplift_storyboard_r2723
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM chain_uplift_storyboard_r2723
  ORDER BY created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_storyboard_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_storyboard_r2723() TO authenticated;

-- 8. Storyboard audience rollup
DROP FUNCTION IF EXISTS founder_chain_uplift_storyboard_by_audience_r2723();
CREATE OR REPLACE FUNCTION founder_chain_uplift_storyboard_by_audience_r2723()
RETURNS TABLE (
  pitch_audience text,
  approved_count int,
  total_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    s.pitch_audience,
    SUM(CASE WHEN s.status IN ('approved','published') THEN 1 ELSE 0 END)::int,
    COUNT(*)::int
  FROM chain_uplift_storyboard_r2723 s
  GROUP BY s.pitch_audience
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_storyboard_by_audience_r2723() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_storyboard_by_audience_r2723() TO authenticated;

-- 9. Approve a storyboard entry
DROP FUNCTION IF EXISTS founder_chain_uplift_storyboard_approve_r2723(uuid, text);
CREATE OR REPLACE FUNCTION founder_chain_uplift_storyboard_approve_r2723(p_id uuid, p_approver text)
RETURNS chain_uplift_storyboard_r2723
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row chain_uplift_storyboard_r2723;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE chain_uplift_storyboard_r2723
     SET status = 'approved',
         approved_by = p_approver
   WHERE id = p_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_uplift_storyboard_approve_r2723(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_uplift_storyboard_approve_r2723(uuid, text) TO authenticated;

COMMIT;
