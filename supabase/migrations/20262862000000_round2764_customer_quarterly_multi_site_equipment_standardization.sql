BEGIN;

-- ============================================================================
-- Round 2764: Customer Quarterly Multi-Site Equipment Standardization
-- HEAVY founder console: customer × site × equipment kind × variance × standardize × cost saving
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: customer_site_equipment_inventory_r2764
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.customer_site_equipment_inventory_r2764 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  site_code text NOT NULL,
  site_city text NOT NULL,
  equipment_kind text NOT NULL,
  brand_model text NOT NULL,
  units_count integer NOT NULL CHECK (units_count >= 0),
  avg_age_months integer NOT NULL CHECK (avg_age_months >= 0),
  annual_service_cost_rupees numeric(14,2) NOT NULL CHECK (annual_service_cost_rupees >= 0),
  is_standard_brand boolean NOT NULL DEFAULT false,
  variance_severity text NOT NULL CHECK (variance_severity IN ('none','low','medium','high','critical')),
  quarter_label text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_site_equipment_inventory_r2764 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_site_equipment_inventory_r2764;
CREATE POLICY founder_all ON public.customer_site_equipment_inventory_r2764
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.customer_site_equipment_inventory_r2764
  (customer_org_name, site_code, site_city, equipment_kind, brand_model, units_count, avg_age_months, annual_service_cost_rupees, is_standard_brand, variance_severity, quarter_label)
VALUES
  ('Apollo Hospitals Group', 'APL-HYD-01', 'Hyderabad', 'Ultrasound', 'GE Voluson E10', 4, 38, 480000.00, true, 'none', 'Q2-2026'),
  ('Apollo Hospitals Group', 'APL-CHN-02', 'Chennai', 'Ultrasound', 'Philips Affiniti 70', 3, 42, 420000.00, false, 'high', 'Q2-2026'),
  ('Apollo Hospitals Group', 'APL-BLR-03', 'Bengaluru', 'Ultrasound', 'Mindray DC-70', 2, 28, 240000.00, false, 'medium', 'Q2-2026'),
  ('Fortis Healthcare', 'FRT-DEL-01', 'Delhi', 'CT Scanner', 'Siemens Somatom Go', 2, 30, 980000.00, true, 'none', 'Q2-2026'),
  ('Fortis Healthcare', 'FRT-MUM-02', 'Mumbai', 'CT Scanner', 'GE Revolution EVO', 1, 22, 720000.00, false, 'critical', 'Q2-2026'),
  ('Manipal Hospitals', 'MNP-BLR-01', 'Bengaluru', 'MRI', 'Siemens Magnetom Sola', 1, 14, 1450000.00, true, 'none', 'Q2-2026'),
  ('Manipal Hospitals', 'MNP-JPR-02', 'Jaipur', 'MRI', 'Philips Ingenia', 1, 18, 1620000.00, false, 'high', 'Q2-2026'),
  ('Narayana Health', 'NRH-BLR-01', 'Bengaluru', 'Dialysis', 'Fresenius 4008S', 12, 36, 360000.00, true, 'none', 'Q2-2026'),
  ('Narayana Health', 'NRH-KOL-02', 'Kolkata', 'Dialysis', 'Nipro Surdial', 8, 44, 280000.00, false, 'medium', 'Q2-2026');

-- ----------------------------------------------------------------------------
-- Table 2: standardization_recommendation_r2764
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.standardization_recommendation_r2764 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_name text NOT NULL,
  equipment_kind text NOT NULL,
  recommended_brand_model text NOT NULL,
  non_standard_sites_count integer NOT NULL CHECK (non_standard_sites_count >= 0),
  estimated_annual_saving_rupees numeric(14,2) NOT NULL CHECK (estimated_annual_saving_rupees >= 0),
  rollout_horizon_months integer NOT NULL CHECK (rollout_horizon_months > 0),
  capex_required_rupees numeric(14,2) NOT NULL CHECK (capex_required_rupees >= 0),
  payback_months integer NOT NULL CHECK (payback_months > 0),
  recommendation_status text NOT NULL CHECK (recommendation_status IN ('draft','proposed','accepted','rolling_out','complete','rejected')),
  founder_notes text,
  proposed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.standardization_recommendation_r2764 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.standardization_recommendation_r2764;
