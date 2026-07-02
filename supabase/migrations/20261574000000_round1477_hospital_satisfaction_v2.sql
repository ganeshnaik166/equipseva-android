BEGIN;

-- ============================================================
-- r1477 · Hospital Satisfaction Survey v2
-- Quarterly 8-dimension survey of hospital partners with
-- weighted composite score + quarter-over-quarter trending.
-- ============================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS hospital_satisfaction_surveys_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,                  -- e.g. 'FY26-Q1'
  quarter_start date NOT NULL,
  quarter_end date NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','submitted','expired','void')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  respondent_user_id uuid REFERENCES profiles(id),
  respondent_role text,
  -- 8 dimensions, each scored 1..10
  score_response_speed         smallint CHECK (score_response_speed         BETWEEN 1 AND 10),
  score_engineer_professional  smallint CHECK (score_engineer_professional  BETWEEN 1 AND 10),
  score_amc_value              smallint CHECK (score_amc_value              BETWEEN 1 AND 10),
  score_repair_quality         smallint CHECK (score_repair_quality         BETWEEN 1 AND 10),
  score_part_availability      smallint CHECK (score_part_availability      BETWEEN 1 AND 10),
  score_billing_clarity        smallint CHECK (score_billing_clarity        BETWEEN 1 AND 10),
  score_communication          smallint CHECK (score_communication          BETWEEN 1 AND 10),
  score_overall_trust          smallint CHECK (score_overall_trust          BETWEEN 1 AND 10),
  composite_score numeric(5,2),                 -- weighted, populated on submit
  nps_band text CHECK (nps_band IN ('promoter','passive','detractor')),
  free_text_comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id, quarter_label)
);

CREATE INDEX IF NOT EXISTS idx_hssv2_org_quarter
  ON hospital_satisfaction_surveys_v2 (hospital_org_id, quarter_start DESC);
CREATE INDEX IF NOT EXISTS idx_hssv2_status
  ON hospital_satisfaction_surveys_v2 (status);
CREATE INDEX IF NOT EXISTS idx_hssv2_submitted_at
  ON hospital_satisfaction_surveys_v2 (submitted_at DESC);

