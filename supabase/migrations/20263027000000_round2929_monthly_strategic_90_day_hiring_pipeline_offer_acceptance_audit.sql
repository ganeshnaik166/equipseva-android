-- Round r2929 — Monthly Strategic 90-Day Hiring Pipeline & Offer Acceptance Audit
-- 1500 +50-MAJORS MILESTONE BATCH · HEAVY ★★★★

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS hiring_pipeline_stages_r2929 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  role_family text NOT NULL,
  stage_name text NOT NULL,
  stage_order int NOT NULL,
  candidates_entered int NOT NULL DEFAULT 0,
  candidates_passed int NOT NULL DEFAULT 0,
  median_days_in_stage numeric(6,2) NOT NULL DEFAULT 0,
  conversion_rate numeric(5,2) NOT NULL DEFAULT 0,
  bottleneck_flag boolean NOT NULL DEFAULT false,
  owner text NOT NULL DEFAULT 'people-ops',
  notes text
);
ALTER TABLE hiring_pipeline_stages_r2929 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS offer_acceptance_audit_r2929 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  candidate_code text NOT NULL,
  role_family text NOT NULL,
  level text NOT NULL,
  offer_date date NOT NULL,
  response_date date,
  offer_status text NOT NULL,
  total_comp_inr_lakhs numeric(8,2) NOT NULL,
  market_band_p50_inr_lakhs numeric(8,2) NOT NULL,
  comp_vs_market_pct numeric(6,2) NOT NULL,
  decline_reason text,
  source_channel text NOT NULL,
  days_to_response int
);
ALTER TABLE offer_acceptance_audit_r2929 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEEDS
-- ============================================================================

INSERT INTO hiring_pipeline_stages_r2929 (audit_month, role_family, stage_name, stage_order, candidates_entered, candidates_passed, median_days_in_stage, conversion_rate, bottleneck_flag, owner, notes) VALUES
  ('2026-06-01'::date, 'field_engineer', 'sourced',         1, 420, 280, 3.5,  66.67, false, 'people-ops',   'LinkedIn + Naukri inbound'),
  ('2026-06-01'::date, 'field_engineer', 'screen_call',     2, 280, 165, 4.2,  58.93, false, 'people-ops',   'phone screen 20min'),
  ('2026-06-01'::date, 'field_engineer', 'technical_test',  3, 165,  92, 6.8,  55.76, true,  'eng-lead',     'biomed troubleshoot scenario'),
  ('2026-06-01'::date, 'field_engineer', 'onsite_panel',    4,  92,  44, 9.1,  47.83, true,  'founder',      'panel slot scarcity'),
  ('2026-06-01'::date, 'field_engineer', 'offer_extended',  5,  44,  31, 5.5,  70.45, false, 'founder',      'offer pack mailed'),
  ('2026-06-01'::date, 'backend_eng',    'sourced',         1, 180, 140, 3.0,  77.78, false, 'people-ops',   'referrals heavy'),
  ('2026-06-01'::date, 'backend_eng',    'screen_call',     2, 140,  88, 4.0,  62.86, false, 'eng-lead',     null),
  ('2026-06-01'::date, 'backend_eng',    'technical_test',  3,  88,  52, 7.5,  59.09, false, 'eng-lead',     'take-home 4hr'),
  ('2026-06-01'::date, 'backend_eng',    'onsite_panel',    4,  52,  24, 10.2, 46.15, true,  'cto-proxy',    'system design hard'),
  ('2026-06-01'::date, 'backend_eng',    'offer_extended',  5,  24,  16, 6.0,  66.67, false, 'founder',      'comp negotiation 2 rounds'),
  ('2026-06-01'::date, 'sales_ae',       'sourced',         1, 310, 220, 3.2,  70.97, false, 'people-ops',   'cold-email pulled in'),
  ('2026-06-01'::date, 'sales_ae',       'screen_call',     2, 220, 140, 4.5,  63.64, false, 'sales-vp',     null),
  ('2026-06-01'::date, 'sales_ae',       'technical_test',  3, 140,  78, 5.5,  55.71, false, 'sales-vp',     'mock pitch + role play'),
  ('2026-06-01'::date, 'sales_ae',       'onsite_panel',    4,  78,  38, 7.8,  48.72, true,  'sales-vp',     'territory mismatch'),
  ('2026-06-01'::date, 'sales_ae',       'offer_extended',  5,  38,  22, 6.5,  57.89, true,  'founder',      'OTE shape pushback'),
  ('2026-06-01'::date, 'product_pm',     'sourced',         1,  95,  60, 4.0,  63.16, false, 'people-ops',   'narrow funnel'),
  ('2026-06-01'::date, 'product_pm',     'screen_call',     2,  60,  32, 5.0,  53.33, false, 'founder',      null),
  ('2026-06-01'::date, 'product_pm',     'technical_test',  3,  32,  18, 8.0,  56.25, false, 'founder',      'case-study'),
  ('2026-06-01'::date, 'product_pm',     'onsite_panel',    4,  18,   8, 11.0, 44.44, true,  'founder',      'founder availability'),
  ('2026-06-01'::date, 'product_pm',     'offer_extended',  5,   8,   4, 7.0,  50.00, true,  'founder',      'half declined')
