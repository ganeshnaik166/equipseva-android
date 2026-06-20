BEGIN;
-- Round 1394: Founder Public Market Intelligence
-- Competitor + market intel tracker for v0.6 Phase 9



-- =========================================================================
-- TABLE: founder_market_competitors
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_market_competitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_name text NOT NULL UNIQUE,
  competitor_kind text CHECK (competitor_kind IN (
    'direct_amc_competitor','adjacent_repair_shop','manufacturer_direct_service',
    'equipment_distributor','technology_platform','startup_pivot'
  )),
  primary_segment text CHECK (primary_segment IN (
    'amc_subscriptions','repair_marketplace','spare_parts','equipment_resale','training','other'
  )),
  founded_year int,
  headquarters_city text,
  headquarters_state text,
  employee_count_band text CHECK (employee_count_band IN (
    '1-10','11-50','51-200','201-500','501-1000','1001-5000','5000+','unknown'
  )),
  funding_status text CHECK (funding_status IN (
    'bootstrapped','seed','seriesA','seriesB','seriesC_plus','public','acquired','dead','unknown'
  )),
  total_funding_rupees numeric,
  market_share_estimate_pct numeric,
  competitive_threat_band text DEFAULT 'medium' CHECK (competitive_threat_band IN (
    'critical','high','medium','low','negligible'
  )),
  notes text,
  primary_source_url text,
  last_intel_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmc_threat ON public.founder_market_competitors(competitive_threat_band);
CREATE INDEX IF NOT EXISTS idx_fmc_kind ON public.founder_market_competitors(competitor_kind);
CREATE INDEX IF NOT EXISTS idx_fmc_last_intel ON public.founder_market_competitors(last_intel_at DESC NULLS LAST);

ALTER TABLE public.founder_market_competitors ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- TABLE: founder_market_pricing_snapshots
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_market_pricing_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id uuid REFERENCES public.founder_market_competitors(id) ON DELETE CASCADE,
  tier_label text NOT NULL,
  monthly_fee_rupees numeric,
  annual_fee_rupees numeric,
  observed_at timestamptz DEFAULT now(),
  source_url text,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmps_competitor ON public.founder_market_pricing_snapshots(competitor_id);
CREATE INDEX IF NOT EXISTS idx_fmps_observed ON public.founder_market_pricing_snapshots(observed_at DESC);

ALTER TABLE public.founder_market_pricing_snapshots ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- RPC: founder_public_market_intelligence_summary
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_public_market_intelligence_summary();

