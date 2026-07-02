BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_amc_plan_catalog_r2236 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_tier text NOT NULL CHECK (plan_tier IN ('basic','standard','premium')),
  monthly_fee_rupees int NOT NULL CHECK (monthly_fee_rupees >= 0),
  visits_included_per_quarter int NOT NULL DEFAULT 0,
  response_sla_hours int NOT NULL DEFAULT 48,
  spare_discount_pct numeric(5,2) NOT NULL DEFAULT 0,
  priority_dispatch boolean NOT NULL DEFAULT false,
  free_calibration boolean NOT NULL DEFAULT false,
  twenty_four_seven_support boolean NOT NULL DEFAULT false,
  upsell_blurb text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_tier)
);

ALTER TABLE public.customer_amc_plan_catalog_r2236 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_amc_plan_catalog_r2236;
CREATE POLICY founder_all ON public.customer_amc_plan_catalog_r2236
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_amc_upsell_signals_r2236 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_tier text CHECK (current_tier IN ('none','basic','standard','premium')),
  target_tier text CHECK (target_tier IN ('basic','standard','premium')),
  monthly_uplift_rupees int NOT NULL DEFAULT 0,
  annual_uplift_rupees int NOT NULL DEFAULT 0,
  roi_payback_months numeric(6,2),
  signal_strength text CHECK (signal_strength IN ('weak','medium','strong','hot')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_amc_upsell_signals_r2236 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_amc_upsell_signals_r2236;
CREATE POLICY founder_all ON public.customer_amc_upsell_signals_r2236
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed catalog
INSERT INTO public.customer_amc_plan_catalog_r2236 (plan_tier, monthly_fee_rupees, visits_included_per_quarter, response_sla_hours, spare_discount_pct, priority_dispatch, free_calibration, twenty_four_seven_support, upsell_blurb)
VALUES
  ('basic', 1499, 1, 48, 5.00, false, false, false, 'Entry tier — preventive visits only'),
  ('standard', 2999, 2, 24, 10.00, true, false, false, 'Most popular — priority dispatch + 2 visits/quarter'),
  ('premium', 5999, 4, 6, 15.00, true, true, true, 'Mission-critical — 24x7 support + free calibration')
ON CONFLICT (plan_tier) DO NOTHING;

CREATE OR REPLACE FUNCTION public.founder_amc_plan_catalog_r2236()
RETURNS TABLE (
  plan_tier text,
  monthly_fee_rupees int,
  visits_included_per_quarter int,
  response_sla_hours int,
  spare_discount_pct numeric,
  priority_dispatch boolean,
  free_calibration boolean,
  twenty_four_seven_support boolean,
  upsell_blurb text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.plan_tier, c.monthly_fee_rupees, c.visits_included_per_quarter, c.response_sla_hours,
           c.spare_discount_pct, c.priority_dispatch, c.free_calibration, c.twenty_four_seven_support, c.upsell_blurb
    FROM public.customer_amc_plan_catalog_r2236 c
    ORDER BY c.monthly_fee_rupees ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_plan_catalog_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_plan_catalog_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_customer_distribution_r2236()
RETURNS TABLE (
  tier_label text,
  customer_count int,
  total_mrr_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COALESCE(ac.amc_tier, 'none')::text AS tier_label,
      (COUNT(*) FILTER (WHERE ac.id IS NOT NULL))::int AS customer_count,
      COALESCE(SUM(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0)::bigint AS total_mrr_rupees
    FROM public.amc_contracts ac
    GROUP BY ac.amc_tier
    ORDER BY total_mrr_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_customer_distribution_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_customer_distribution_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_upsell_candidates_r2236()
RETURNS TABLE (
  signal_id uuid,
  customer_email text,
  current_tier text,
  target_tier text,
  monthly_uplift_rupees int,
  annual_uplift_rupees int,
  roi_payback_months numeric,
  signal_strength text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, p.email::text, s.current_tier, s.target_tier,
           s.monthly_uplift_rupees, s.annual_uplift_rupees, s.roi_payback_months,
           s.signal_strength, s.created_at
    FROM public.customer_amc_upsell_signals_r2236 s
    LEFT JOIN public.profiles p ON p.id = s.customer_id
    ORDER BY s.signal_strength DESC NULLS LAST, s.annual_uplift_rupees DESC
    LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_upsell_candidates_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_upsell_candidates_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_plan_revenue_compare_r2236()
RETURNS TABLE (
  plan_tier text,
  active_customers int,
  monthly_revenue_rupees bigint,
  annual_revenue_rupees bigint,
  avg_fee_rupees int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      ac.amc_tier::text AS plan_tier,
      (COUNT(*) FILTER (WHERE ac.status = 'active'))::int AS active_customers,
      COALESCE(SUM(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0)::bigint AS monthly_revenue_rupees,
      (COALESCE(SUM(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0) * 12)::bigint AS annual_revenue_rupees,
      COALESCE(AVG(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0)::int AS avg_fee_rupees
    FROM public.amc_contracts ac
    WHERE ac.amc_tier IS NOT NULL
    GROUP BY ac.amc_tier
    ORDER BY monthly_revenue_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_plan_revenue_compare_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_plan_revenue_compare_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_upsell_roi_summary_r2236()
RETURNS TABLE (
  signal_strength text,
  candidate_count int,
  total_monthly_uplift bigint,
  total_annual_uplift bigint,
  avg_payback_months numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.signal_strength,
           (COUNT(*))::int AS candidate_count,
           COALESCE(SUM(s.monthly_uplift_rupees), 0)::bigint AS total_monthly_uplift,
           COALESCE(SUM(s.annual_uplift_rupees), 0)::bigint AS total_annual_uplift,
           COALESCE(AVG(s.roi_payback_months), 0)::numeric AS avg_payback_months
    FROM public.customer_amc_upsell_signals_r2236 s
    GROUP BY s.signal_strength
    ORDER BY total_annual_uplift DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_upsell_roi_summary_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_upsell_roi_summary_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_tier_migration_r2236()
RETURNS TABLE (
  from_tier text,
  to_tier text,
  migration_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(s.current_tier, 'none')::text AS from_tier,
           s.target_tier::text AS to_tier,
           (COUNT(*))::int AS migration_count
    FROM public.customer_amc_upsell_signals_r2236 s
    WHERE s.target_tier IS NOT NULL
    GROUP BY s.current_tier, s.target_tier
    ORDER BY migration_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_tier_migration_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_tier_migration_r2236() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_amc_plan_kpi_r2236()
RETURNS TABLE (
  total_active_amcs int,
  total_mrr_rupees bigint,
  total_arr_rupees bigint,
  hot_upsell_candidates int,
  potential_annual_uplift bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT (COUNT(*) FILTER (WHERE ac.status = 'active'))::int FROM public.amc_contracts ac) AS total_active_amcs,
      (SELECT COALESCE(SUM(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0)::bigint FROM public.amc_contracts ac) AS total_mrr_rupees,
      (SELECT (COALESCE(SUM(ac.monthly_fee_rupees) FILTER (WHERE ac.status = 'active'), 0) * 12)::bigint FROM public.amc_contracts ac) AS total_arr_rupees,
      (SELECT (COUNT(*) FILTER (WHERE s.signal_strength = 'hot'))::int FROM public.customer_amc_upsell_signals_r2236 s) AS hot_upsell_candidates,
      (SELECT COALESCE(SUM(s.annual_uplift_rupees), 0)::bigint FROM public.customer_amc_upsell_signals_r2236 s) AS potential_annual_uplift;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_amc_plan_kpi_r2236() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_amc_plan_kpi_r2236() TO authenticated;

COMMIT;
