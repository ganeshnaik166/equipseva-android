-- v2.1 PR-D13: parts-cost outlier detection (T2.8 in strategy memo).
--
-- "Parts-vs-labor ratio outliers — itemized invoice required. If
-- parts cost > 5x category average → manual review."
--
-- Adapted: we compare parts_cost vs the category-wide average of
-- actual_cost_parts on completed jobs in the trailing window. Jobs
-- where the engineer's parts charge is >5x the category average get
-- surfaced for admin review. This is the third leg of the audit-
-- trail / cash-survey / engineer-pair triad: detection of subtle
-- inflation that the other detectors don't catch.
--
-- Why threshold 5x and not 2x: hospital equipment varies wildly —
-- a single proximal humerus plate can legitimately cost 20-30x a
-- thermistor. We want to surface obvious abuse, not penalize the
-- mid-distribution. Tunable via the RPC parameter.
--
-- Output: one row per outlier job with the comparison numbers so
-- admin can decide-vs-flag without re-querying. Jobs that already
-- have an open content_report are excluded — once reviewed, they
-- shouldn't keep re-appearing.

CREATE OR REPLACE FUNCTION public.list_parts_cost_outliers(
  p_window_days  int     DEFAULT 90,
  p_multiplier   numeric DEFAULT 5.0
)
RETURNS TABLE (
  repair_job_id        uuid,
  job_number           text,
  engineer_id          uuid,
  engineer_name        text,
  hospital_user_id     uuid,
  hospital_name        text,
  equipment_type       text,
  equipment_brand      text,
  equipment_model      text,
  parts_cost           numeric,
  category_avg_parts   numeric,
  ratio                numeric,
  completed_at         timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_multiplier <= 0 OR p_window_days <= 0 THEN
    RAISE EXCEPTION 'multiplier and window_days must be > 0' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  WITH window_jobs AS (
    SELECT
      rj.id,
      rj.job_number,
      rj.engineer_id,
      rj.hospital_user_id,
      rj.equipment_type,
      rj.equipment_brand,
      rj.equipment_model,
      coalesce(rj.actual_cost_parts, 0) AS parts_cost,
      rj.completed_at
    FROM public.repair_jobs rj
    WHERE rj.status::text = 'completed'
      AND rj.completed_at IS NOT NULL
      AND rj.completed_at >= now() - make_interval(days => p_window_days)
      AND coalesce(rj.actual_cost_parts, 0) > 0
  ),
  cat_avg AS (
    SELECT equipment_type,
           avg(parts_cost) AS avg_parts
      FROM window_jobs
     GROUP BY equipment_type
    HAVING count(*) >= 3   -- need at least 3 samples for the avg to mean anything
  )
  SELECT
    w.id                                                           AS repair_job_id,
    w.job_number,
    w.engineer_id,
    coalesce(p_eng.full_name, '(unnamed)')                          AS engineer_name,
    w.hospital_user_id,
    coalesce(p_hosp.full_name, '(unnamed)')                         AS hospital_name,
    w.equipment_type,
    w.equipment_brand,
    w.equipment_model,
    w.parts_cost,
    round(c.avg_parts, 2)                                          AS category_avg_parts,
    round(w.parts_cost / nullif(c.avg_parts, 0), 2)                AS ratio,
    w.completed_at
  FROM window_jobs w
  JOIN cat_avg c ON c.equipment_type = w.equipment_type
  LEFT JOIN public.engineers e ON e.id = w.engineer_id
  LEFT JOIN public.profiles  p_eng  ON p_eng.id = e.user_id
  LEFT JOIN public.profiles  p_hosp ON p_hosp.id = w.hospital_user_id
  WHERE w.parts_cost > p_multiplier * c.avg_parts
    -- Exclude jobs with an open content report — already on admin's queue.
    AND NOT EXISTS (
      SELECT 1
        FROM public.content_reports cr
       WHERE cr.target_id = w.id
         AND cr.target_type = 'repair_job'
    )
  ORDER BY w.parts_cost / nullif(c.avg_parts, 0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_parts_cost_outliers(int, numeric) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.list_parts_cost_outliers(int, numeric) TO authenticated;
