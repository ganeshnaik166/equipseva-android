-- Round 2908 — Customer Monthly Engineer Wearable-Uniform & Safety-Gear Compliance
-- Tables (_r2908 suffix) + 7 founder-gated RPCs + seed data.

BEGIN;

-- ============================================================================
-- TABLE 1 — monthly compliance checks per engineer per customer site visit
-- ============================================================================
CREATE TABLE IF NOT EXISTS engineer_wearable_compliance_checks_r2908 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_month date NOT NULL,
  engineer_user_id uuid,
  customer_org_id uuid,
  city text NOT NULL,
  uniform_clean boolean NOT NULL DEFAULT true,
  id_badge_visible boolean NOT NULL DEFAULT true,
  safety_shoes_worn boolean NOT NULL DEFAULT true,
  gloves_worn boolean NOT NULL DEFAULT true,
  mask_worn boolean NOT NULL DEFAULT true,
  helmet_worn boolean NOT NULL DEFAULT true,
  goggles_worn boolean NOT NULL DEFAULT true,
  hi_vis_vest_worn boolean NOT NULL DEFAULT true,
  compliance_score numeric(5,2) NOT NULL DEFAULT 100.00,
  total_items_checked int NOT NULL DEFAULT 8,
  total_items_passed int NOT NULL DEFAULT 8,
  customer_feedback text,
  photo_evidence_url text,
  flagged boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_wearable_compliance_checks_r2908 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TABLE 2 — safety gear inventory & issuance audit per engineer
-- ============================================================================
CREATE TABLE IF NOT EXISTS engineer_safety_gear_inventory_r2908 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid,
  gear_type text NOT NULL,
  issued_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  last_inspection_at timestamptz,
  condition_grade text NOT NULL DEFAULT 'good',
  replacement_due boolean NOT NULL DEFAULT false,
  cost_rupees int NOT NULL DEFAULT 0,
  supplier_name text,
  city text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_safety_gear_inventory_r2908 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEED DATA — compliance checks (20 rows)
-- ============================================================================
INSERT INTO engineer_wearable_compliance_checks_r2908
  (check_month, city, uniform_clean, id_badge_visible, safety_shoes_worn, gloves_worn, mask_worn, helmet_worn, goggles_worn, hi_vis_vest_worn, compliance_score, total_items_passed, customer_feedback, flagged)
VALUES
  ('2026-06-01'::date, 'Hyderabad', true, true, true, true, true, true, true, true, 100.00, 8, 'Excellent presentation', false),
  ('2026-06-01'::date, 'Bangalore', true, true, true, true, true, true, false, true, 87.50, 7, 'Missing goggles for laser unit', true),
  ('2026-06-01'::date, 'Chennai', true, true, true, true, true, true, true, true, 100.00, 8, 'Spotless uniform', false),
  ('2026-06-01'::date, 'Mumbai', false, true, true, true, true, true, true, true, 87.50, 7, 'Uniform stained, please replace', true),
  ('2026-06-01'::date, 'Delhi', true, true, true, true, true, true, true, true, 100.00, 8, 'Professional', false),
  ('2026-06-01'::date, 'Pune', true, true, false, true, true, true, true, true, 87.50, 7, 'Sneakers instead of safety shoes', true),
  ('2026-06-01'::date, 'Kolkata', true, true, true, true, true, true, true, true, 100.00, 8, 'All gear in order', false),
  ('2026-06-01'::date, 'Ahmedabad', true, false, true, true, true, true, true, true, 87.50, 7, 'ID badge not visible', true),
  ('2026-06-01'::date, 'Jaipur', true, true, true, true, true, true, true, true, 100.00, 8, 'Clean and professional', false),
  ('2026-06-01'::date, 'Lucknow', true, true, true, false, true, true, true, true, 87.50, 7, 'Gloves missing during cath lab work', true),
  ('2026-06-01'::date, 'Hyderabad', true, true, true, true, true, true, true, true, 100.00, 8, 'Top tier', false),
  ('2026-06-01'::date, 'Bangalore', true, true, true, true, true, true, true, true, 100.00, 8, 'Good', false),
  ('2026-06-01'::date, 'Chennai', true, true, true, true, false, true, true, true, 87.50, 7, 'No mask in OT zone', true),
  ('2026-06-01'::date, 'Mumbai', true, true, true, true, true, true, true, true, 100.00, 8, 'Excellent', false),
  ('2026-06-01'::date, 'Delhi', true, true, true, true, true, false, true, true, 87.50, 7, 'No helmet in radiology', true),
  ('2026-06-01'::date, 'Pune', true, true, true, true, true, true, true, true, 100.00, 8, 'All checks passed', false),
  ('2026-06-01'::date, 'Kolkata', true, true, true, true, true, true, true, false, 87.50, 7, 'Hi-vis vest absent', true),
  ('2026-06-01'::date, 'Ahmedabad', true, true, true, true, true, true, true, true, 100.00, 8, 'Compliant', false),
  ('2026-06-01'::date, 'Jaipur', true, true, true, true, true, true, true, true, 100.00, 8, 'Excellent', false),
  ('2026-06-01'::date, 'Lucknow', true, true, true, true, true, true, true, true, 100.00, 8, 'Spotless', false);

