BEGIN;
-- r1360 — Founder Incident RCA Readout.
--
-- Pure read aggregator over founder_incident_postmortems (r1332).
-- Surfaces the "lessons learned" institutional memory:
--   1. How many incidents got a structured postmortem with an RCA classification?
--   2. What is the dominant root-cause class right now? (process_gap vs code_bug vs
--      vendor_failure vs people_error etc.)
--   3. What is the cumulative customer + revenue impact captured in postmortems?
--   4. Which postmortems were published recently, and how is action-item burndown?
--
-- Discipline rule (founder norms, not constraint):
--   Every p0/p1 founder_incident MUST get a postmortem with a non-null
--   root_cause_classification published within 7 days of resolved_at. This page
--   makes the violation surface (gaps + slow publishing) visible.
--
-- NO new tables. Pure SECURITY DEFINER read functions gated by is_founder().

-- ============================================================================
-- 16-KPI summary
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_incident_rca_readout_summary();
CREATE OR REPLACE FUNCTION public.founder_incident_rca_readout_summary()
RETURNS TABLE (
  total_postmortems_with_rca   bigint,
  postmortems_last_30d         bigint,
  avg_resolution_duration_hours numeric,
  avg_detection_lag_minutes    numeric,
  total_revenue_impact_rupees  numeric,
  total_affected_users         bigint,
  process_gap_count            bigint,
  code_bug_count               bigint,
  data_inconsistency_count     bigint,
  vendor_failure_count         bigint,
  external_event_count         bigint,
  people_error_count           bigint,
  design_gap_count             bigint,
  other_rca_count              bigint,
  top_root_cause               text,
  top_root_cause_count         bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_cause   text;
  v_top_count   bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Resolve the dominant root cause (excludes NULLs from the ranking).
  SELECT root_cause_classification, count(*)::bigint
    INTO v_top_cause, v_top_count
  FROM public.founder_incident_postmortems
  WHERE root_cause_classification IS NOT NULL
  GROUP BY root_cause_classification
  ORDER BY count(*) DESC, root_cause_classification ASC
  LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint
              FROM public.founder_incident_postmortems
              WHERE root_cause_classification IS NOT NULL), 0),
    coalesce((SELECT count(*)::bigint
              FROM public.founder_incident_postmortems
              WHERE written_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(resolution_duration_minutes) / 60.0, 2)::numeric
              FROM public.founder_incident_postmortems
              WHERE resolution_duration_minutes IS NOT NULL), 0)::numeric,
    coalesce((SELECT round(avg(detection_lag_minutes)::numeric, 1)
              FROM public.founder_incident_postmortems
              WHERE detection_lag_minutes IS NOT NULL), 0)::numeric,
    coalesce((SELECT sum(revenue_impact_rupees)
              FROM public.founder_incident_postmortems), 0)::numeric,
    coalesce((SELECT sum(affected_user_count)::bigint
              FROM public.founder_incident_postmortems), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'process_gap'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'code_bug'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'data_inconsistency'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'vendor_failure'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'external_event'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'people_error'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'design_gap'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incident_postmortems
              WHERE root_cause_classification = 'other'
                 OR root_cause_classification IS NULL), 0),
    coalesce(v_top_cause, 'n/a')::text,
    coalesce(v_top_count, 0)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_incident_rca_readout_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_incident_rca_readout_summary() TO authenticated;

-- ============================================================================
-- Recent published readouts (joined with action-item burndown)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_incident_rca_readout_recent(int);
CREATE OR REPLACE FUNCTION public.founder_incident_rca_readout_recent(
  p_limit int DEFAULT 30
)
RETURNS TABLE (
  postmortem_id              uuid,
  incident_id                uuid,
  title                      text,
  root_cause_classification  text,
  severity                   text,
  revenue_impact_rupees      numeric,
  affected_user_count        int,
  resolution_duration_hours  numeric,
  detection_lag_minutes      int,
  written_at                 timestamptz,
  action_items_open_count    int,
  action_items_total_count   int,
  completion_pct             numeric,
  source_domain              text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH ai_counts AS (
    SELECT
      postmortem_id,
      count(*) FILTER (WHERE status IN ('open','in_progress'))::int AS open_count,
      count(*)::int AS total_count,
      count(*) FILTER (WHERE status = 'closed')::int AS closed_count
    FROM public.founder_incident_postmortem_action_items
    GROUP BY postmortem_id
  )
  SELECT
    pm.id                                                  AS postmortem_id,
    pm.incident_id,
    pm.title,
    coalesce(pm.root_cause_classification, 'other')::text  AS root_cause_classification,
    coalesce(pm.severity_at_resolution, 'p3')::text        AS severity,
    coalesce(pm.revenue_impact_rupees, 0)::numeric         AS revenue_impact_rupees,
    coalesce(pm.affected_user_count, 0)::int               AS affected_user_count,
    CASE WHEN pm.resolution_duration_minutes IS NULL THEN NULL
         ELSE round(pm.resolution_duration_minutes / 60.0, 2)::numeric END
                                                           AS resolution_duration_hours,
    pm.detection_lag_minutes,
    pm.written_at,
    coalesce(ai.open_count, 0)::int                        AS action_items_open_count,
    coalesce(ai.total_count, pm.action_items_count, 0)::int AS action_items_total_count,
    CASE
      WHEN coalesce(ai.total_count, pm.action_items_count, 0) = 0 THEN 0::numeric
      ELSE round(100.0 * coalesce(ai.closed_count, pm.action_items_closed_count, 0)
                       / coalesce(ai.total_count, pm.action_items_count, 1), 1)
    END                                                    AS completion_pct,
    CASE coalesce(pm.root_cause_classification, 'other')
      WHEN 'process_gap'        THEN 'ops-process'
      WHEN 'code_bug'           THEN 'engineering'
      WHEN 'data_inconsistency' THEN 'data-platform'
      WHEN 'vendor_failure'     THEN 'vendor-mgmt'
      WHEN 'external_event'     THEN 'external'
      WHEN 'people_error'       THEN 'people-ops'
      WHEN 'design_gap'         THEN 'product-design'
      ELSE                          'general'
    END::text                                              AS source_domain
  FROM public.founder_incident_postmortems pm
  LEFT JOIN ai_counts ai ON ai.postmortem_id = pm.id
  ORDER BY pm.written_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_incident_rca_readout_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_incident_rca_readout_recent(int) TO authenticated;

COMMIT;