CREATE OR REPLACE FUNCTION public.founder_public_market_intelligence_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_direct_amc int;
  v_critical int;
  v_high int;
  v_medium int;
  v_low int;
  v_snapshots_total int;
  v_snapshots_30d int;
  v_avg_comp_fee numeric;
  v_our_avg_fee numeric;
  v_pricing_advantage_pct numeric;
  v_top_name text;
  v_top_amount numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_total FROM public.founder_market_competitors;
  SELECT count(*) INTO v_direct_amc FROM public.founder_market_competitors WHERE competitor_kind = 'direct_amc_competitor';
  SELECT count(*) INTO v_critical FROM public.founder_market_competitors WHERE competitive_threat_band = 'critical';
  SELECT count(*) INTO v_high FROM public.founder_market_competitors WHERE competitive_threat_band = 'high';
  SELECT count(*) INTO v_medium FROM public.founder_market_competitors WHERE competitive_threat_band = 'medium';
  SELECT count(*) INTO v_low FROM public.founder_market_competitors WHERE competitive_threat_band = 'low';

  SELECT count(*) INTO v_snapshots_total FROM public.founder_market_pricing_snapshots;
  SELECT count(*) INTO v_snapshots_30d FROM public.founder_market_pricing_snapshots
    WHERE observed_at >= now() - interval '30 days';

  SELECT avg(monthly_fee_rupees) INTO v_avg_comp_fee
    FROM public.founder_market_pricing_snapshots
    WHERE monthly_fee_rupees IS NOT NULL
      AND observed_at >= now() - interval '180 days';

  SELECT avg(monthly_fee_rupees) INTO v_our_avg_fee
    FROM public.amc_contracts
    WHERE status = 'active';

  IF v_avg_comp_fee IS NOT NULL AND v_avg_comp_fee > 0 AND v_our_avg_fee IS NOT NULL THEN
    v_pricing_advantage_pct := round(((v_avg_comp_fee - v_our_avg_fee) / v_avg_comp_fee) * 100.0, 2);
  ELSE
    v_pricing_advantage_pct := NULL;
  END IF;

  SELECT competitor_name, total_funding_rupees
    INTO v_top_name, v_top_amount
    FROM public.founder_market_competitors
    WHERE total_funding_rupees IS NOT NULL
    ORDER BY total_funding_rupees DESC NULLS LAST
    LIMIT 1;

  RETURN jsonb_build_object(
    'total_competitors', coalesce(v_total, 0),
    'direct_amc_competitor_count', coalesce(v_direct_amc, 0),
    'critical_threat_count', coalesce(v_critical, 0),
    'high_threat_count', coalesce(v_high, 0),
    'medium_threat_count', coalesce(v_medium, 0),
    'low_threat_count', coalesce(v_low, 0),
    'total_market_pricing_snapshots', coalesce(v_snapshots_total, 0),
    'pricing_snapshots_30d', coalesce(v_snapshots_30d, 0),
    'avg_competitor_monthly_fee_rupees', coalesce(v_avg_comp_fee, 0),
    'our_avg_monthly_fee_rupees', coalesce(v_our_avg_fee, 0),
    'pricing_advantage_pct', v_pricing_advantage_pct,
    'top_funded_competitor', coalesce(v_top_name, 'none'),
    'top_funded_amount_rupees', coalesce(v_top_amount, 0),
    'generated_at', now()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_public_market_intelligence_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_public_market_intelligence_summary() TO authenticated;

-- =========================================================================
-- RPC: founder_market_competitors_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_market_competitors_recent(text, int);

CREATE OR REPLACE FUNCTION public.founder_market_competitors_recent(
  p_threat_band text DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE(
  id uuid,
  competitor_name text,
  competitor_kind text,
  primary_segment text,
  founded_year int,
  headquarters_city text,
  headquarters_state text,
  employee_count_band text,
  funding_status text,
  total_funding_rupees numeric,
  market_share_estimate_pct numeric,
  competitive_threat_band text,
  primary_source_url text,
  last_intel_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id, c.competitor_name, c.competitor_kind, c.primary_segment,
    c.founded_year, c.headquarters_city, c.headquarters_state,
    c.employee_count_band, c.funding_status, c.total_funding_rupees,
    c.market_share_estimate_pct, c.competitive_threat_band,
    c.primary_source_url, c.last_intel_at, c.created_at
  FROM public.founder_market_competitors c
  WHERE (p_threat_band IS NULL OR c.competitive_threat_band = p_threat_band)
  ORDER BY
    CASE c.competitive_threat_band
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      WHEN 'negligible' THEN 5
      ELSE 6
    END,
    c.last_intel_at DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_market_competitors_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_market_competitors_recent(text, int) TO authenticated;

-- =========================================================================
-- RPC: founder_market_pricing_snapshots_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_market_pricing_snapshots_recent(uuid, int);

CREATE OR REPLACE FUNCTION public.founder_market_pricing_snapshots_recent(
  p_competitor_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE(
  id uuid,
  competitor_id uuid,
  competitor_name text,
  tier_label text,
  monthly_fee_rupees numeric,
  annual_fee_rupees numeric,
  observed_at timestamptz,
  source_url text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    s.id, s.competitor_id, c.competitor_name, s.tier_label,
    s.monthly_fee_rupees, s.annual_fee_rupees, s.observed_at, s.source_url
  FROM public.founder_market_pricing_snapshots s
  LEFT JOIN public.founder_market_competitors c ON c.id = s.competitor_id
  WHERE (p_competitor_id IS NULL OR s.competitor_id = p_competitor_id)
  ORDER BY s.observed_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_market_pricing_snapshots_recent(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_market_pricing_snapshots_recent(uuid, int) TO authenticated;

-- =========================================================================
-- WRITE-LAYER RPCs (founder logging hooks)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_market_register_competitor(text, text, text, text, text, numeric, text);

CREATE OR REPLACE FUNCTION public.log_founder_market_register_competitor(
  p_competitor_name text,
  p_competitor_kind text,
  p_primary_segment text,
  p_threat_band text DEFAULT 'medium',
  p_funding_status text DEFAULT 'unknown',
  p_total_funding_rupees numeric DEFAULT NULL,
  p_source_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_market_competitors (
    competitor_name, competitor_kind, primary_segment,
    competitive_threat_band, funding_status, total_funding_rupees,
    primary_source_url, last_intel_at
  ) VALUES (
    p_competitor_name, p_competitor_kind, p_primary_segment,
    p_threat_band, p_funding_status, p_total_funding_rupees,
    p_source_url, now()
  )
  ON CONFLICT (competitor_name) DO UPDATE
    SET competitive_threat_band = EXCLUDED.competitive_threat_band,
        funding_status = EXCLUDED.funding_status,
        total_funding_rupees = COALESCE(EXCLUDED.total_funding_rupees, public.founder_market_competitors.total_funding_rupees),
        last_intel_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_market_register_competitor(text, text, text, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_market_register_competitor(text, text, text, text, text, numeric, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_market_record_pricing_snapshot(uuid, text, numeric, numeric, text);

CREATE OR REPLACE FUNCTION public.log_founder_market_record_pricing_snapshot(
  p_competitor_id uuid,
  p_tier_label text,
  p_monthly_fee_rupees numeric DEFAULT NULL,
  p_annual_fee_rupees numeric DEFAULT NULL,
  p_source_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_market_pricing_snapshots (
    competitor_id, tier_label, monthly_fee_rupees, annual_fee_rupees, source_url
  ) VALUES (
    p_competitor_id, p_tier_label, p_monthly_fee_rupees, p_annual_fee_rupees, p_source_url
  ) RETURNING id INTO v_id;

  UPDATE public.founder_market_competitors
     SET last_intel_at = now(), updated_at = now()
   WHERE id = p_competitor_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_market_record_pricing_snapshot(uuid, text, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_market_record_pricing_snapshot(uuid, text, numeric, numeric, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_market_competitor_status(uuid, text, text);

CREATE OR REPLACE FUNCTION public.log_founder_market_competitor_status(
  p_competitor_id uuid,
  p_new_threat_band text,
  p_notes text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_market_competitors
     SET competitive_threat_band = p_new_threat_band,
         notes = COALESCE(p_notes, notes),
         last_intel_at = now(),
         updated_at = now()
   WHERE id = p_competitor_id;

  RETURN FOUND;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_market_competitor_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_market_competitor_status(uuid, text, text) TO authenticated;

COMMIT;