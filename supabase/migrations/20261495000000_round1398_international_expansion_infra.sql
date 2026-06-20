BEGIN;
-- round1398_international_expansion_infra.sql
-- International Expansion infrastructure (v0.6 Phase 10)
-- 3 tables + 7 RPCs for tracking cross-border expansion (LK, BD, NP, ...)



-- ============================================================================
-- TABLE 1: founder_international_countries
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_international_countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code text NOT NULL UNIQUE,
  country_name text NOT NULL,
  currency_code text NOT NULL,
  expansion_status text NOT NULL DEFAULT 'researching'
    CHECK (expansion_status IN ('researching','market_validation','partner_signed','pilot','active','paused','exited')),
  timezone_offset_minutes int,
  regulatory_burden_band text
    CHECK (regulatory_burden_band IN ('low','medium','high','very_high')),
  estimated_market_size_rupees numeric DEFAULT 0,
  estimated_total_addressable_hospitals int DEFAULT 0,
  local_partner_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  entered_at timestamptz,
  activated_at timestamptz,
  paused_at timestamptz,
  exited_at timestamptz,
  regulatory_notes text,
  market_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intl_countries_status
  ON public.founder_international_countries(expansion_status);
CREATE INDEX IF NOT EXISTS idx_intl_countries_currency
  ON public.founder_international_countries(currency_code);

ALTER TABLE public.founder_international_countries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_intl_countries_founder_all ON public.founder_international_countries;
CREATE POLICY p_intl_countries_founder_all ON public.founder_international_countries
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: founder_international_currencies
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_international_currencies (
  currency_code text PRIMARY KEY,
  currency_label text,
  exchange_rate_inr numeric NOT NULL,
  exchange_rate_source text NOT NULL DEFAULT 'manual'
    CHECK (exchange_rate_source IN ('manual','rbi','oanda','xe','fixer','bloomberg')),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true
);

ALTER TABLE public.founder_international_currencies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_intl_currencies_founder_all ON public.founder_international_currencies;
CREATE POLICY p_intl_currencies_founder_all ON public.founder_international_currencies
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 3: founder_international_milestones
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_international_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid REFERENCES public.founder_international_countries(id) ON DELETE CASCADE,
  milestone_kind text NOT NULL
    CHECK (milestone_kind IN ('first_visit','regulatory_clarity','local_entity_formed','first_partner_signed','first_engineer_recruited','first_hospital_signed','first_revenue','crossed_break_even','pause_decision','exit_decision')),
  description text,
  value_rupees numeric DEFAULT 0,
  achieved_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intl_milestones_country
  ON public.founder_international_milestones(country_id, achieved_at DESC);
CREATE INDEX IF NOT EXISTS idx_intl_milestones_kind
  ON public.founder_international_milestones(milestone_kind);

ALTER TABLE public.founder_international_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_intl_milestones_founder_all ON public.founder_international_milestones;
CREATE POLICY p_intl_milestones_founder_all ON public.founder_international_milestones
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA: 3 default countries + 3 currencies
-- ============================================================================
INSERT INTO public.founder_international_currencies (currency_code, currency_label, exchange_rate_inr, exchange_rate_source)
VALUES
  ('LKR', 'Sri Lankan Rupee', 0.28, 'manual'),
  ('BDT', 'Bangladeshi Taka', 0.78, 'manual'),
  ('NPR', 'Nepalese Rupee', 0.62, 'manual')
ON CONFLICT (currency_code) DO NOTHING;

INSERT INTO public.founder_international_countries
  (country_code, country_name, currency_code, expansion_status, timezone_offset_minutes, regulatory_burden_band, estimated_market_size_rupees, estimated_total_addressable_hospitals, regulatory_notes, market_notes)
VALUES
  ('LK', 'Sri Lanka', 'LKR', 'researching', 330, 'low', 8500000000, 380, 'Ministry of Health registration required; medical device import via NMRA.', 'Strong English usage; Colombo + Kandy tier-1 hospital cluster.'),
  ('BD', 'Bangladesh', 'BDT', 'researching', 360, 'medium', 24000000000, 1200, 'DGDA approval required for medical devices; local entity recommended.', 'Dhaka + Chittagong dominate; price-sensitive market.'),
  ('NP', 'Nepal', 'NPR', 'researching', 345, 'low', 4200000000, 210, 'Department of Drug Administration; lighter touch than BD.', 'Kathmandu valley = 60% of TAM; mountainous logistics constraints.')
