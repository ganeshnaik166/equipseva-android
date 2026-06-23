BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_referral_sources_r2395 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name text NOT NULL,
  source_category text NOT NULL CHECK (source_category IN ('direct_outbound','partner_referral','conference_event','digital_ad','organic_inbound','existing_customer_referral','consultant_intro','government_tender')),
  channel_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cost_to_acquire_rupees bigint NOT NULL DEFAULT 0,
  spend_period_start date,
  spend_period_end date,
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_referral_attributions_r2395 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  chain_name text,
  source_id uuid NOT NULL REFERENCES public.hospital_referral_sources_r2395(id) ON DELETE CASCADE,
  signup_date date NOT NULL,
  first_revenue_date date,
  ltv_to_date_rupees bigint NOT NULL DEFAULT 0,
  amc_contracts_signed integer NOT NULL DEFAULT 0,
  beds_count integer,
  city text,
  attributed_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  attribution_confidence text NOT NULL DEFAULT 'high' CHECK (attribution_confidence IN ('high','medium','low','assumed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrs_r2395_category ON public.hospital_referral_sources_r2395(source_category);
CREATE INDEX IF NOT EXISTS idx_hrs_r2395_active ON public.hospital_referral_sources_r2395(is_active);
CREATE INDEX IF NOT EXISTS idx_hra_r2395_source ON public.hospital_referral_attributions_r2395(source_id);
CREATE INDEX IF NOT EXISTS idx_hra_r2395_signup ON public.hospital_referral_attributions_r2395(signup_date DESC);
CREATE INDEX IF NOT EXISTS idx_hra_r2395_chain ON public.hospital_referral_attributions_r2395(chain_name);

ALTER TABLE public.hospital_referral_sources_r2395 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_referral_attributions_r2395 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_referral_sources_r2395;
CREATE POLICY founder_all ON public.hospital_referral_sources_r2395 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_referral_attributions_r2395;
CREATE POLICY founder_all ON public.hospital_referral_attributions_r2395 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2395_source_roi_summary()
RETURNS TABLE (
  source_id uuid,
  source_name text,
  source_category text,
  hospitals_signed bigint,
  total_ltv_rupees bigint,
  total_cost_rupees bigint,
  roi_multiple numeric,
  cost_per_hospital_rupees numeric,
  avg_ltv_per_hospital_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.source_name, s.source_category,
    COUNT(a.id)::bigint AS hospitals_signed,
    COALESCE(SUM(a.ltv_to_date_rupees),0)::bigint AS total_ltv_rupees,
    s.cost_to_acquire_rupees AS total_cost_rupees,
    CASE WHEN s.cost_to_acquire_rupees > 0
         THEN ROUND(COALESCE(SUM(a.ltv_to_date_rupees),0)::numeric / s.cost_to_acquire_rupees, 2)
         ELSE NULL END AS roi_multiple,
    CASE WHEN COUNT(a.id) > 0
         THEN ROUND(s.cost_to_acquire_rupees::numeric / COUNT(a.id), 0)
         ELSE NULL END AS cost_per_hospital_rupees,
    CASE WHEN COUNT(a.id) > 0
         THEN ROUND(COALESCE(SUM(a.ltv_to_date_rupees),0)::numeric / COUNT(a.id), 0)
         ELSE NULL END AS avg_ltv_per_hospital_rupees
  FROM public.hospital_referral_sources_r2395 s
  LEFT JOIN public.hospital_referral_attributions_r2395 a ON a.source_id = s.id
  GROUP BY s.id, s.source_name, s.source_category, s.cost_to_acquire_rupees
  ORDER BY total_ltv_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_recent_attributions(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  chain_name text,
  source_name text,
  source_category text,
  signup_date date,
  ltv_to_date_rupees bigint,
  amc_contracts_signed integer,
  beds_count integer,
  city text,
  attribution_confidence text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_name, a.chain_name, s.source_name, s.source_category,
    a.signup_date, a.ltv_to_date_rupees, a.amc_contracts_signed, a.beds_count,
    a.city, a.attribution_confidence
  FROM public.hospital_referral_attributions_r2395 a
  JOIN public.hospital_referral_sources_r2395 s ON s.id = a.source_id
  ORDER BY a.signup_date DESC
  LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_category_rollup()
RETURNS TABLE (
  source_category text,
  source_count bigint,
  hospitals_signed bigint,
  total_cost_rupees bigint,
  total_ltv_rupees bigint,
  blended_roi numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.source_category,
    COUNT(DISTINCT s.id)::bigint AS source_count,
    COUNT(a.id)::bigint AS hospitals_signed,
    COALESCE(SUM(s.cost_to_acquire_rupees),0)::bigint AS total_cost_rupees,
    COALESCE(SUM(a.ltv_to_date_rupees),0)::bigint AS total_ltv_rupees,
    CASE WHEN COALESCE(SUM(s.cost_to_acquire_rupees),0) > 0
         THEN ROUND(COALESCE(SUM(a.ltv_to_date_rupees),0)::numeric / SUM(s.cost_to_acquire_rupees), 2)
         ELSE NULL END AS blended_roi
  FROM public.hospital_referral_sources_r2395 s
  LEFT JOIN public.hospital_referral_attributions_r2395 a ON a.source_id = s.id
  GROUP BY s.source_category
  ORDER BY total_ltv_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_monthly_signups(p_months integer DEFAULT 12)
RETURNS TABLE (
  month_start date,
  signups bigint,
  total_ltv_rupees bigint,
  avg_beds numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', a.signup_date)::date AS month_start,
    COUNT(*)::bigint AS signups,
    COALESCE(SUM(a.ltv_to_date_rupees),0)::bigint AS total_ltv_rupees,
    ROUND(AVG(a.beds_count)::numeric, 0) AS avg_beds
  FROM public.hospital_referral_attributions_r2395 a
  WHERE a.signup_date >= (CURRENT_DATE - (p_months || ' months')::interval)
  GROUP BY 1
  ORDER BY 1 DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_top_chains()
RETURNS TABLE (
  chain_name text,
  hospitals_in_chain bigint,
  total_ltv_rupees bigint,
  total_beds bigint,
  dominant_source text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH chain_src AS (
    SELECT a.chain_name, s.source_name,
      ROW_NUMBER() OVER (PARTITION BY a.chain_name ORDER BY COUNT(*) DESC) AS rn,
      COUNT(*) AS cnt
    FROM public.hospital_referral_attributions_r2395 a
    JOIN public.hospital_referral_sources_r2395 s ON s.id = a.source_id
    WHERE a.chain_name IS NOT NULL
    GROUP BY a.chain_name, s.source_name
  )
  SELECT a.chain_name,
    COUNT(*)::bigint AS hospitals_in_chain,
    COALESCE(SUM(a.ltv_to_date_rupees),0)::bigint AS total_ltv_rupees,
    COALESCE(SUM(a.beds_count),0)::bigint AS total_beds,
    (SELECT cs.source_name FROM chain_src cs WHERE cs.chain_name = a.chain_name AND cs.rn = 1) AS dominant_source
  FROM public.hospital_referral_attributions_r2395 a
  WHERE a.chain_name IS NOT NULL
  GROUP BY a.chain_name
  ORDER BY total_ltv_rupees DESC
  LIMIT 25;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_kpis()
RETURNS TABLE (
  total_sources bigint,
  active_sources bigint,
  total_hospitals bigint,
  total_marketing_spend_rupees bigint,
  total_ltv_rupees bigint,
  blended_cac_rupees numeric,
  blended_roi numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_referral_sources_r2395)::bigint,
    (SELECT COUNT(*) FROM public.hospital_referral_sources_r2395 WHERE is_active)::bigint,
    (SELECT COUNT(*) FROM public.hospital_referral_attributions_r2395)::bigint,
    (SELECT COALESCE(SUM(cost_to_acquire_rupees),0) FROM public.hospital_referral_sources_r2395)::bigint,
    (SELECT COALESCE(SUM(ltv_to_date_rupees),0) FROM public.hospital_referral_attributions_r2395)::bigint,
    CASE WHEN (SELECT COUNT(*) FROM public.hospital_referral_attributions_r2395) > 0
         THEN ROUND((SELECT COALESCE(SUM(cost_to_acquire_rupees),0) FROM public.hospital_referral_sources_r2395)::numeric
                    / (SELECT COUNT(*) FROM public.hospital_referral_attributions_r2395), 0)
         ELSE NULL END,
    CASE WHEN (SELECT COALESCE(SUM(cost_to_acquire_rupees),0) FROM public.hospital_referral_sources_r2395) > 0
         THEN ROUND((SELECT COALESCE(SUM(ltv_to_date_rupees),0) FROM public.hospital_referral_attributions_r2395)::numeric
                    / (SELECT SUM(cost_to_acquire_rupees) FROM public.hospital_referral_sources_r2395), 2)
         ELSE NULL END;
END $$;

CREATE OR REPLACE FUNCTION public.r2395_low_confidence_attributions()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  source_name text,
  signup_date date,
  attribution_confidence text,
  ltv_to_date_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_name, s.source_name, a.signup_date, a.attribution_confidence, a.ltv_to_date_rupees
  FROM public.hospital_referral_attributions_r2395 a
  JOIN public.hospital_referral_sources_r2395 s ON s.id = a.source_id
  WHERE a.attribution_confidence IN ('low','assumed')
  ORDER BY a.ltv_to_date_rupees DESC
  LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.r2395_source_roi_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_recent_attributions(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_category_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_monthly_signups(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_top_chains() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2395_low_confidence_attributions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2395_source_roi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_recent_attributions(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_category_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_monthly_signups(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_top_chains() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2395_low_confidence_attributions() TO authenticated;

COMMIT;