CREATE POLICY founder_all ON public.standardization_recommendation_r2764
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.standardization_recommendation_r2764
  (customer_org_name, equipment_kind, recommended_brand_model, non_standard_sites_count, estimated_annual_saving_rupees, rollout_horizon_months, capex_required_rupees, payback_months, recommendation_status, founder_notes)
VALUES
  ('Apollo Hospitals Group', 'Ultrasound', 'GE Voluson E10', 2, 380000.00, 9, 2400000.00, 38, 'proposed', 'Consolidate CHN+BLR onto APL-HYD standard; vendor discount tier unlocks at 10 units'),
  ('Fortis Healthcare', 'CT Scanner', 'Siemens Somatom Go', 1, 290000.00, 6, 4200000.00, 14, 'accepted', 'MUM swap-out scheduled Q4 2026; trade-in credit secured'),
  ('Manipal Hospitals', 'MRI', 'Siemens Magnetom Sola', 1, 410000.00, 12, 6800000.00, 24, 'proposed', 'JPR Philips Ingenia under AMC until Q1 2027 — start rollout post-expiry'),
  ('Narayana Health', 'Dialysis', 'Fresenius 4008S', 1, 220000.00, 8, 1800000.00, 18, 'rolling_out', 'KOL Nipro fleet aging out; 8 units swap in 2 waves'),
  ('Apollo Hospitals Group', 'CT Scanner', 'Siemens Somatom Go', 3, 540000.00, 14, 9600000.00, 32, 'draft', 'Cross-vertical standardization candidate — pending Apollo CFO review'),
  ('Fortis Healthcare', 'Ultrasound', 'GE Voluson E10', 4, 320000.00, 10, 3200000.00, 30, 'draft', 'Mixed Mindray/Philips fleet; consolidating onto Apollo standard saves ~12%'),
  ('Manipal Hospitals', 'Dialysis', 'Fresenius 4008S', 2, 180000.00, 7, 1500000.00, 22, 'proposed', 'Smaller fleet — bundle with Narayana procurement for volume discount');

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. KPI summary
DROP FUNCTION IF EXISTS public.rpc_r2764_kpi_summary();
CREATE OR REPLACE FUNCTION public.rpc_r2764_kpi_summary()
RETURNS TABLE (
  total_customers integer,
  total_sites integer,
  total_units integer,
  total_annual_service_cost_rupees numeric,
  total_non_standard_sites integer,
  total_estimated_saving_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT customer_org_name)::int FROM customer_site_equipment_inventory_r2764),
    (SELECT COUNT(DISTINCT site_code)::int FROM customer_site_equipment_inventory_r2764),
    (SELECT COALESCE(SUM(units_count),0)::int FROM customer_site_equipment_inventory_r2764),
    (SELECT COALESCE(SUM(annual_service_cost_rupees),0)::numeric FROM customer_site_equipment_inventory_r2764),
    (SELECT COUNT(*)::int FROM customer_site_equipment_inventory_r2764 WHERE is_standard_brand = false),
    (SELECT COALESCE(SUM(estimated_annual_saving_rupees),0)::numeric FROM standardization_recommendation_r2764);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_kpi_summary() TO authenticated;

-- 2. Inventory rows
DROP FUNCTION IF EXISTS public.rpc_r2764_inventory_rows();
CREATE OR REPLACE FUNCTION public.rpc_r2764_inventory_rows()
RETURNS SETOF customer_site_equipment_inventory_r2764
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM customer_site_equipment_inventory_r2764
  ORDER BY customer_org_name, equipment_kind, site_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_inventory_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_inventory_rows() TO authenticated;

-- 3. Recommendation rows
DROP FUNCTION IF EXISTS public.rpc_r2764_recommendation_rows();
CREATE OR REPLACE FUNCTION public.rpc_r2764_recommendation_rows()
RETURNS SETOF standardization_recommendation_r2764
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM standardization_recommendation_r2764
  ORDER BY estimated_annual_saving_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_recommendation_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_recommendation_rows() TO authenticated;