ON CONFLICT DO NOTHING;

INSERT INTO offer_acceptance_audit_r2929 (audit_month, candidate_code, role_family, level, offer_date, response_date, offer_status, total_comp_inr_lakhs, market_band_p50_inr_lakhs, comp_vs_market_pct, decline_reason, source_channel, days_to_response) VALUES
  ('2026-06-01'::date, 'FE-2026-A01', 'field_engineer', 'L2',  '2026-06-03'::date, '2026-06-05'::date, 'accepted', 7.20, 7.50, 96.00, null,                    'linkedin', 2),
  ('2026-06-01'::date, 'FE-2026-A02', 'field_engineer', 'L2',  '2026-06-04'::date, '2026-06-09'::date, 'accepted', 7.50, 7.50, 100.00, null,                   'referral', 5),
  ('2026-06-01'::date, 'FE-2026-A03', 'field_engineer', 'L3',  '2026-06-06'::date, '2026-06-13'::date, 'declined', 9.80, 11.00, 89.09, 'comp_below_market',    'naukri',   7),
  ('2026-06-01'::date, 'FE-2026-A04', 'field_engineer', 'L1',  '2026-06-08'::date, '2026-06-10'::date, 'accepted', 5.50, 5.20, 105.77, null,                   'campus',   2),
  ('2026-06-01'::date, 'FE-2026-A05', 'field_engineer', 'L2',  '2026-06-09'::date, '2026-06-16'::date, 'declined', 7.00, 7.50, 93.33, 'counter_offer',         'linkedin', 7),
  ('2026-06-01'::date, 'BE-2026-B01', 'backend_eng',    'L4',  '2026-06-02'::date, '2026-06-06'::date, 'accepted', 28.00, 27.00, 103.70, null,                 'referral', 4),
  ('2026-06-01'::date, 'BE-2026-B02', 'backend_eng',    'L5',  '2026-06-05'::date, '2026-06-12'::date, 'declined', 38.00, 42.00, 90.48, 'comp_below_market',   'linkedin', 7),
  ('2026-06-01'::date, 'BE-2026-B03', 'backend_eng',    'L3',  '2026-06-07'::date, '2026-06-09'::date, 'accepted', 19.50, 19.00, 102.63, null,                 'referral', 2),
  ('2026-06-01'::date, 'BE-2026-B04', 'backend_eng',    'L4',  '2026-06-10'::date, null,               'pending',  29.00, 27.00, 107.41, null,                 'inbound',  null),
  ('2026-06-01'::date, 'BE-2026-B05', 'backend_eng',    'L4',  '2026-06-11'::date, '2026-06-17'::date, 'declined', 26.00, 27.00, 96.30, 'remote_only_request', 'linkedin', 6),
  ('2026-06-01'::date, 'SA-2026-C01', 'sales_ae',       'L3',  '2026-06-03'::date, '2026-06-06'::date, 'accepted', 16.00, 15.50, 103.23, null,                 'referral', 3),
  ('2026-06-01'::date, 'SA-2026-C02', 'sales_ae',       'L4',  '2026-06-05'::date, '2026-06-14'::date, 'declined', 22.00, 24.00, 91.67, 'ote_structure',       'linkedin', 9),
  ('2026-06-01'::date, 'SA-2026-C03', 'sales_ae',       'L2',  '2026-06-07'::date, '2026-06-10'::date, 'accepted', 11.50, 11.00, 104.55, null,                 'inbound',  3),
  ('2026-06-01'::date, 'SA-2026-C04', 'sales_ae',       'L3',  '2026-06-09'::date, '2026-06-18'::date, 'declined', 15.50, 15.50, 100.00, 'territory_concern',  'naukri',   9),
  ('2026-06-01'::date, 'SA-2026-C05', 'sales_ae',       'L3',  '2026-06-12'::date, '2026-06-15'::date, 'accepted', 16.50, 15.50, 106.45, null,                 'linkedin', 3),
  ('2026-06-01'::date, 'PM-2026-D01', 'product_pm',     'L5',  '2026-06-04'::date, '2026-06-11'::date, 'declined', 45.00, 48.00, 93.75, 'comp_below_market',   'referral', 7),
  ('2026-06-01'::date, 'PM-2026-D02', 'product_pm',     'L4',  '2026-06-06'::date, '2026-06-09'::date, 'accepted', 36.00, 35.00, 102.86, null,                 'referral', 3),
  ('2026-06-01'::date, 'PM-2026-D03', 'product_pm',     'L4',  '2026-06-09'::date, '2026-06-19'::date, 'declined', 34.00, 35.00, 97.14, 'remote_only_request', 'linkedin', 10),
  ('2026-06-01'::date, 'PM-2026-D04', 'product_pm',     'L3',  '2026-06-11'::date, '2026-06-13'::date, 'accepted', 26.00, 25.00, 104.00, null,                 'inbound',  2)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- RPCs (all SECURITY DEFINER, is_founder gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_r2929_pipeline_overview()
RETURNS TABLE (
  role_family text,
  stages int,
  total_entered int,
  total_passed int,
  funnel_conversion_pct numeric,
  bottlenecks int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.role_family,
    COUNT(*)::int AS stages,
    SUM(s.candidates_entered)::int AS total_entered,
    SUM(s.candidates_passed)::int AS total_passed,
    ROUND(
      (MIN(s.candidates_passed) FILTER (WHERE s.stage_order = 5)::numeric
       / NULLIF(MAX(s.candidates_entered) FILTER (WHERE s.stage_order = 1), 0)) * 100,
      2
    ) AS funnel_conversion_pct,
    COUNT(*) FILTER (WHERE s.bottleneck_flag)::int AS bottlenecks
  FROM hiring_pipeline_stages_r2929 s
  GROUP BY s.role_family
  ORDER BY funnel_conversion_pct DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_bottleneck_stages()
RETURNS TABLE (
  role_family text,
  stage_name text,
  stage_order int,
  candidates_entered int,
  candidates_passed int,
  median_days_in_stage numeric,
  conversion_rate numeric,
  owner text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.role_family, s.stage_name, s.stage_order, s.candidates_entered, s.candidates_passed,
         s.median_days_in_stage, s.conversion_rate, s.owner, s.notes
  FROM hiring_pipeline_stages_r2929 s
  WHERE s.bottleneck_flag
  ORDER BY s.median_days_in_stage DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_stage_conversion_detail()
RETURNS TABLE (
  role_family text,
  stage_name text,
  stage_order int,
  candidates_entered int,
  candidates_passed int,
  conversion_rate numeric,
  median_days_in_stage numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.role_family, s.stage_name, s.stage_order, s.candidates_entered,
         s.candidates_passed, s.conversion_rate, s.median_days_in_stage
  FROM hiring_pipeline_stages_r2929 s
  ORDER BY s.role_family, s.stage_order;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_offer_acceptance_rate()
RETURNS TABLE (
  role_family text,
  total_offers int,
  accepted int,
  declined int,
  pending int,
  acceptance_rate_pct numeric,
  median_days_to_response numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.role_family,
    COUNT(*)::int AS total_offers,
    COUNT(*) FILTER (WHERE o.offer_status = 'accepted')::int AS accepted,
    COUNT(*) FILTER (WHERE o.offer_status = 'declined')::int AS declined,
    COUNT(*) FILTER (WHERE o.offer_status = 'pending')::int AS pending,
    ROUND(
      (COUNT(*) FILTER (WHERE o.offer_status = 'accepted')::numeric
       / NULLIF(COUNT(*) FILTER (WHERE o.offer_status IN ('accepted','declined')), 0)) * 100,
      2
    ) AS acceptance_rate_pct,
    ROUND(AVG(o.days_to_response) FILTER (WHERE o.days_to_response IS NOT NULL), 2) AS median_days_to_response
  FROM offer_acceptance_audit_r2929 o
  GROUP BY o.role_family
  ORDER BY acceptance_rate_pct DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_decline_reason_breakdown()
RETURNS TABLE (
  decline_reason text,
  count int,
  affected_role_families int,
  avg_comp_gap_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.decline_reason,
    COUNT(*)::int AS count,
    COUNT(DISTINCT o.role_family)::int AS affected_role_families,
    ROUND(AVG(100 - o.comp_vs_market_pct), 2) AS avg_comp_gap_pct
  FROM offer_acceptance_audit_r2929 o
  WHERE o.offer_status = 'declined' AND o.decline_reason IS NOT NULL
  GROUP BY o.decline_reason
  ORDER BY count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_comp_vs_market_outliers()
RETURNS TABLE (
  candidate_code text,
  role_family text,
  level text,
  total_comp_inr_lakhs numeric,
  market_band_p50_inr_lakhs numeric,
  comp_vs_market_pct numeric,
  offer_status text,
  decline_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.candidate_code, o.role_family, o.level, o.total_comp_inr_lakhs,
         o.market_band_p50_inr_lakhs, o.comp_vs_market_pct, o.offer_status, o.decline_reason
  FROM offer_acceptance_audit_r2929 o
  WHERE o.comp_vs_market_pct < 95 OR o.comp_vs_market_pct > 105
  ORDER BY o.comp_vs_market_pct ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_source_channel_yield()
RETURNS TABLE (
  source_channel text,
  total_offers int,
  accepted int,
  acceptance_rate_pct numeric,
  avg_days_to_response numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.source_channel,
    COUNT(*)::int AS total_offers,
    COUNT(*) FILTER (WHERE o.offer_status = 'accepted')::int AS accepted,
    ROUND(
      (COUNT(*) FILTER (WHERE o.offer_status = 'accepted')::numeric
       / NULLIF(COUNT(*) FILTER (WHERE o.offer_status IN ('accepted','declined')), 0)) * 100,
      2
    ) AS acceptance_rate_pct,
    ROUND(AVG(o.days_to_response) FILTER (WHERE o.days_to_response IS NOT NULL), 2) AS avg_days_to_response
  FROM offer_acceptance_audit_r2929 o
  GROUP BY o.source_channel
  ORDER BY acceptance_rate_pct DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2929_pending_offers_followup()
RETURNS TABLE (
  candidate_code text,
  role_family text,
  level text,
  offer_date date,
  days_outstanding int,
  total_comp_inr_lakhs numeric,
  source_channel text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.candidate_code, o.role_family, o.level, o.offer_date,
         (CURRENT_DATE - o.offer_date)::int AS days_outstanding,
         o.total_comp_inr_lakhs, o.source_channel
  FROM offer_acceptance_audit_r2929 o
  WHERE o.offer_status = 'pending'
  ORDER BY days_outstanding DESC;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION founder_r2929_pipeline_overview()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_bottleneck_stages()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_stage_conversion_detail()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_offer_acceptance_rate()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_decline_reason_breakdown()    FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_comp_vs_market_outliers()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_source_channel_yield()        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2929_pending_offers_followup()     FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2929_pipeline_overview()           TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_bottleneck_stages()           TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_stage_conversion_detail()     TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_offer_acceptance_rate()       TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_decline_reason_breakdown()    TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_comp_vs_market_outliers()     TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_source_channel_yield()        TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2929_pending_offers_followup()     TO authenticated;

COMMIT;
