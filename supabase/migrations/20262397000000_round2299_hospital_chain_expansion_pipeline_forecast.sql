BEGIN;

-- ============================================================================
-- r2299 — Hospital Chain Expansion-Pipeline Forecast
-- Track chain branches/sites in pipeline, revenue forecast, our involvement
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chain_expansion_sites_r2299 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  chain_name      text NOT NULL,
  parent_org_id   uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  site_name       text NOT NULL,
  city            text NOT NULL,
  state_code      text NOT NULL,
  site_type       text NOT NULL CHECK (site_type IN ('greenfield_hospital','acquired_hospital','satellite_clinic','daycare_center','diagnostic_center','specialty_wing')),
  bed_count_planned integer NOT NULL DEFAULT 0 CHECK (bed_count_planned >= 0),
  pipeline_stage  text NOT NULL CHECK (pipeline_stage IN ('rumor','announced','land_acquired','construction','equipping','soft_launch','operational','cancelled')),
  stage_confidence integer NOT NULL DEFAULT 50 CHECK (stage_confidence BETWEEN 0 AND 100),
  expected_open_date date,
  capex_estimate_inr_lakh numeric(14,2) NOT NULL DEFAULT 0,
  equipment_capex_inr_lakh numeric(14,2) NOT NULL DEFAULT 0,
  our_amc_share_pct integer NOT NULL DEFAULT 0 CHECK (our_amc_share_pct BETWEEN 0 AND 100),
  forecast_amc_inr_year numeric(14,2) NOT NULL DEFAULT 0,
  forecast_repair_inr_year numeric(14,2) NOT NULL DEFAULT 0,
  forecast_parts_inr_year numeric(14,2) NOT NULL DEFAULT 0,
  involvement_plan text NOT NULL DEFAULT 'cold' CHECK (involvement_plan IN ('cold','intro_sent','pilot_proposed','quoted','negotiating','contracted','onboarded','lost')),
  decision_maker_name text,
  decision_maker_email text,
  decision_maker_phone text,
  source_signal   text NOT NULL DEFAULT 'manual' CHECK (source_signal IN ('manual','press_release','linkedin','referral','rfp_portal','tender','site_visit','industry_event')),
  source_url      text,
  notes           text,
  added_by_email  text NOT NULL,
  last_activity_at timestamptz,
  next_action     text,
  next_action_due date,
  killed_at       timestamptz,
  kill_reason     text
);

CREATE INDEX IF NOT EXISTS idx_ces_r2299_stage ON public.chain_expansion_sites_r2299(pipeline_stage);
CREATE INDEX IF NOT EXISTS idx_ces_r2299_chain ON public.chain_expansion_sites_r2299(chain_name);
CREATE INDEX IF NOT EXISTS idx_ces_r2299_due ON public.chain_expansion_sites_r2299(next_action_due) WHERE killed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ces_r2299_open ON public.chain_expansion_sites_r2299(expected_open_date) WHERE killed_at IS NULL;

ALTER TABLE public.chain_expansion_sites_r2299 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ces_r2299_founder_all ON public.chain_expansion_sites_r2299;
CREATE POLICY ces_r2299_founder_all ON public.chain_expansion_sites_r2299
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chain_expansion_activity_r2299 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id         uuid NOT NULL REFERENCES public.chain_expansion_sites_r2299(id) ON DELETE CASCADE,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  activity_type   text NOT NULL CHECK (activity_type IN ('note','call','email','meeting','site_visit','quote_sent','pilot_started','contract_signed','stage_change','lost')),
  from_stage      text,
  to_stage        text,
  summary         text NOT NULL,
  amount_inr_lakh numeric(14,2),
  actor_email     text NOT NULL,
  actor_user_id   uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cea_r2299_site ON public.chain_expansion_activity_r2299(site_id, occurred_at DESC);