-- 4. Variance by customer
DROP FUNCTION IF EXISTS public.rpc_r2764_variance_by_customer();
CREATE OR REPLACE FUNCTION public.rpc_r2764_variance_by_customer()
RETURNS TABLE (
  customer_org_name text,
  total_sites integer,
  non_standard_sites integer,
  variance_pct numeric,
  worst_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.customer_org_name,
    COUNT(*)::int AS total_sites,
    SUM(CASE WHEN i.is_standard_brand = false THEN 1 ELSE 0 END)::int AS non_standard_sites,
    ROUND(100.0 * SUM(CASE WHEN i.is_standard_brand = false THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2) AS variance_pct,
    MAX(CASE i.variance_severity
      WHEN 'critical' THEN '5_critical'
      WHEN 'high' THEN '4_high'
      WHEN 'medium' THEN '3_medium'
      WHEN 'low' THEN '2_low'
      ELSE '1_none' END) AS worst_severity
  FROM customer_site_equipment_inventory_r2764 i
  GROUP BY i.customer_org_name
  ORDER BY variance_pct DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_variance_by_customer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_variance_by_customer() TO authenticated;

-- 5. Saving by equipment kind
DROP FUNCTION IF EXISTS public.rpc_r2764_saving_by_kind();
CREATE OR REPLACE FUNCTION public.rpc_r2764_saving_by_kind()
RETURNS TABLE (
  equipment_kind text,
  recommendation_count integer,
  total_saving_rupees numeric,
  total_capex_rupees numeric,
  avg_payback_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.equipment_kind,
    COUNT(*)::int,
    COALESCE(SUM(r.estimated_annual_saving_rupees),0)::numeric,
    COALESCE(SUM(r.capex_required_rupees),0)::numeric,
    ROUND(AVG(r.payback_months)::numeric, 1)
  FROM standardization_recommendation_r2764 r
  GROUP BY r.equipment_kind
  ORDER BY total_saving_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_saving_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_saving_by_kind() TO authenticated;

-- 6. Status pipeline
DROP FUNCTION IF EXISTS public.rpc_r2764_status_pipeline();
CREATE OR REPLACE FUNCTION public.rpc_r2764_status_pipeline()
RETURNS TABLE (
  recommendation_status text,
  count_recommendations integer,
  saving_in_status_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.recommendation_status,
    COUNT(*)::int,
    COALESCE(SUM(r.estimated_annual_saving_rupees),0)::numeric
  FROM standardization_recommendation_r2764 r
  GROUP BY r.recommendation_status
  ORDER BY saving_in_status_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_status_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_status_pipeline() TO authenticated;

-- 7. Top quick wins (high saving, fast payback)
DROP FUNCTION IF EXISTS public.rpc_r2764_top_quick_wins();
CREATE OR REPLACE FUNCTION public.rpc_r2764_top_quick_wins()
RETURNS TABLE (
  customer_org_name text,
  equipment_kind text,
  recommended_brand_model text,
  estimated_annual_saving_rupees numeric,
  payback_months integer,
  recommendation_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.customer_org_name,
    r.equipment_kind,
    r.recommended_brand_model,
    r.estimated_annual_saving_rupees,
    r.payback_months,
    r.recommendation_status
  FROM standardization_recommendation_r2764 r
  WHERE r.payback_months <= 24
  ORDER BY r.estimated_annual_saving_rupees DESC, r.payback_months ASC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_top_quick_wins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_top_quick_wins() TO authenticated;

-- 8. Site cost outliers
DROP FUNCTION IF EXISTS public.rpc_r2764_site_cost_outliers();
CREATE OR REPLACE FUNCTION public.rpc_r2764_site_cost_outliers()
RETURNS TABLE (
  customer_org_name text,
  site_code text,
  site_city text,
  equipment_kind text,
  brand_model text,
  annual_service_cost_rupees numeric,
  cost_per_unit_rupees numeric,
  variance_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.customer_org_name,
    i.site_code,
    i.site_city,
    i.equipment_kind,
    i.brand_model,
    i.annual_service_cost_rupees,
    ROUND(i.annual_service_cost_rupees / NULLIF(i.units_count,0), 2),
    i.variance_severity
  FROM customer_site_equipment_inventory_r2764 i
  WHERE i.variance_severity IN ('high','critical')
  ORDER BY (i.annual_service_cost_rupees / NULLIF(i.units_count,0)) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rpc_r2764_site_cost_outliers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2764_site_cost_outliers() TO authenticated;

COMMIT;