CREATE TABLE IF NOT EXISTS hospital_satisfaction_dim_weights_v2 (
  dimension text PRIMARY KEY,
  weight numeric(4,3) NOT NULL CHECK (weight > 0 AND weight <= 1),
  display_label text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO hospital_satisfaction_dim_weights_v2 (dimension, weight, display_label) VALUES
  ('response_speed',         0.175, 'Response Speed'),
  ('engineer_professional',  0.150, 'Engineer Professionalism'),
  ('amc_value',              0.150, 'AMC Value'),
  ('repair_quality',         0.150, 'Repair Quality'),
  ('part_availability',      0.100, 'Part Availability'),
  ('billing_clarity',        0.075, 'Billing Clarity'),
  ('communication',          0.075, 'Communication'),
  ('overall_trust',          0.125, 'Overall Trust')
ON CONFLICT (dimension) DO NOTHING;

-- ---------- RLS ----------

ALTER TABLE hospital_satisfaction_surveys_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_satisfaction_dim_weights_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hssv2_founder_only ON hospital_satisfaction_surveys_v2;
CREATE POLICY hssv2_founder_only ON hospital_satisfaction_surveys_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS hssv2_weights_founder_only ON hospital_satisfaction_dim_weights_v2;
CREATE POLICY hssv2_weights_founder_only ON hospital_satisfaction_dim_weights_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- Log helpers (VOLATILE) ----------

CREATE OR REPLACE FUNCTION log_founder_hssv2_survey_seed(p_hospital uuid, p_quarter text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'hssv2.survey_seed',
         jsonb_build_object('hospital_org_id', p_hospital, 'quarter_label', p_quarter)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hssv2_survey_seed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hssv2_survey_seed(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hssv2_score_recompute(p_survey uuid, p_score numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'hssv2.score_recompute',
         jsonb_build_object('survey_id', p_survey, 'composite_score', p_score)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hssv2_score_recompute(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hssv2_score_recompute(uuid, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hssv2_weight_update(p_dimension text, p_weight numeric)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'hssv2.weight_update',
         jsonb_build_object('dimension', p_dimension, 'weight', p_weight)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hssv2_weight_update(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hssv2_weight_update(text, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_hssv2_void(p_survey uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'hssv2.void',
         jsonb_build_object('survey_id', p_survey, 'reason', p_reason)
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_hssv2_void(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hssv2_void(uuid, text) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- 1. KPI snapshot for current quarter
CREATE OR REPLACE FUNCTION founder_hssv2_kpi_snapshot()
RETURNS TABLE (
  surveys_sent_q int,
  surveys_submitted_q int,
  response_rate_pct numeric,
  avg_composite numeric,
  promoter_count int,
  passive_count int,
  detractor_count int,
  nps_score numeric,
  best_dimension text,
  best_dimension_score numeric,
  worst_dimension text,
  worst_dimension_score numeric,
  hospitals_covered int,
  hospitals_total int,
  overdue_count int,
  composite_qoq_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cur_start date := date_trunc('quarter', current_date)::date;
  v_cur_end   date := (date_trunc('quarter', current_date) + interval '3 months - 1 day')::date;
  v_prev_start date := (date_trunc('quarter', current_date) - interval '3 months')::date;
  v_prev_end   date := (date_trunc('quarter', current_date) - interval '1 day')::date;
  v_prev_avg numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT avg(composite_score) INTO v_prev_avg
  FROM hospital_satisfaction_surveys_v2
  WHERE quarter_start = v_prev_start AND status='submitted';

  RETURN QUERY
  WITH cur AS (
    SELECT * FROM hospital_satisfaction_surveys_v2
    WHERE quarter_start = v_cur_start
  ),
  dims AS (
    SELECT 'response_speed' AS d, avg(score_response_speed) AS s FROM cur WHERE status='submitted'
    UNION ALL SELECT 'engineer_professional', avg(score_engineer_professional) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'amc_value', avg(score_amc_value) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'repair_quality', avg(score_repair_quality) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'part_availability', avg(score_part_availability) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'billing_clarity', avg(score_billing_clarity) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'communication', avg(score_communication) FROM cur WHERE status='submitted'
    UNION ALL SELECT 'overall_trust', avg(score_overall_trust) FROM cur WHERE status='submitted'
  )
  SELECT
    (SELECT count(*)::int FROM cur),
    (SELECT count(*)::int FROM cur WHERE status='submitted'),
    CASE WHEN (SELECT count(*) FROM cur) = 0 THEN 0
         ELSE round(100.0 * (SELECT count(*) FROM cur WHERE status='submitted')::numeric
                        / (SELECT count(*) FROM cur)::numeric, 1) END,
    round(coalesce((SELECT avg(composite_score) FROM cur WHERE status='submitted'),0), 2),
    (SELECT count(*)::int FROM cur WHERE nps_band='promoter'),
    (SELECT count(*)::int FROM cur WHERE nps_band='passive'),
    (SELECT count(*)::int FROM cur WHERE nps_band='detractor'),
    CASE WHEN (SELECT count(*) FROM cur WHERE status='submitted') = 0 THEN 0
         ELSE round(100.0 * ((SELECT count(*) FROM cur WHERE nps_band='promoter')
                              - (SELECT count(*) FROM cur WHERE nps_band='detractor'))::numeric
                  / (SELECT count(*) FROM cur WHERE status='submitted')::numeric, 1) END,
    (SELECT d FROM dims WHERE s IS NOT NULL ORDER BY s DESC NULLS LAST LIMIT 1),
    (SELECT round(s,2) FROM dims WHERE s IS NOT NULL ORDER BY s DESC NULLS LAST LIMIT 1),
    (SELECT d FROM dims WHERE s IS NOT NULL ORDER BY s ASC LIMIT 1),
    (SELECT round(s,2) FROM dims WHERE s IS NOT NULL ORDER BY s ASC LIMIT 1),
    (SELECT count(DISTINCT hospital_org_id)::int FROM cur WHERE status='submitted'),
    (SELECT count(*)::int FROM organizations WHERE org_type='hospital'),
    (SELECT count(*)::int FROM cur WHERE status='open' AND quarter_end < current_date),
    round(coalesce((SELECT avg(composite_score) FROM cur WHERE status='submitted'),0) - coalesce(v_prev_avg,0), 2);
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_kpi_snapshot() TO authenticated;

-- 2. Quarterly trend
CREATE OR REPLACE FUNCTION founder_hssv2_quarterly_trend()
RETURNS TABLE (
  id text,
  quarter_label text,
  quarter_start date,
  surveys_sent int,
  surveys_submitted int,
  response_rate_pct numeric,
  avg_composite numeric,
  nps_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.quarter_label::text AS id,
    s.quarter_label,
    s.quarter_start,
    count(*)::int,
    count(*) FILTER (WHERE s.status='submitted')::int,
    CASE WHEN count(*) = 0 THEN 0
         ELSE round(100.0 * count(*) FILTER (WHERE s.status='submitted')::numeric / count(*)::numeric, 1) END,
    round(coalesce(avg(s.composite_score) FILTER (WHERE s.status='submitted'),0), 2),
    CASE WHEN count(*) FILTER (WHERE s.status='submitted') = 0 THEN 0
         ELSE round(100.0 * (count(*) FILTER (WHERE s.nps_band='promoter')
                          - count(*) FILTER (WHERE s.nps_band='detractor'))::numeric
                  / count(*) FILTER (WHERE s.status='submitted')::numeric, 1) END
  FROM hospital_satisfaction_surveys_v2 s
  GROUP BY s.quarter_label, s.quarter_start
  ORDER BY s.quarter_start DESC
  LIMIT 8;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_quarterly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_quarterly_trend() TO authenticated;

-- 3. Dimension breakdown (current quarter)
CREATE OR REPLACE FUNCTION founder_hssv2_dimension_breakdown()
RETURNS TABLE (
  id text,
  dimension text,
  display_label text,
  weight numeric,
  avg_score numeric,
  weighted_contribution numeric,
  responses int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cur_start date := date_trunc('quarter', current_date)::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      avg(score_response_speed) AS response_speed,
      avg(score_engineer_professional) AS engineer_professional,
      avg(score_amc_value) AS amc_value,
      avg(score_repair_quality) AS repair_quality,
      avg(score_part_availability) AS part_availability,
      avg(score_billing_clarity) AS billing_clarity,
      avg(score_communication) AS communication,
      avg(score_overall_trust) AS overall_trust,
      count(*) FILTER (WHERE status='submitted') AS n
    FROM hospital_satisfaction_surveys_v2
    WHERE quarter_start = v_cur_start AND status='submitted'
  ),
  rows AS (
    SELECT 'response_speed' AS d, response_speed AS s, n FROM agg
    UNION ALL SELECT 'engineer_professional', engineer_professional, n FROM agg
    UNION ALL SELECT 'amc_value', amc_value, n FROM agg
    UNION ALL SELECT 'repair_quality', repair_quality, n FROM agg
    UNION ALL SELECT 'part_availability', part_availability, n FROM agg
    UNION ALL SELECT 'billing_clarity', billing_clarity, n FROM agg
    UNION ALL SELECT 'communication', communication, n FROM agg
    UNION ALL SELECT 'overall_trust', overall_trust, n FROM agg
  )
  SELECT
    r.d::text AS id,
    r.d,
    w.display_label,
    w.weight,
    round(coalesce(r.s, 0), 2),
    round(coalesce(r.s, 0) * w.weight, 3),
    coalesce(r.n, 0)::int
  FROM rows r
  JOIN hospital_satisfaction_dim_weights_v2 w ON w.dimension = r.d
  ORDER BY w.weight DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_dimension_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_dimension_breakdown() TO authenticated;

-- 4. Per-hospital current standing
CREATE OR REPLACE FUNCTION founder_hssv2_hospital_standing()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  composite_score numeric,
  nps_band text,
  submitted_at timestamptz,
  status text,
  prior_composite numeric,
  delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cur_start date := date_trunc('quarter', current_date)::date;
  v_prev_start date := (date_trunc('quarter', current_date) - interval '3 months')::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    o.name::text AS hospital_name,
    coalesce(o.city,'')::text AS city,
    s.composite_score,
    s.nps_band,
    s.submitted_at,
    s.status,
    p.composite_score AS prior_composite,
    round(coalesce(s.composite_score,0) - coalesce(p.composite_score,0), 2) AS delta
  FROM hospital_satisfaction_surveys_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  LEFT JOIN hospital_satisfaction_surveys_v2 p
    ON p.hospital_org_id = s.hospital_org_id AND p.quarter_start = v_prev_start
  WHERE s.quarter_start = v_cur_start
  ORDER BY s.composite_score DESC NULLS LAST, o.name
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_hospital_standing() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_hospital_standing() TO authenticated;

-- 5. Detractors needing outreach
CREATE OR REPLACE FUNCTION founder_hssv2_detractor_outreach()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  composite_score numeric,
  worst_dim text,
  worst_dim_score smallint,
  comment text,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cur_start date := date_trunc('quarter', current_date)::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    o.name::text,
    coalesce(o.city,'')::text,
    s.composite_score,
    (SELECT d FROM (VALUES
        ('Response Speed', s.score_response_speed),
        ('Engineer Prof.', s.score_engineer_professional),
        ('AMC Value', s.score_amc_value),
        ('Repair Quality', s.score_repair_quality),
        ('Part Avail.', s.score_part_availability),
        ('Billing Clarity', s.score_billing_clarity),
        ('Communication', s.score_communication),
        ('Overall Trust', s.score_overall_trust)
     ) AS t(d, v) WHERE v IS NOT NULL ORDER BY v ASC LIMIT 1) AS worst_dim,
    (SELECT v FROM (VALUES
        (s.score_response_speed),
        (s.score_engineer_professional),
        (s.score_amc_value),
        (s.score_repair_quality),
        (s.score_part_availability),
        (s.score_billing_clarity),
        (s.score_communication),
        (s.score_overall_trust)
     ) AS t(v) WHERE v IS NOT NULL ORDER BY v ASC LIMIT 1) AS worst_dim_score,
    coalesce(s.free_text_comment,'')::text,
    s.submitted_at
  FROM hospital_satisfaction_surveys_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.quarter_start = v_cur_start
    AND s.status='submitted'
    AND s.nps_band='detractor'
  ORDER BY s.composite_score ASC NULLS LAST
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_detractor_outreach() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_detractor_outreach() TO authenticated;

-- 6. Outstanding (open / overdue) surveys
CREATE OR REPLACE FUNCTION founder_hssv2_outstanding()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  city text,
  quarter_label text,
  sent_at timestamptz,
  quarter_end date,
  days_open int,
  is_overdue boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    o.name::text,
    coalesce(o.city,'')::text,
    s.quarter_label,
    s.sent_at,
    s.quarter_end,
    GREATEST(0, (current_date - s.sent_at::date))::int AS days_open,
    (s.quarter_end < current_date) AS is_overdue
  FROM hospital_satisfaction_surveys_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.status='open'
  ORDER BY s.quarter_end ASC, s.sent_at ASC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_outstanding() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_outstanding() TO authenticated;

-- 7. Dimension weights (config view)
CREATE OR REPLACE FUNCTION founder_hssv2_weights_view()
RETURNS TABLE (
  id text,
  dimension text,
  display_label text,
  weight numeric,
  weight_pct numeric,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.dimension::text AS id,
    w.dimension,
    w.display_label,
    w.weight,
    round(w.weight * 100.0, 1) AS weight_pct,
    w.updated_at
  FROM hospital_satisfaction_dim_weights_v2 w
  ORDER BY w.weight DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_hssv2_weights_view() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hssv2_weights_view() TO authenticated;

COMMIT;