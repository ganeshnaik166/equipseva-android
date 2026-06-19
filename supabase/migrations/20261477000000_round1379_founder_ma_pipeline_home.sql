BEGIN;
-- round1379: composite M&A pipeline cockpit (extends r1324)
-- Pure read aggregator. No new tables. Two RPCs for /founder-ma-pipeline-home.



-- ============================================================
-- RPC 1: founder_ma_pipeline_home_summary
-- 14 KPIs aggregating founder_ma_targets + founder_ma_activity_log
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_ma_pipeline_home_summary();

CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_home_summary()
RETURNS TABLE (
  total_targets bigint,
  active_pipeline_count bigint,
  closed_deals_count bigint,
  passed_deals_count bigint,
  conversion_pct_to_closed numeric,
  total_estimated_acquisition_rupees numeric,
  total_closed_value_rupees numeric,
  active_pipeline_value_rupees numeric,
  avg_target_revenue_rupees numeric,
  most_active_segment text,
  most_active_segment_count bigint,
  activities_last_30d_count bigint,
  newest_target_at timestamptz,
  generated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_targets bigint;
  v_active_count bigint;
  v_closed_count bigint;
  v_passed_count bigint;
  v_conv_pct numeric;
  v_total_est numeric;
  v_total_closed_val numeric;
  v_active_val numeric;
  v_avg_revenue numeric;
  v_top_segment text;
  v_top_segment_count bigint;
  v_act_30d bigint;
  v_newest timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- counts by deal_status
  SELECT
    count(*),
    count(*) FILTER (WHERE deal_status NOT IN ('passed','closed')),
    count(*) FILTER (WHERE deal_status = 'closed'),
    count(*) FILTER (WHERE deal_status = 'passed')
  INTO v_total_targets, v_active_count, v_closed_count, v_passed_count
  FROM public.founder_ma_targets;

  -- conversion to closed (closed / (closed + passed) * 100)
  IF (v_closed_count + v_passed_count) > 0 THEN
    v_conv_pct := round((v_closed_count::numeric / (v_closed_count + v_passed_count)::numeric) * 100, 2);
  ELSE
    v_conv_pct := 0;
  END IF;

  -- value rollups
  SELECT
    coalesce(sum(estimated_acquisition_rupees), 0),
    coalesce(sum(estimated_acquisition_rupees) FILTER (WHERE deal_status = 'closed'), 0),
    coalesce(sum(estimated_acquisition_rupees) FILTER (WHERE deal_status NOT IN ('passed','closed')), 0),
    CASE
      WHEN count(*) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL) > 0 THEN
        round(
          sum(target_revenue_rupees_annual) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL)
          / count(*) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL)::numeric
        , 0)
      ELSE 0
    END,
    max(created_at)
  INTO v_total_est, v_total_closed_val, v_active_val, v_avg_revenue, v_newest
  FROM public.founder_ma_targets;

  -- most active segment
  SELECT industry_segment, cnt
  INTO v_top_segment, v_top_segment_count
  FROM (
    SELECT industry_segment, count(*) AS cnt
    FROM public.founder_ma_targets
    WHERE industry_segment IS NOT NULL
    GROUP BY industry_segment
    ORDER BY cnt DESC NULLS LAST, industry_segment ASC
    LIMIT 1
  ) seg;

  -- activity volume last 30d
  SELECT count(*) INTO v_act_30d
  FROM public.founder_ma_activity_log
  WHERE created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce(v_total_targets, 0),
    coalesce(v_active_count, 0),
    coalesce(v_closed_count, 0),
    coalesce(v_passed_count, 0),
    coalesce(v_conv_pct, 0),
    coalesce(v_total_est, 0),
    coalesce(v_total_closed_val, 0),
    coalesce(v_active_val, 0),
    coalesce(v_avg_revenue, 0),
    coalesce(v_top_segment, '(none)'),
    coalesce(v_top_segment_count, 0),
    coalesce(v_act_30d, 0),
    v_newest,
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ma_pipeline_home_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ma_pipeline_home_summary() TO authenticated;

-- ============================================================
-- RPC 2: founder_ma_pipeline_home_top_targets
-- Top targets ordered by priority then estimated value
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_ma_pipeline_home_top_targets(int);

CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_home_top_targets(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  target_company_name text,
  industry_segment text,
  deal_status text,
  deal_priority text,
  estimated_acquisition_rupees numeric,
  last_activity_at timestamptz,
  days_since_activity int
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
  WITH last_act AS (
    SELECT target_id, max(created_at) AS last_at
    FROM public.founder_ma_activity_log
    GROUP BY target_id
  )
  SELECT
    t.id,
    t.target_company_name,
    t.industry_segment,
    t.deal_status,
    t.deal_priority,
    coalesce(t.estimated_acquisition_rupees, 0) AS estimated_acquisition_rupees,
    la.last_at AS last_activity_at,
    CASE
      WHEN la.last_at IS NULL THEN NULL
      ELSE extract(day FROM (now() - la.last_at))::int
    END AS days_since_activity
  FROM public.founder_ma_targets t
  LEFT JOIN last_act la ON la.target_id = t.id
  WHERE t.deal_status NOT IN ('passed','closed')
  ORDER BY
    CASE lower(coalesce(t.deal_priority,''))
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END ASC,
    coalesce(t.estimated_acquisition_rupees, 0) DESC,
    t.created_at DESC
  LIMIT greatest(coalesce(p_limit, 30), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_ma_pipeline_home_top_targets(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ma_pipeline_home_top_targets(int) TO authenticated;

COMMIT;