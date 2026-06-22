BEGIN;

-- =====================================================================
-- r2272 Customer NPS-by-segment slice
-- Two tables: nps_survey_responses_r2272 and nps_segment_snapshots_r2272
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.nps_survey_responses_r2272 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  respondent_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_org_name   text NOT NULL,
  hospital_tier       text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3')),
  region              text NOT NULL CHECK (region IN ('north','south','east','west','central','north_east')),
  amc_plan            text NOT NULL CHECK (amc_plan IN ('none','basic','standard','premium','platinum')),
  equipment_class     text NOT NULL CHECK (equipment_class IN ('imaging','surgical','life_support','diagnostic','dental','rehab')),
  nps_score           int  NOT NULL CHECK (nps_score BETWEEN 0 AND 10),
  nps_category        text NOT NULL CHECK (nps_category IN ('promoter','passive','detractor')),
  primary_reason      text NOT NULL,
  verbatim_quote      text,
  follow_up_status    text NOT NULL DEFAULT 'pending' CHECK (follow_up_status IN ('pending','contacted','resolved','escalated','lost')),
  surveyed_at         timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_tier        ON public.nps_survey_responses_r2272(hospital_tier);
CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_region      ON public.nps_survey_responses_r2272(region);
CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_amc         ON public.nps_survey_responses_r2272(amc_plan);
CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_equipclass  ON public.nps_survey_responses_r2272(equipment_class);
CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_category    ON public.nps_survey_responses_r2272(nps_category);
CREATE INDEX IF NOT EXISTS idx_nps_resp_r2272_surveyed    ON public.nps_survey_responses_r2272(surveyed_at DESC);

