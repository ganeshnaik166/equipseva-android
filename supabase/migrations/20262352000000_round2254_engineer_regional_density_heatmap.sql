BEGIN;

-- ============================================================
-- r2254: Engineer regional density heatmap
-- Track engineer count by city x pin code, demand vs supply ratio,
-- gaps to fill, hiring priority
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_regional_density_r2254 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city text NOT NULL,
  pin_code text NOT NULL CHECK (char_length(pin_code) = 6),
  region text NOT NULL CHECK (region IN ('north','south','east','west','central','northeast')),
  engineer_count int NOT NULL DEFAULT 0 CHECK (engineer_count >= 0),
  active_engineer_count int NOT NULL DEFAULT 0 CHECK (active_engineer_count >= 0),
  open_jobs_30d int NOT NULL DEFAULT 0 CHECK (open_jobs_30d >= 0),
  completed_jobs_30d int NOT NULL DEFAULT 0 CHECK (completed_jobs_30d >= 0),
  avg_response_time_hours numeric(6,2),
  demand_supply_ratio numeric(6,2) NOT NULL DEFAULT 0,
  density_tier text NOT NULL CHECK (density_tier IN ('saturated','healthy','thin','critical_gap','no_coverage')),
  hiring_priority text NOT NULL CHECK (hiring_priority IN ('p0','p1','p2','p3','none')),
  hospitals_count int NOT NULL DEFAULT 0 CHECK (hospitals_count >= 0),
  notes text,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(city, pin_code, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_erd_r2254_city ON public.engineer_regional_density_r2254(city);
CREATE INDEX IF NOT EXISTS idx_erd_r2254_pin ON public.engineer_regional_density_r2254(pin_code);
CREATE INDEX IF NOT EXISTS idx_erd_r2254_priority ON public.engineer_regional_density_r2254(hiring_priority);
CREATE INDEX IF NOT EXISTS idx_erd_r2254_tier ON public.engineer_regional_density_r2254(density_tier);

ALTER TABLE public.engineer_regional_density_r2254 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS erd_r2254_founder_all ON public.engineer_regional_density_r2254;
CREATE POLICY erd_r2254_founder_all ON public.engineer_regional_density_r2254
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_hiring_targets_r2254 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city text NOT NULL,
  pin_code text NOT NULL CHECK (char_length(pin_code) = 6),
  region text NOT NULL CHECK (region IN ('north','south','east','west','central','northeast')),
  target_engineer_count int NOT NULL CHECK (target_engineer_count >= 0),
  current_engineer_count int NOT NULL DEFAULT 0 CHECK (current_engineer_count >= 0),
  gap_to_fill int NOT NULL DEFAULT 0,
  target_quarter text NOT NULL CHECK (target_quarter IN ('q1_2026','q2_2026','q3_2026','q4_2026','q1_2027')),
  status text NOT NULL CHECK (status IN ('planned','recruiting','interviewing','onboarding','hit_target','dropped')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  monthly_burn_estimate_rupees numeric(12,2) NOT NULL DEFAULT 0,
  rationale text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(city, pin_code, target_quarter)
);

CREATE INDEX IF NOT EXISTS idx_eht_r2254_city ON public.engineer_hiring_targets_r2254(city);
CREATE INDEX IF NOT EXISTS idx_eht_r2254_status ON public.engineer_hiring_targets_r2254(status);
CREATE INDEX IF NOT EXISTS idx_eht_r2254_quarter ON public.engineer_hiring_targets_r2254(target_quarter);

ALTER TABLE public.engineer_hiring_targets_r2254 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eht_r2254_founder_all ON public.engineer_hiring_targets_r2254;
CREATE POLICY eht_r2254_founder_all ON public.engineer_hiring_targets_r2254
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seed sample data
-- ============================================================

INSERT INTO public.engineer_regional_density_r2254
  (city, pin_code, region, engineer_count, active_engineer_count, open_jobs_30d, completed_jobs_30d, avg_response_time_hours, demand_supply_ratio, density_tier, hiring_priority, hospitals_count, notes)
VALUES
  ('Hyderabad','500032','south', 12, 11, 78, 65, 3.2, 6.50, 'healthy', 'p2', 18, 'Madhapur cluster - strong density'),
  ('Hyderabad','500081','south', 8, 7, 52, 41, 4.1, 6.50, 'healthy', 'p2', 12, 'Gachibowli IT corridor'),
  ('Hyderabad','500001','south', 3, 2, 38, 18, 9.5, 12.67, 'critical_gap', 'p0', 14, 'Old city - low coverage'),
  ('Bengaluru','560001','south', 14, 13, 92, 78, 2.8, 6.57, 'healthy', 'p2', 22, 'MG Road / central'),
  ('Bengaluru','560066','south', 6, 5, 64, 41, 5.2, 10.67, 'thin', 'p1', 16, 'Whitefield - growing demand'),
  ('Bengaluru','560100','south', 2, 2, 41, 14, 11.0, 20.50, 'critical_gap', 'p0', 11, 'Electronic City - urgent'),
  ('Mumbai','400001','west', 15, 14, 102, 89, 2.5, 6.80, 'healthy', 'p2', 25, 'Fort / South Mumbai'),
  ('Mumbai','400076','west', 4, 4, 58, 32, 6.8, 14.50, 'thin', 'p1', 15, 'Powai - hospital chain demand'),
  ('Mumbai','400706','west', 1, 1, 28, 8, 14.5, 28.00, 'critical_gap', 'p0', 9, 'Navi Mumbai - underserved'),
  ('Delhi','110001','north', 11, 10, 84, 71, 3.5, 7.64, 'healthy', 'p2', 19, 'Connaught Place'),
  ('Delhi','110085','north', 5, 4, 47, 28, 6.2, 9.40, 'thin', 'p1', 13, 'Rohini - moderate gap'),
  ('Delhi','201301','north', 0, 0, 22, 0, NULL, 22.00, 'no_coverage', 'p0', 8, 'Noida sector 1 - zero engineers'),
  ('Chennai','600001','south', 9, 8, 61, 52, 3.8, 6.78, 'healthy', 'p2', 14, 'Parrys Corner'),
  ('Chennai','600040','south', 3, 3, 42, 22, 8.5, 14.00, 'critical_gap', 'p0', 11, 'Anna Nagar - growth area'),
  ('Pune','411001','west', 7, 6, 58, 44, 4.2, 8.29, 'thin', 'p1', 13, 'Camp area'),
  ('Pune','411014','west', 4, 4, 51, 32, 6.0, 12.75, 'critical_gap', 'p0', 12, 'Hinjewadi - IT boom'),
  ('Kolkata','700001','east', 6, 5, 44, 33, 5.5, 7.33, 'thin', 'p1', 11, 'BBD Bagh'),
  ('Kolkata','700091','east', 1, 1, 31, 9, 13.0, 31.00, 'critical_gap', 'p0', 8, 'Salt Lake - urgent hiring'),
  ('Ahmedabad','380001','west', 5, 5, 41, 31, 5.8, 8.20, 'thin', 'p1', 9, 'Ellis Bridge area'),
  ('Jaipur','302001','north', 4, 3, 35, 22, 7.2, 8.75, 'thin', 'p1', 8, 'Civil Lines'),
  ('Lucknow','226001','central', 3, 2, 28, 16, 9.0, 9.33, 'thin', 'p1', 7, 'Hazratganj'),
  ('Indore','452001','central', 2, 2, 19, 11, 10.5, 9.50, 'thin', 'p2', 6, 'Vijay Nagar'),
  ('Bhopal','462001','central', 1, 1, 14, 5, 16.0, 14.00, 'critical_gap', 'p0', 5, 'New Market'),
  ('Visakhapatnam','530001','south', 2, 2, 22, 12, 11.0, 11.00, 'thin', 'p1', 6, 'Daba Gardens'),
  ('Coimbatore','641001','south', 3, 3, 28, 19, 8.5, 9.33, 'thin', 'p2', 7, 'RS Puram'),
  ('Guwahati','781001','northeast', 0, 0, 18, 0, NULL, 18.00, 'no_coverage', 'p0', 6, 'Pan Bazaar - greenfield'),
  ('Hyderabad','500016','south', 22, 20, 145, 132, 2.1, 6.59, 'saturated', 'none', 28, 'Banjara Hills - oversupply')
ON CONFLICT (city, pin_code, snapshot_at) DO NOTHING;

INSERT INTO public.engineer_hiring_targets_r2254
  (city, pin_code, region, target_engineer_count, current_engineer_count, gap_to_fill, target_quarter, status, monthly_burn_estimate_rupees, rationale)
VALUES
  ('Bengaluru','560100','south', 8, 2, 6, 'q3_2026','recruiting', 540000, 'Electronic City demand 41 open jobs vs 2 engineers'),
  ('Mumbai','400706','west', 6, 1, 5, 'q3_2026','recruiting', 475000, 'Navi Mumbai - hospital chain MoU pending'),
  ('Delhi','201301','north', 5, 0, 5, 'q3_2026','planned', 400000, 'Noida sector 1 - zero coverage, blue ocean'),
  ('Hyderabad','500001','south', 6, 3, 3, 'q3_2026','interviewing', 250000, 'Old city - 3 hires sourced'),
  ('Chennai','600040','south', 7, 3, 4, 'q4_2026','planned', 320000, 'Anna Nagar growth'),
  ('Pune','411014','west', 8, 4, 4, 'q3_2026','onboarding', 340000, 'Hinjewadi - 4 engineers in onboarding'),
  ('Kolkata','700091','east', 5, 1, 4, 'q4_2026','recruiting', 280000, 'Salt Lake - 13x ratio'),
  ('Guwahati','781001','northeast', 4, 0, 4, 'q4_2026','planned', 320000, 'Northeast greenfield expansion'),
  ('Bhopal','462001','central', 3, 1, 2, 'q4_2026','planned', 170000, 'Tier-2 expansion'),
  ('Bengaluru','560066','south', 10, 6, 4, 'q3_2026','interviewing', 280000, 'Whitefield IT corridor')
ON CONFLICT (city, pin_code, target_quarter) DO NOTHING;

-- ============================================================
-- RPCs (7) — all founder-gated
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_engineer_regional_heatmap_r2254()
RETURNS TABLE (
  city text,
  pin_code text,
  region text,
  engineer_count int,
  active_engineer_count int,
  open_jobs_30d int,
  completed_jobs_30d int,
  demand_supply_ratio numeric,
  density_tier text,
  hiring_priority text,
  hospitals_count int,
  avg_response_time_hours numeric,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.city, e.pin_code, e.region, e.engineer_count, e.active_engineer_count,
         e.open_jobs_30d, e.completed_jobs_30d, e.demand_supply_ratio,
         e.density_tier, e.hiring_priority, e.hospitals_count,
         e.avg_response_time_hours, e.notes
  FROM public.engineer_regional_density_r2254 e
  ORDER BY
    CASE e.hiring_priority WHEN 'p0' THEN 1 WHEN 'p1' THEN 2 WHEN 'p2' THEN 3 WHEN 'p3' THEN 4 ELSE 5 END,
    e.demand_supply_ratio DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_engineer_regional_heatmap_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_engineer_regional_heatmap_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_city_density_rollup_r2254()
RETURNS TABLE (
  city text,
  region text,
  pin_codes_tracked int,
  total_engineers int,
  total_active_engineers int,
  total_open_jobs_30d int,
  total_completed_jobs_30d int,
  city_demand_supply_ratio numeric,
  critical_gap_pins int,
  no_coverage_pins int,
  hospitals_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.city,
    MAX(e.region),
    COUNT(*)::int,
    SUM(e.engineer_count)::int,
    SUM(e.active_engineer_count)::int,
    SUM(e.open_jobs_30d)::int,
    SUM(e.completed_jobs_30d)::int,
    ROUND(SUM(e.open_jobs_30d)::numeric / NULLIF(SUM(e.engineer_count), 0), 2),
    (COUNT(*) FILTER (WHERE e.density_tier = 'critical_gap'))::int,
    (COUNT(*) FILTER (WHERE e.density_tier = 'no_coverage'))::int,
    SUM(e.hospitals_count)::int
  FROM public.engineer_regional_density_r2254 e
  GROUP BY e.city
  ORDER BY SUM(e.open_jobs_30d) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_density_rollup_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_city_density_rollup_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_critical_gap_pins_r2254()
RETURNS TABLE (
  city text,
  pin_code text,
  region text,
  engineer_count int,
  open_jobs_30d int,
  demand_supply_ratio numeric,
  density_tier text,
  hospitals_count int,
  avg_response_time_hours numeric,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.city, e.pin_code, e.region, e.engineer_count, e.open_jobs_30d,
         e.demand_supply_ratio, e.density_tier, e.hospitals_count,
         e.avg_response_time_hours, e.notes
  FROM public.engineer_regional_density_r2254 e
  WHERE e.density_tier IN ('critical_gap','no_coverage')
  ORDER BY e.demand_supply_ratio DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_critical_gap_pins_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_critical_gap_pins_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_hiring_targets_pipeline_r2254()
RETURNS TABLE (
  city text,
  pin_code text,
  region text,
  target_engineer_count int,
  current_engineer_count int,
  gap_to_fill int,
  target_quarter text,
  status text,
  monthly_burn_estimate_rupees numeric,
  owner_email text,
  rationale text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.city, h.pin_code, h.region, h.target_engineer_count, h.current_engineer_count,
         h.gap_to_fill, h.target_quarter, h.status,
         h.monthly_burn_estimate_rupees, p.email, h.rationale
  FROM public.engineer_hiring_targets_r2254 h
  LEFT JOIN public.profiles p ON p.id = h.owner_user_id
  ORDER BY
    CASE h.status
      WHEN 'recruiting' THEN 1
      WHEN 'interviewing' THEN 2
      WHEN 'onboarding' THEN 3
      WHEN 'planned' THEN 4
      WHEN 'hit_target' THEN 5
      ELSE 6
    END,
    h.gap_to_fill DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_hiring_targets_pipeline_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_hiring_targets_pipeline_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_region_supply_breakdown_r2254()
RETURNS TABLE (
  region text,
  pin_codes_tracked int,
  total_engineers int,
  total_open_jobs_30d int,
  region_demand_supply_ratio numeric,
  saturated_pins int,
  healthy_pins int,
  thin_pins int,
  critical_gap_pins int,
  no_coverage_pins int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.region,
    COUNT(*)::int,
    SUM(e.engineer_count)::int,
    SUM(e.open_jobs_30d)::int,
    ROUND(SUM(e.open_jobs_30d)::numeric / NULLIF(SUM(e.engineer_count), 0), 2),
    (COUNT(*) FILTER (WHERE e.density_tier = 'saturated'))::int,
    (COUNT(*) FILTER (WHERE e.density_tier = 'healthy'))::int,
    (COUNT(*) FILTER (WHERE e.density_tier = 'thin'))::int,
    (COUNT(*) FILTER (WHERE e.density_tier = 'critical_gap'))::int,
    (COUNT(*) FILTER (WHERE e.density_tier = 'no_coverage'))::int
  FROM public.engineer_regional_density_r2254 e
  GROUP BY e.region
  ORDER BY SUM(e.open_jobs_30d) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_region_supply_breakdown_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_region_supply_breakdown_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_saturated_zones_r2254()
RETURNS TABLE (
  city text,
  pin_code text,
  region text,
  engineer_count int,
  open_jobs_30d int,
  demand_supply_ratio numeric,
  avg_response_time_hours numeric,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.city, e.pin_code, e.region, e.engineer_count, e.open_jobs_30d,
         e.demand_supply_ratio, e.avg_response_time_hours, e.notes
  FROM public.engineer_regional_density_r2254 e
  WHERE e.density_tier = 'saturated'
  ORDER BY e.engineer_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_saturated_zones_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_saturated_zones_r2254() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_regional_density_kpis_r2254()
RETURNS TABLE (
  total_pin_codes_tracked int,
  total_cities int,
  total_engineers int,
  total_active_engineers int,
  total_open_jobs_30d int,
  overall_demand_supply_ratio numeric,
  critical_gap_pins int,
  no_coverage_pins int,
  p0_hiring_targets int,
  total_gap_to_fill int,
  monthly_burn_estimate_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_regional_density_r2254),
    (SELECT COUNT(DISTINCT city)::int FROM public.engineer_regional_density_r2254),
    (SELECT COALESCE(SUM(engineer_count),0)::int FROM public.engineer_regional_density_r2254),
    (SELECT COALESCE(SUM(active_engineer_count),0)::int FROM public.engineer_regional_density_r2254),
    (SELECT COALESCE(SUM(open_jobs_30d),0)::int FROM public.engineer_regional_density_r2254),
    (SELECT ROUND(SUM(open_jobs_30d)::numeric / NULLIF(SUM(engineer_count), 0), 2) FROM public.engineer_regional_density_r2254),
    (SELECT (COUNT(*) FILTER (WHERE density_tier = 'critical_gap'))::int FROM public.engineer_regional_density_r2254),
    (SELECT (COUNT(*) FILTER (WHERE density_tier = 'no_coverage'))::int FROM public.engineer_regional_density_r2254),
    (SELECT (COUNT(*) FILTER (WHERE hiring_priority = 'p0'))::int FROM public.engineer_regional_density_r2254),
    (SELECT COALESCE(SUM(gap_to_fill),0)::int FROM public.engineer_hiring_targets_r2254 WHERE status NOT IN ('hit_target','dropped')),
    (SELECT COALESCE(SUM(monthly_burn_estimate_rupees),0) FROM public.engineer_hiring_targets_r2254 WHERE status NOT IN ('hit_target','dropped'));
END;
$$;

REVOKE ALL ON FUNCTION public.get_regional_density_kpis_r2254() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_regional_density_kpis_r2254() TO authenticated;

COMMIT;