ON CONFLICT (country_code) DO NOTHING;

-- ============================================================================
-- RPC 1: founder_international_expansion_summary — 14 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_international_expansion_summary();
CREATE OR REPLACE FUNCTION public.founder_international_expansion_summary()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_countries int;
  v_researching int;
  v_market_validation int;
  v_partner_signed int;
  v_pilot int;
  v_active int;
  v_paused int;
  v_exited int;
  v_total_tam_inr numeric;
  v_total_hospitals int;
  v_active_currencies int;
  v_milestones_30d int;
  v_milestones_all int;
  v_revenue_milestones_value numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_total_countries FROM public.founder_international_countries;
  SELECT count(*) INTO v_researching FROM public.founder_international_countries WHERE expansion_status='researching';
  SELECT count(*) INTO v_market_validation FROM public.founder_international_countries WHERE expansion_status='market_validation';
  SELECT count(*) INTO v_partner_signed FROM public.founder_international_countries WHERE expansion_status='partner_signed';
  SELECT count(*) INTO v_pilot FROM public.founder_international_countries WHERE expansion_status='pilot';
  SELECT count(*) INTO v_active FROM public.founder_international_countries WHERE expansion_status='active';
  SELECT count(*) INTO v_paused FROM public.founder_international_countries WHERE expansion_status='paused';
  SELECT count(*) INTO v_exited FROM public.founder_international_countries WHERE expansion_status='exited';
  SELECT coalesce(sum(estimated_market_size_rupees),0) INTO v_total_tam_inr FROM public.founder_international_countries WHERE expansion_status NOT IN ('exited','paused');
  SELECT coalesce(sum(estimated_total_addressable_hospitals),0) INTO v_total_hospitals FROM public.founder_international_countries WHERE expansion_status NOT IN ('exited','paused');
  SELECT count(*) INTO v_active_currencies FROM public.founder_international_currencies WHERE is_active=true;
  SELECT count(*) INTO v_milestones_30d FROM public.founder_international_milestones WHERE achieved_at > now() - interval '30 days';
  SELECT count(*) INTO v_milestones_all FROM public.founder_international_milestones;
  SELECT coalesce(sum(value_rupees),0) INTO v_revenue_milestones_value FROM public.founder_international_milestones WHERE milestone_kind='first_revenue';

  RETURN jsonb_build_object(
    'total_countries', v_total_countries,
    'researching', v_researching,
    'market_validation', v_market_validation,
    'partner_signed', v_partner_signed,
    'pilot', v_pilot,
    'active', v_active,
    'paused', v_paused,
    'exited', v_exited,
    'total_tam_inr', v_total_tam_inr,
    'total_addressable_hospitals', v_total_hospitals,
    'active_currencies', v_active_currencies,
    'milestones_30d', v_milestones_30d,
    'milestones_all', v_milestones_all,
    'revenue_milestones_value_inr', v_revenue_milestones_value
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_international_expansion_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_international_expansion_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_international_countries_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_international_countries_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_international_countries_recent(p_status text DEFAULT NULL, p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  country_code text,
  country_name text,
  currency_code text,
  expansion_status text,
  regulatory_burden_band text,
  estimated_market_size_rupees numeric,
  estimated_total_addressable_hospitals int,
  entered_at timestamptz,
  activated_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT c.id, c.country_code, c.country_name, c.currency_code, c.expansion_status,
         c.regulatory_burden_band, c.estimated_market_size_rupees, c.estimated_total_addressable_hospitals,
         c.entered_at, c.activated_at, c.created_at
  FROM public.founder_international_countries c
  WHERE (p_status IS NULL OR c.expansion_status = p_status)
  ORDER BY c.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_international_countries_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_international_countries_recent(text, int) TO authenticated;

-- ============================================================================
-- RPC 3: founder_international_milestones_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_international_milestones_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_international_milestones_recent(p_country_id uuid DEFAULT NULL, p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  country_id uuid,
  country_code text,
  country_name text,
  milestone_kind text,
  description text,
  value_rupees numeric,
  achieved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT m.id, m.country_id, c.country_code, c.country_name, m.milestone_kind,
         m.description, m.value_rupees, m.achieved_at
  FROM public.founder_international_milestones m
  LEFT JOIN public.founder_international_countries c ON c.id = m.country_id
  WHERE (p_country_id IS NULL OR m.country_id = p_country_id)
  ORDER BY m.achieved_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 25), 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_international_milestones_recent(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_international_milestones_recent(uuid, int) TO authenticated;

-- ============================================================================
-- RPC 4: founder_international_currency_table
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_international_currency_table();
CREATE OR REPLACE FUNCTION public.founder_international_currency_table()
RETURNS TABLE (
  currency_code text,
  currency_label text,
  exchange_rate_inr numeric,
  exchange_rate_source text,
  last_updated_at timestamptz,
  is_active boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT cu.currency_code, cu.currency_label, cu.exchange_rate_inr, cu.exchange_rate_source,
         cu.last_updated_at, cu.is_active
  FROM public.founder_international_currencies cu
  ORDER BY cu.is_active DESC, cu.currency_code ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_international_currency_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_international_currency_table() TO authenticated;

-- ============================================================================
-- RPC 5: log_founder_intl_register_country
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_intl_register_country(text, text, text, text, text, numeric, int);
CREATE OR REPLACE FUNCTION public.log_founder_intl_register_country(
  p_country_code text,
  p_country_name text,
  p_currency_code text,
  p_expansion_status text DEFAULT 'researching',
  p_regulatory_burden_band text DEFAULT 'medium',
  p_estimated_market_size_rupees numeric DEFAULT 0,
  p_estimated_total_addressable_hospitals int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_international_countries
    (country_code, country_name, currency_code, expansion_status, regulatory_burden_band,
     estimated_market_size_rupees, estimated_total_addressable_hospitals, entered_at)
  VALUES (upper(p_country_code), p_country_name, upper(p_currency_code), p_expansion_status,
          p_regulatory_burden_band, coalesce(p_estimated_market_size_rupees,0),
          coalesce(p_estimated_total_addressable_hospitals,0), now())
  ON CONFLICT (country_code) DO UPDATE
    SET country_name = EXCLUDED.country_name,
        currency_code = EXCLUDED.currency_code,
        expansion_status = EXCLUDED.expansion_status,
        regulatory_burden_band = EXCLUDED.regulatory_burden_band,
        estimated_market_size_rupees = EXCLUDED.estimated_market_size_rupees,
        estimated_total_addressable_hospitals = EXCLUDED.estimated_total_addressable_hospitals,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_intl_register_country(text, text, text, text, text, numeric, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_intl_register_country(text, text, text, text, text, numeric, int) TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_intl_milestone
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_intl_milestone(uuid, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_intl_milestone(
  p_country_id uuid,
  p_milestone_kind text,
  p_description text DEFAULT NULL,
  p_value_rupees numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_international_milestones
    (country_id, milestone_kind, description, value_rupees, created_by, achieved_at)
  VALUES (p_country_id, p_milestone_kind, p_description, coalesce(p_value_rupees,0), auth.uid(), now())
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_intl_milestone(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_intl_milestone(uuid, text, text, numeric) TO authenticated;

-- ============================================================================
-- RPC 7a: log_founder_intl_country_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_intl_country_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_intl_country_status(
  p_country_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_international_countries
  SET expansion_status = p_new_status,
      activated_at = CASE WHEN p_new_status = 'active' AND activated_at IS NULL THEN now() ELSE activated_at END,
      paused_at = CASE WHEN p_new_status = 'paused' THEN now() ELSE paused_at END,
      exited_at = CASE WHEN p_new_status = 'exited' THEN now() ELSE exited_at END,
      updated_at = now()
  WHERE id = p_country_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_intl_country_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_intl_country_status(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 7b: log_founder_intl_update_currency_rate
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_intl_update_currency_rate(text, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_intl_update_currency_rate(
  p_currency_code text,
  p_exchange_rate_inr numeric,
  p_exchange_rate_source text DEFAULT 'manual'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_international_currencies (currency_code, exchange_rate_inr, exchange_rate_source, last_updated_at)
  VALUES (upper(p_currency_code), p_exchange_rate_inr, p_exchange_rate_source, now())
  ON CONFLICT (currency_code) DO UPDATE
    SET exchange_rate_inr = EXCLUDED.exchange_rate_inr,
        exchange_rate_source = EXCLUDED.exchange_rate_source,
        last_updated_at = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_intl_update_currency_rate(text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_intl_update_currency_rate(text, numeric, text) TO authenticated;

COMMIT;