ALTER TABLE public.nps_survey_responses_r2272 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_nps_resp_r2272 ON public.nps_survey_responses_r2272;
CREATE POLICY founder_all_nps_resp_r2272 ON public.nps_survey_responses_r2272
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.nps_segment_snapshots_r2272 (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_dimension   text NOT NULL CHECK (segment_dimension IN ('hospital_tier','region','amc_plan','equipment_class')),
  segment_value       text NOT NULL,
  promoters_count     int  NOT NULL CHECK (promoters_count  >= 0),
  passives_count      int  NOT NULL CHECK (passives_count   >= 0),
  detractors_count    int  NOT NULL CHECK (detractors_count >= 0),
  total_responses     int  NOT NULL CHECK (total_responses  >= 0),
  nps_score_basis     int  NOT NULL CHECK (nps_score_basis BETWEEN -100 AND 100),
  prior_period_score  int  CHECK (prior_period_score BETWEEN -100 AND 100),
  trend_direction     text NOT NULL DEFAULT 'flat' CHECK (trend_direction IN ('up','down','flat')),
  snapshot_period     text NOT NULL DEFAULT 'rolling_90d',
  computed_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nps_snap_r2272_dim      ON public.nps_segment_snapshots_r2272(segment_dimension);
CREATE INDEX IF NOT EXISTS idx_nps_snap_r2272_score    ON public.nps_segment_snapshots_r2272(nps_score_basis);
CREATE INDEX IF NOT EXISTS idx_nps_snap_r2272_computed ON public.nps_segment_snapshots_r2272(computed_at DESC);

ALTER TABLE public.nps_segment_snapshots_r2272 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_nps_snap_r2272 ON public.nps_segment_snapshots_r2272;
CREATE POLICY founder_all_nps_snap_r2272 ON public.nps_segment_snapshots_r2272
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =====================================================================
-- SEED DATA — profiles.role ∈ {engineer, hospital_admin, supplier, manufacturer, logistics}
-- =====================================================================
DO $seed$
DECLARE
  p1 uuid; p2 uuid; p3 uuid; p4 uuid; p5 uuid; p6 uuid; p7 uuid; p8 uuid;
BEGIN
  SELECT id INTO p1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO p2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO p3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO p4 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 3 LIMIT 1;
  SELECT id INTO p5 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 4 LIMIT 1;
  SELECT id INTO p6 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 5 LIMIT 1;
  SELECT id INTO p7 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 6 LIMIT 1;
  SELECT id INTO p8 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 7 LIMIT 1;

  IF p1 IS NULL THEN SELECT id INTO p1 FROM public.profiles ORDER BY created_at LIMIT 1; END IF;
  IF p2 IS NULL THEN p2 := p1; END IF;
  IF p3 IS NULL THEN p3 := p1; END IF;
  IF p4 IS NULL THEN p4 := p1; END IF;
  IF p5 IS NULL THEN p5 := p1; END IF;
  IF p6 IS NULL THEN p6 := p1; END IF;
  IF p7 IS NULL THEN p7 := p1; END IF;
  IF p8 IS NULL THEN p8 := p1; END IF;

  IF p1 IS NOT NULL THEN
    INSERT INTO public.nps_survey_responses_r2272
      (respondent_id, hospital_org_name, hospital_tier, region, amc_plan, equipment_class,
       nps_score, nps_category, primary_reason, verbatim_quote, follow_up_status, surveyed_at)
    VALUES
      (p1, 'Apollo Multi-Specialty Hyderabad', 'tier_1', 'south',     'platinum', 'imaging',
        9, 'promoter',  'fast_response',    'Engineer reached in 38 min — unheard of in this city.', 'resolved',   now() - interval '3 days'),
      (p2, 'Fortis Heart Bangalore',           'tier_1', 'south',     'platinum', 'life_support',
       10, 'promoter',  'uptime_99',        'Two quarters zero downtime on the ventilator fleet.',  'resolved',   now() - interval '6 days'),
      (p3, 'Manipal Tier-2 Mangalore',         'tier_2', 'south',     'standard', 'surgical',
        7, 'passive',   'spares_delay',     'Service OK but spare delivery still 4 days from Pune.', 'contacted',  now() - interval '8 days'),
      (p4, 'Care Hospital Vizag',              'tier_2', 'east',      'standard', 'diagnostic',
        6, 'passive',   'price_amc',        'Premium AMC price 18 percent higher than incumbent.',   'contacted',  now() - interval '11 days'),
      (p5, 'Dental Clinic Chain Kanpur',       'tier_3', 'north',     'basic',    'dental',
        3, 'detractor', 'engineer_no_show', 'Engineer no-show twice in one week. Lost trust.',       'escalated',  now() - interval '14 days'),
      (p6, 'Rural Care Center Bihar',          'tier_3', 'east',      'none',     'rehab',
        2, 'detractor', 'unreachable_24h',  'Could not reach support for 26 hours during outage.',   'escalated',  now() - interval '17 days'),
      (p7, 'Tata Memorial Mumbai',             'tier_1', 'west',      'premium',  'imaging',
        8, 'promoter',  'engineer_skill',   'Senior engineer caught a fault three vendors missed.',  'resolved',   now() - interval '20 days'),
      (p8, 'AIIMS Bhopal',                     'tier_2', 'central',   'premium',  'life_support',
        4, 'detractor', 'parts_counterfeit','Suspicion of refurbished part fitted as new.',          'escalated',  now() - interval '23 days');
  END IF;

  INSERT INTO public.nps_segment_snapshots_r2272
    (segment_dimension, segment_value, promoters_count, passives_count, detractors_count, total_responses, nps_score_basis, prior_period_score, trend_direction, snapshot_period)
  VALUES
    ('hospital_tier',    'tier_1',      142,  38,  12, 192,  68,  61, 'up',   'rolling_90d'),
    ('hospital_tier',    'tier_2',       84,  47,  29, 160,  34,  39, 'down', 'rolling_90d'),
    ('hospital_tier',    'tier_3',       31,  22,  41,  94, -11,  -4, 'down', 'rolling_90d'),
    ('region',           'south',       118,  44,  18, 180,  56,  52, 'up',   'rolling_90d'),
    ('region',           'west',         72,  31,  17, 120,  46,  48, 'flat', 'rolling_90d'),
    ('region',           'north',        48,  29,  33, 110,  14,  21, 'down', 'rolling_90d'),
    ('region',           'east',         29,  21,  28,  78,   1,   8, 'down', 'rolling_90d'),
    ('region',           'central',      18,  14,  11,  43,  16,  12, 'up',   'rolling_90d'),
    ('region',           'north_east',    9,   8,   8,  25,   4,  -2, 'up',   'rolling_90d'),
    ('amc_plan',         'platinum',     94,  18,   6, 118,  75,  72, 'up',   'rolling_90d'),
    ('amc_plan',         'premium',      71,  29,  14, 114,  50,  48, 'flat', 'rolling_90d'),
    ('amc_plan',         'standard',     58,  41,  26, 125,  26,  31, 'down', 'rolling_90d'),
    ('amc_plan',         'basic',        22,  18,  29,  69, -10,  -3, 'down', 'rolling_90d'),
    ('amc_plan',         'none',         12,  11,  18,  41, -15,  -8, 'down', 'rolling_90d'),
    ('equipment_class',  'imaging',      88,  24,   9, 121,  65,  60, 'up',   'rolling_90d'),
    ('equipment_class',  'life_support', 64,  21,  11,  96,  55,  58, 'flat', 'rolling_90d'),
    ('equipment_class',  'surgical',     51,  28,  16,  95,  37,  41, 'down', 'rolling_90d'),
    ('equipment_class',  'diagnostic',   38,  26,  19,  83,  23,  28, 'down', 'rolling_90d'),
    ('equipment_class',  'dental',       11,   8,  17,  36, -17, -10, 'down', 'rolling_90d'),
    ('equipment_class',  'rehab',         5,   2,  10,  17, -29, -22, 'down', 'rolling_90d');
END $seed$;


-- =====================================================================
-- 7 RPCs — all is_founder gated, LANGUAGE plpgsql SECURITY DEFINER
-- =====================================================================

-- 1. Tier overview
CREATE OR REPLACE FUNCTION public.nps_by_tier_overview_r2272()
RETURNS TABLE (
  hospital_tier      text,
  responses          int,
  promoters          int,
  passives           int,
  detractors         int,
  nps_score          int,
  prior_score        int,
  trend              text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment_value,
           s.total_responses,
           s.promoters_count,
           s.passives_count,
           s.detractors_count,
           s.nps_score_basis,
           s.prior_period_score,
           s.trend_direction
    FROM public.nps_segment_snapshots_r2272 s
    WHERE s.segment_dimension = 'hospital_tier'
    ORDER BY s.nps_score_basis DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_by_tier_overview_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_by_tier_overview_r2272() TO authenticated;

-- 2. Region overview
CREATE OR REPLACE FUNCTION public.nps_by_region_overview_r2272()
RETURNS TABLE (
  region        text,
  responses     int,
  promoters     int,
  passives      int,
  detractors    int,
  nps_score     int,
  prior_score   int,
  trend         text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment_value,
           s.total_responses,
           s.promoters_count,
           s.passives_count,
           s.detractors_count,
           s.nps_score_basis,
           s.prior_period_score,
           s.trend_direction
    FROM public.nps_segment_snapshots_r2272 s
    WHERE s.segment_dimension = 'region'
    ORDER BY s.nps_score_basis DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_by_region_overview_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_by_region_overview_r2272() TO authenticated;

-- 3. AMC plan overview
CREATE OR REPLACE FUNCTION public.nps_by_amc_plan_overview_r2272()
RETURNS TABLE (
  amc_plan       text,
  responses      int,
  promoters      int,
  passives       int,
  detractors     int,
  nps_score      int,
  prior_score    int,
  trend          text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment_value,
           s.total_responses,
           s.promoters_count,
           s.passives_count,
           s.detractors_count,
           s.nps_score_basis,
           s.prior_period_score,
           s.trend_direction
    FROM public.nps_segment_snapshots_r2272 s
    WHERE s.segment_dimension = 'amc_plan'
    ORDER BY s.nps_score_basis DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_by_amc_plan_overview_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_by_amc_plan_overview_r2272() TO authenticated;

-- 4. Equipment class overview
CREATE OR REPLACE FUNCTION public.nps_by_equipment_class_overview_r2272()
RETURNS TABLE (
  equipment_class  text,
  responses        int,
  promoters        int,
  passives         int,
  detractors       int,
  nps_score        int,
  prior_score      int,
  trend            text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.segment_value,
           s.total_responses,
           s.promoters_count,
           s.passives_count,
           s.detractors_count,
           s.nps_score_basis,
           s.prior_period_score,
           s.trend_direction
    FROM public.nps_segment_snapshots_r2272 s
    WHERE s.segment_dimension = 'equipment_class'
    ORDER BY s.nps_score_basis DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_by_equipment_class_overview_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_by_equipment_class_overview_r2272() TO authenticated;

-- 5. Detractor drill-down (all detractor rows, ordered by recency)
CREATE OR REPLACE FUNCTION public.nps_detractor_drilldown_r2272()
RETURNS TABLE (
  hospital_org_name  text,
  hospital_tier      text,
  region             text,
  amc_plan           text,
  equipment_class    text,
  nps_score          int,
  primary_reason     text,
  verbatim_quote     text,
  follow_up_status   text,
  surveyed_at        timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.hospital_org_name,
           r.hospital_tier,
           r.region,
           r.amc_plan,
           r.equipment_class,
           r.nps_score,
           r.primary_reason,
           r.verbatim_quote,
           r.follow_up_status,
           r.surveyed_at
    FROM public.nps_survey_responses_r2272 r
    WHERE r.nps_category = 'detractor'
    ORDER BY r.surveyed_at DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_detractor_drilldown_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_detractor_drilldown_r2272() TO authenticated;

-- 6. Detractor reason rollup
CREATE OR REPLACE FUNCTION public.nps_detractor_reason_rollup_r2272()
RETURNS TABLE (
  primary_reason  text,
  detractor_count int,
  escalated_count int,
  resolved_count  int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.primary_reason,
           (COUNT(*))::int,
           (COUNT(*) FILTER (WHERE r.follow_up_status = 'escalated'))::int,
           (COUNT(*) FILTER (WHERE r.follow_up_status = 'resolved'))::int
    FROM public.nps_survey_responses_r2272 r
    WHERE r.nps_category = 'detractor'
    GROUP BY r.primary_reason
    ORDER BY (COUNT(*))::int DESC;
END $fn$;
REVOKE ALL ON FUNCTION public.nps_detractor_reason_rollup_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_detractor_reason_rollup_r2272() TO authenticated;

-- 7. Headline KPI (overall NPS)
CREATE OR REPLACE FUNCTION public.nps_headline_kpi_r2272()
RETURNS TABLE (
  total_responses        int,
  promoters              int,
  passives               int,
  detractors             int,
  overall_nps            int,
  segments_tracked       int,
  worst_segment          text,
  worst_segment_score    int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_total int;
  v_prom  int;
  v_pas   int;
  v_det   int;
  v_nps   int;
  v_segs  int;
  v_ws    text;
  v_wss   int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT (COUNT(*))::int,
         (COUNT(*) FILTER (WHERE nps_category = 'promoter'))::int,
         (COUNT(*) FILTER (WHERE nps_category = 'passive'))::int,
         (COUNT(*) FILTER (WHERE nps_category = 'detractor'))::int
    INTO v_total, v_prom, v_pas, v_det
    FROM public.nps_survey_responses_r2272;

  IF v_total > 0 THEN
    v_nps := ((v_prom - v_det) * 100 / v_total)::int;
  ELSE
    v_nps := 0;
  END IF;

  SELECT (COUNT(*))::int INTO v_segs FROM public.nps_segment_snapshots_r2272;

  SELECT s.segment_dimension || ':' || s.segment_value, s.nps_score_basis
    INTO v_ws, v_wss
    FROM public.nps_segment_snapshots_r2272 s
    ORDER BY s.nps_score_basis ASC
    LIMIT 1;

  RETURN QUERY SELECT v_total, v_prom, v_pas, v_det, v_nps, v_segs, COALESCE(v_ws,'none'), COALESCE(v_wss,0);
END $fn$;
REVOKE ALL ON FUNCTION public.nps_headline_kpi_r2272() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_headline_kpi_r2272() TO authenticated;

COMMIT;