ALTER TABLE public.chain_expansion_activity_r2299 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cea_r2299_founder_all ON public.chain_expansion_activity_r2299;
CREATE POLICY cea_r2299_founder_all ON public.chain_expansion_activity_r2299
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: overview metrics
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_chain_expansion_overview();
CREATE OR REPLACE FUNCTION public.r2299_chain_expansion_overview()
RETURNS TABLE (
  active_sites         integer,
  unique_chains        integer,
  beds_pipeline        integer,
  total_capex_lakh     numeric,
  forecast_arr_lakh    numeric,
  weighted_arr_lakh    numeric,
  contracted_sites     integer,
  opening_next_90d     integer,
  overdue_actions      integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE killed_at IS NULL)::int AS active_sites,
    COUNT(DISTINCT chain_name) FILTER (WHERE killed_at IS NULL)::int AS unique_chains,
    COALESCE(SUM(bed_count_planned) FILTER (WHERE killed_at IS NULL), 0)::int AS beds_pipeline,
    COALESCE(SUM(equipment_capex_inr_lakh) FILTER (WHERE killed_at IS NULL), 0)::numeric AS total_capex_lakh,
    COALESCE(SUM((forecast_amc_inr_year + forecast_repair_inr_year + forecast_parts_inr_year) / 100000.0) FILTER (WHERE killed_at IS NULL), 0)::numeric AS forecast_arr_lakh,
    COALESCE(SUM(((forecast_amc_inr_year + forecast_repair_inr_year + forecast_parts_inr_year) / 100000.0) * stage_confidence / 100.0) FILTER (WHERE killed_at IS NULL), 0)::numeric AS weighted_arr_lakh,
    COUNT(*) FILTER (WHERE involvement_plan IN ('contracted','onboarded') AND killed_at IS NULL)::int AS contracted_sites,
    COUNT(*) FILTER (WHERE expected_open_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days' AND killed_at IS NULL)::int AS opening_next_90d,
    COUNT(*) FILTER (WHERE next_action_due < CURRENT_DATE AND killed_at IS NULL)::int AS overdue_actions
  FROM public.chain_expansion_sites_r2299;
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_chain_expansion_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_chain_expansion_overview() TO authenticated;

-- ============================================================================
-- RPC 2: list pipeline sites
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_list_pipeline_sites(text, text, integer);
CREATE OR REPLACE FUNCTION public.r2299_list_pipeline_sites(
  p_stage text DEFAULT NULL,
  p_involvement text DEFAULT NULL,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id                uuid,
  chain_name        text,
  site_name         text,
  city              text,
  state_code        text,
  site_type         text,
  bed_count_planned integer,
  pipeline_stage    text,
  stage_confidence  integer,
  expected_open_date date,
  equipment_capex_inr_lakh numeric,
  forecast_arr_lakh numeric,
  weighted_arr_lakh numeric,
  involvement_plan  text,
  next_action       text,
  next_action_due   date,
  days_to_open      integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.chain_name,
    s.site_name,
    s.city,
    s.state_code,
    s.site_type,
    s.bed_count_planned,
    s.pipeline_stage,
    s.stage_confidence,
    s.expected_open_date,
    s.equipment_capex_inr_lakh,
    ((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0)::numeric AS forecast_arr_lakh,
    (((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0) * s.stage_confidence / 100.0)::numeric AS weighted_arr_lakh,
    s.involvement_plan,
    s.next_action,
    s.next_action_due,
    CASE WHEN s.expected_open_date IS NULL THEN NULL ELSE (s.expected_open_date - CURRENT_DATE)::int END AS days_to_open
  FROM public.chain_expansion_sites_r2299 s
  WHERE s.killed_at IS NULL
    AND (p_stage IS NULL OR s.pipeline_stage = p_stage)
    AND (p_involvement IS NULL OR s.involvement_plan = p_involvement)
  ORDER BY s.expected_open_date NULLS LAST, s.stage_confidence DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_list_pipeline_sites(text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_list_pipeline_sites(text, text, integer) TO authenticated;

-- ============================================================================
-- RPC 3: chain rollup
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_chain_rollup();
CREATE OR REPLACE FUNCTION public.r2299_chain_rollup()
RETURNS TABLE (
  chain_name        text,
  site_count        integer,
  beds_pipeline     integer,
  total_capex_lakh  numeric,
  forecast_arr_lakh numeric,
  weighted_arr_lakh numeric,
  contracted_sites  integer,
  earliest_open     date,
  latest_open       date,
  hottest_stage     text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.chain_name,
    COUNT(*)::int AS site_count,
    COALESCE(SUM(s.bed_count_planned), 0)::int AS beds_pipeline,
    COALESCE(SUM(s.equipment_capex_inr_lakh), 0)::numeric AS total_capex_lakh,
    COALESCE(SUM((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0), 0)::numeric AS forecast_arr_lakh,
    COALESCE(SUM(((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0) * s.stage_confidence / 100.0), 0)::numeric AS weighted_arr_lakh,
    COUNT(*) FILTER (WHERE s.involvement_plan IN ('contracted','onboarded'))::int AS contracted_sites,
    MIN(s.expected_open_date) AS earliest_open,
    MAX(s.expected_open_date) AS latest_open,
    (SELECT s2.pipeline_stage
       FROM public.chain_expansion_sites_r2299 s2
       WHERE s2.chain_name = s.chain_name AND s2.killed_at IS NULL
       ORDER BY s2.stage_confidence DESC, s2.expected_open_date NULLS LAST
       LIMIT 1) AS hottest_stage
  FROM public.chain_expansion_sites_r2299 s
  WHERE s.killed_at IS NULL
  GROUP BY s.chain_name
  ORDER BY weighted_arr_lakh DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_chain_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_chain_rollup() TO authenticated;

-- ============================================================================
-- RPC 4: quarterly opening calendar
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_quarterly_calendar();
CREATE OR REPLACE FUNCTION public.r2299_quarterly_calendar()
RETURNS TABLE (
  quarter_label     text,
  quarter_start     date,
  sites_opening     integer,
  beds_opening      integer,
  capex_lakh        numeric,
  forecast_arr_lakh numeric,
  weighted_arr_lakh numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    'Q' || EXTRACT(QUARTER FROM s.expected_open_date)::text || ' ' || EXTRACT(YEAR FROM s.expected_open_date)::text AS quarter_label,
    DATE_TRUNC('quarter', s.expected_open_date)::date AS quarter_start,
    COUNT(*)::int AS sites_opening,
    COALESCE(SUM(s.bed_count_planned), 0)::int AS beds_opening,
    COALESCE(SUM(s.equipment_capex_inr_lakh), 0)::numeric AS capex_lakh,
    COALESCE(SUM((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0), 0)::numeric AS forecast_arr_lakh,
    COALESCE(SUM(((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0) * s.stage_confidence / 100.0), 0)::numeric AS weighted_arr_lakh
  FROM public.chain_expansion_sites_r2299 s
  WHERE s.killed_at IS NULL
    AND s.expected_open_date IS NOT NULL
    AND s.expected_open_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY quarter_label, quarter_start
  ORDER BY quarter_start
  LIMIT 16;
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_quarterly_calendar() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_quarterly_calendar() TO authenticated;

-- ============================================================================
-- RPC 5: stage funnel
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_stage_funnel();
CREATE OR REPLACE FUNCTION public.r2299_stage_funnel()
RETURNS TABLE (
  pipeline_stage    text,
  site_count        integer,
  forecast_arr_lakh numeric,
  weighted_arr_lakh numeric,
  avg_confidence    numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.pipeline_stage,
    COUNT(*)::int AS site_count,
    COALESCE(SUM((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0), 0)::numeric AS forecast_arr_lakh,
    COALESCE(SUM(((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0) * s.stage_confidence / 100.0), 0)::numeric AS weighted_arr_lakh,
    COALESCE(AVG(s.stage_confidence), 0)::numeric AS avg_confidence
  FROM public.chain_expansion_sites_r2299 s
  WHERE s.killed_at IS NULL
  GROUP BY s.pipeline_stage
  ORDER BY
    CASE s.pipeline_stage
      WHEN 'rumor' THEN 1
      WHEN 'announced' THEN 2
      WHEN 'land_acquired' THEN 3
      WHEN 'construction' THEN 4
      WHEN 'equipping' THEN 5
      WHEN 'soft_launch' THEN 6
      WHEN 'operational' THEN 7
      WHEN 'cancelled' THEN 8
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_stage_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_stage_funnel() TO authenticated;

-- ============================================================================
-- RPC 6: overdue actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_overdue_actions();
CREATE OR REPLACE FUNCTION public.r2299_overdue_actions()
RETURNS TABLE (
  id                uuid,
  chain_name        text,
  site_name         text,
  city              text,
  pipeline_stage    text,
  involvement_plan  text,
  next_action       text,
  next_action_due   date,
  days_overdue      integer,
  weighted_arr_lakh numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.chain_name,
    s.site_name,
    s.city,
    s.pipeline_stage,
    s.involvement_plan,
    s.next_action,
    s.next_action_due,
    (CURRENT_DATE - s.next_action_due)::int AS days_overdue,
    (((s.forecast_amc_inr_year + s.forecast_repair_inr_year + s.forecast_parts_inr_year) / 100000.0) * s.stage_confidence / 100.0)::numeric AS weighted_arr_lakh
  FROM public.chain_expansion_sites_r2299 s
  WHERE s.killed_at IS NULL
    AND s.next_action_due IS NOT NULL
    AND s.next_action_due < CURRENT_DATE
  ORDER BY s.next_action_due ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_overdue_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_overdue_actions() TO authenticated;

-- ============================================================================
-- RPC 7: recent activity
-- ============================================================================
DROP FUNCTION IF EXISTS public.r2299_recent_activity(integer);
CREATE OR REPLACE FUNCTION public.r2299_recent_activity(p_limit integer DEFAULT 30)
RETURNS TABLE (
  id              uuid,
  occurred_at     timestamptz,
  chain_name      text,
  site_name       text,
  activity_type   text,
  from_stage      text,
  to_stage        text,
  summary         text,
  amount_inr_lakh numeric,
  actor_email     text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.occurred_at,
    s.chain_name,
    s.site_name,
    a.activity_type,
    a.from_stage,
    a.to_stage,
    a.summary,
    a.amount_inr_lakh,
    a.actor_email
  FROM public.chain_expansion_activity_r2299 a
  JOIN public.chain_expansion_sites_r2299 s ON s.id = a.site_id
  ORDER BY a.occurred_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE ALL ON FUNCTION public.r2299_recent_activity(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2299_recent_activity(integer) TO authenticated;

COMMIT;