-- ============================================================================
-- SEED DATA — safety gear inventory (18 rows)
-- ============================================================================
INSERT INTO engineer_safety_gear_inventory_r2908
  (gear_type, issued_at, expires_at, last_inspection_at, condition_grade, replacement_due, cost_rupees, supplier_name, city, notes)
VALUES
  ('safety_shoes', '2026-01-15'::timestamptz, '2027-01-15'::timestamptz, '2026-05-15'::timestamptz, 'good', false, 2400, 'Karam India', 'Hyderabad', 'Steel toe S3'),
  ('helmet', '2026-02-10'::timestamptz, '2027-02-10'::timestamptz, '2026-05-20'::timestamptz, 'good', false, 850, 'Venus Safety', 'Bangalore', 'Class A'),
  ('gloves_nitrile', '2026-06-01'::timestamptz, '2026-07-01'::timestamptz, '2026-06-15'::timestamptz, 'good', false, 320, 'Ansell', 'Chennai', 'Box of 100'),
  ('goggles', '2026-03-05'::timestamptz, '2027-03-05'::timestamptz, '2026-05-10'::timestamptz, 'fair', true, 480, '3M India', 'Mumbai', 'Scratched lens'),
  ('uniform_shirt', '2026-04-01'::timestamptz, '2026-10-01'::timestamptz, '2026-06-01'::timestamptz, 'good', false, 1200, 'Liberty Uniforms', 'Delhi', 'Branded EquipSeva'),
  ('hi_vis_vest', '2026-02-20'::timestamptz, '2027-02-20'::timestamptz, '2026-05-12'::timestamptz, 'good', false, 650, 'Karam India', 'Pune', 'Class 2'),
  ('mask_n95', '2026-06-01'::timestamptz, '2026-06-30'::timestamptz, '2026-06-15'::timestamptz, 'good', false, 180, '3M India', 'Kolkata', 'Box of 20'),
  ('id_badge', '2026-01-01'::timestamptz, '2027-01-01'::timestamptz, '2026-06-01'::timestamptz, 'good', false, 250, 'Inhouse', 'Ahmedabad', 'NFC chip'),
  ('safety_shoes', '2026-02-01'::timestamptz, '2027-02-01'::timestamptz, '2026-05-15'::timestamptz, 'poor', true, 2400, 'Karam India', 'Jaipur', 'Sole worn'),
  ('helmet', '2025-12-10'::timestamptz, '2026-12-10'::timestamptz, '2026-04-20'::timestamptz, 'good', false, 850, 'Venus Safety', 'Lucknow', null),
  ('gloves_cut_resistant', '2026-05-15'::timestamptz, '2026-08-15'::timestamptz, '2026-06-10'::timestamptz, 'good', false, 540, 'Ansell', 'Hyderabad', 'Level 5'),
  ('goggles', '2026-03-15'::timestamptz, '2027-03-15'::timestamptz, '2026-05-25'::timestamptz, 'good', false, 480, '3M India', 'Bangalore', null),
  ('uniform_trousers', '2026-04-10'::timestamptz, '2026-10-10'::timestamptz, '2026-06-01'::timestamptz, 'good', false, 980, 'Liberty Uniforms', 'Chennai', null),
  ('hi_vis_vest', '2026-01-25'::timestamptz, '2027-01-25'::timestamptz, '2026-04-30'::timestamptz, 'fair', true, 650, 'Karam India', 'Mumbai', 'Reflective tape peeling'),
  ('mask_surgical', '2026-06-10'::timestamptz, '2026-07-10'::timestamptz, '2026-06-15'::timestamptz, 'good', false, 90, '3M India', 'Delhi', 'Box of 50'),
  ('safety_shoes', '2026-05-01'::timestamptz, '2027-05-01'::timestamptz, '2026-06-01'::timestamptz, 'good', false, 2400, 'Karam India', 'Pune', null),
  ('helmet', '2025-11-15'::timestamptz, '2026-11-15'::timestamptz, '2026-05-15'::timestamptz, 'fair', true, 850, 'Venus Safety', 'Kolkata', 'Crack near brim'),
  ('id_badge', '2026-02-01'::timestamptz, '2027-02-01'::timestamptz, '2026-06-01'::timestamptz, 'good', false, 250, 'Inhouse', 'Ahmedabad', null);

