-- r1491: audit-fix-sweep for r1471-r1490 (7 confirmed bugs, 2 CRITICAL)
-- Audit workflow wm02h8yti. Hardened gotcha-brief held — only 7 bugs vs r1470's 30.
BEGIN;

-- ============================================================
-- r1472 CRITICAL — repair_jobs.is_recurrence + .accepted_at don't exist
-- Rewrite founder_hsq_recompute_current_quarter to drop those refs
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_hsq_recompute_current_quarter();
CREATE OR REPLACE FUNCTION public.founder_hsq_recompute_current_quarter()
RETURNS TABLE (hospitals_scored bigint, quarter_label text)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_q text;
  v_start date;
  v_end date;
  v_count bigint := 0;
  v_actor_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_start := date_trunc('quarter', now())::date;
  v_end   := (date_trunc('quarter', now()) + interval '3 months - 1 day')::date;
  v_q     := to_char(v_start, 'YYYY') || '-Q' || to_char(v_start, 'Q');

  WITH hosp AS (
    SELECT DISTINCT hospital_org_id
    FROM public.repair_jobs
    WHERE created_at >= v_start
      AND created_at <  v_start + interval '3 months'
      AND hospital_org_id IS NOT NULL
  ),
  -- First-response = avg minutes between job created_at and accepted bid's responded_at
  resp AS (
    SELECT r.hospital_org_id,
           avg(EXTRACT(EPOCH FROM (b.responded_at - r.created_at))/60.0)
             FILTER (WHERE b.responded_at IS NOT NULL) AS first_resp_min
    FROM public.repair_jobs r
    LEFT JOIN LATERAL (
      SELECT min(responded_at) AS responded_at
      FROM public.repair_bids
      WHERE job_id = r.id AND status = 'accepted'
    ) b ON true
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  -- Recurrence proxy: completed jobs that share hospital+equipment with another completed job inside 90d
  recur AS (
    SELECT r.hospital_org_id,
           (count(*) FILTER (WHERE r.status='completed' AND EXISTS (
              SELECT 1 FROM public.repair_jobs r2
              WHERE r2.hospital_org_id = r.hospital_org_id
                AND r2.equipment_id = r.equipment_id
                AND r2.id <> r.id
                AND r2.status = 'completed'
                AND r2.completed_at > r.completed_at - interval '90 days'
                AND r2.completed_at < r.completed_at
           ))::numeric / NULLIF(count(*) FILTER (WHERE r.status='completed'), 0)) * 100 AS recur_pct
    FROM public.repair_jobs r
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  agg AS (
    SELECT
      r.hospital_org_id,
      count(*) FILTER (WHERE r.status = 'completed')::int AS jobs_completed,
      avg(r.hospital_rating) FILTER (WHERE r.hospital_rating IS NOT NULL) AS avg_rating
    FROM public.repair_jobs r
    WHERE r.created_at >= v_start AND r.created_at < v_start + interval '3 months'
      AND r.hospital_org_id IS NOT NULL
    GROUP BY r.hospital_org_id
  ),
  scored AS (
    SELECT
      h.hospital_org_id,
      COALESCE(a.jobs_completed, 0) AS jobs_completed,
      ROUND(COALESCE(a.avg_rating, 0)::numeric, 2) AS avg_rating,
      ROUND(((COALESCE(a.avg_rating, 0) - 3) * 50)::numeric, 2) AS nps,
      ROUND(LEAST(100, GREATEST(0, 100 - COALESCE(rc.recur_pct, 0)))::numeric, 2) AS uptime,
      ROUND(COALESCE(rs.first_resp_min, 0)::numeric, 2) AS resp_min,
      ROUND(COALESCE(rc.recur_pct, 0)::numeric, 2) AS recur,
      ROUND((
        (COALESCE(a.avg_rating, 0) / 5.0) * 40
        + (LEAST(100, GREATEST(0, 100 - COALESCE(rc.recur_pct, 0))) / 100.0) * 30
        + (GREATEST(0, 1 - LEAST(120, COALESCE(rs.first_resp_min, 120)) / 120.0)) * 20
        + (GREATEST(0, 1 - LEAST(50, COALESCE(rc.recur_pct, 50)) / 50.0)) * 10
      )::numeric, 2) AS composite
    FROM hosp h
    LEFT JOIN agg a USING (hospital_org_id)
    LEFT JOIN resp rs USING (hospital_org_id)
    LEFT JOIN recur rc USING (hospital_org_id)
  )
  INSERT INTO public.hospital_sq_benchmark_snapshots (
    hospital_org_id, quarter_label, period_start, period_end,
    jobs_completed, avg_hospital_rating, nps_score, uptime_pct,
    first_response_minutes_avg, recurrence_rate_pct, composite_score,
    letter_grade, flagged_for_review
  )
  SELECT
    hospital_org_id, v_q, v_start, v_end,
    jobs_completed, avg_rating, nps, uptime, resp_min, recur, composite,
    CASE WHEN composite >= 80 THEN 'A'
         WHEN composite >= 65 THEN 'B'
         WHEN composite >= 50 THEN 'C'
         ELSE 'D' END,
    (composite < 50)
  FROM scored
  ON CONFLICT (hospital_org_id, quarter_label) DO UPDATE SET
    jobs_completed = EXCLUDED.jobs_completed,
    avg_hospital_rating = EXCLUDED.avg_hospital_rating,
    nps_score = EXCLUDED.nps_score,
    uptime_pct = EXCLUDED.uptime_pct,
    first_response_minutes_avg = EXCLUDED.first_response_minutes_avg,
    recurrence_rate_pct = EXCLUDED.recurrence_rate_pct,
    composite_score = EXCLUDED.composite_score,
    letter_grade = EXCLUDED.letter_grade,
    flagged_for_review = EXCLUDED.flagged_for_review;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  SELECT email INTO v_actor_email FROM public.profiles WHERE id = auth.uid();
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'hsq_recompute_quarter',
    jsonb_build_object('quarter', v_q, 'hospitals_scored', v_count));

  RETURN QUERY SELECT v_count, v_q;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hsq_recompute_current_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hsq_recompute_current_quarter() TO authenticated;

-- ============================================================
-- r1481 CRITICAL — amc_contracts.hospital_org_id doesn't exist
-- Bridge through profiles.organization_id
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_site_visit_redline_90d();
CREATE OR REPLACE FUNCTION public.founder_site_visit_redline_90d()
RETURNS TABLE(hospital_org_id uuid, hospital_name text, last_visited_at timestamptz,
              days_since_last int, has_active_amc boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH lv AS (
    SELECT v.hospital_org_id, max(v.visited_at) AS visited_at
    FROM public.hospital_site_visits v
    WHERE v.status='completed'
    GROUP BY v.hospital_org_id
  )
  SELECT o.id, o.name, lv.visited_at,
         CASE WHEN lv.visited_at IS NULL THEN NULL
              ELSE EXTRACT(EPOCH FROM (now() - lv.visited_at))::int / 86400 END,
         EXISTS (
           SELECT 1 FROM public.amc_contracts a
           JOIN public.profiles p ON p.id = a.hospital_user_id
           WHERE p.organization_id = o.id AND a.status='active'
         )
  FROM public.organizations o
  LEFT JOIN lv ON lv.hospital_org_id = o.id
  WHERE o.kind='hospital'
    AND (lv.visited_at IS NULL OR lv.visited_at < now() - interval '90 days')
  ORDER BY lv.visited_at NULLS FIRST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.founder_site_visit_redline_90d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_site_visit_redline_90d() TO authenticated;

-- ============================================================
-- r1479 MEDIUM — fwll_audience_breakdown_90d counts events forever (no time filter on join)
-- ============================================================
DROP FUNCTION IF EXISTS public.fwll_audience_breakdown_90d();
CREATE OR REPLACE FUNCTION public.fwll_audience_breakdown_90d()
RETURNS TABLE (
  audience text, video_count bigint, total_views bigint,
  avg_views_per_video numeric, avg_completion_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.audience,
    COUNT(DISTINCT v.id)::bigint AS video_count,
    COALESCE(COUNT(e.id),0)::bigint AS total_views,
    CASE WHEN COUNT(DISTINCT v.id) > 0
         THEN ROUND(COUNT(e.id)::numeric / COUNT(DISTINCT v.id)::numeric, 1) ELSE 0 END AS avg_views_per_video,
    CASE WHEN COUNT(e.id) > 0
         THEN ROUND(100.0 * SUM(CASE WHEN e.completed THEN 1 ELSE 0 END)::numeric / COUNT(e.id)::numeric, 1)
         ELSE 0 END AS avg_completion_rate
  FROM public.founder_weekly_loom_videos v
  LEFT JOIN public.founder_weekly_loom_view_events e
    ON e.video_id = v.id AND e.viewed_at >= now() - interval '90 days'
  WHERE v.recorded_at >= now() - interval '90 days'
  GROUP BY v.audience
  ORDER BY total_views DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.fwll_audience_breakdown_90d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fwll_audience_breakdown_90d() TO authenticated;

COMMIT;