-- ============================================================================
-- RPC 1 — KPI summary
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_compliance_summary()
RETURNS TABLE(
  total_checks bigint,
  flagged_checks bigint,
  avg_compliance_score numeric,
  perfect_scores bigint,
  unique_cities bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE flagged)::bigint,
    round(avg(compliance_score), 2),
    count(*) FILTER (WHERE compliance_score = 100.00)::bigint,
    count(DISTINCT city)::bigint
  FROM engineer_wearable_compliance_checks_r2908;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_compliance_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_compliance_summary() TO authenticated;

-- ============================================================================
-- RPC 2 — compliance by city
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_compliance_by_city()
RETURNS TABLE(
  city text,
  checks bigint,
  flagged bigint,
  avg_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.city,
    count(*)::bigint,
    count(*) FILTER (WHERE c.flagged)::bigint,
    round(avg(c.compliance_score), 2)
  FROM engineer_wearable_compliance_checks_r2908 c
  GROUP BY c.city
  ORDER BY avg(c.compliance_score) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_compliance_by_city() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_compliance_by_city() TO authenticated;

-- ============================================================================
-- RPC 3 — flagged checks detail
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_flagged_checks()
RETURNS TABLE(
  id uuid,
  city text,
  check_month date,
  compliance_score numeric,
  customer_feedback text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.id, c.city, c.check_month, c.compliance_score, c.customer_feedback
  FROM engineer_wearable_compliance_checks_r2908 c
  WHERE c.flagged
  ORDER BY c.compliance_score ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_flagged_checks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_flagged_checks() TO authenticated;

-- ============================================================================
-- RPC 4 — gear inventory summary
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_gear_inventory_summary()
RETURNS TABLE(
  total_items bigint,
  replacement_due_count bigint,
  total_cost_rupees bigint,
  unique_gear_types bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE replacement_due)::bigint,
    sum(cost_rupees)::bigint,
    count(DISTINCT gear_type)::bigint
  FROM engineer_safety_gear_inventory_r2908;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_gear_inventory_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_gear_inventory_summary() TO authenticated;

-- ============================================================================
-- RPC 5 — gear due for replacement
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_gear_replacement_due()
RETURNS TABLE(
  id uuid,
  gear_type text,
  city text,
  condition_grade text,
  cost_rupees int,
  supplier_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT g.id, g.gear_type, g.city, g.condition_grade, g.cost_rupees, g.supplier_name
  FROM engineer_safety_gear_inventory_r2908 g
  WHERE g.replacement_due
  ORDER BY g.cost_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_gear_replacement_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_gear_replacement_due() TO authenticated;

-- ============================================================================
-- RPC 6 — gear by type breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_gear_by_type()
RETURNS TABLE(
  gear_type text,
  units bigint,
  total_cost bigint,
  due_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    g.gear_type,
    count(*)::bigint,
    sum(g.cost_rupees)::bigint,
    count(*) FILTER (WHERE g.replacement_due)::bigint
  FROM engineer_safety_gear_inventory_r2908 g
  GROUP BY g.gear_type
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_gear_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_gear_by_type() TO authenticated;

-- ============================================================================
-- RPC 7 — recent checks (last 20)
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_recent_checks()
RETURNS TABLE(
  id uuid,
  check_month date,
  city text,
  compliance_score numeric,
  total_items_passed int,
  flagged boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.id, c.check_month, c.city, c.compliance_score, c.total_items_passed, c.flagged
  FROM engineer_wearable_compliance_checks_r2908 c
  ORDER BY c.created_at DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_recent_checks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_recent_checks() TO authenticated;

-- ============================================================================
-- RPC 8 — supplier spend breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION rpc_r2908_supplier_spend()
RETURNS TABLE(
  supplier_name text,
  units bigint,
  total_spend_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    g.supplier_name,
    count(*)::bigint,
    sum(g.cost_rupees)::bigint
  FROM engineer_safety_gear_inventory_r2908 g
  WHERE g.supplier_name IS NOT NULL
  GROUP BY g.supplier_name
  ORDER BY sum(g.cost_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2908_supplier_spend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2908_supplier_spend() TO authenticated;

COMMIT;
