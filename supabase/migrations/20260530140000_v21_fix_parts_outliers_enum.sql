-- v2.1 PR-D21 follow-up: fix list_parts_cost_outliers two-bug stack.
--
-- 1. PL/pgSQL variable shadowing: RETURNS TABLE declares
--    `equipment_type` as a variable, so referencing the CTE column of
--    the same name ambiguates and fails with 42702. Add
--    `#variable_conflict use_column` directive so unqualified refs
--    resolve to the column, not the variable.
-- 2. Cross-type compare on the exclude-already-reported sub-query:
--    cr.target_id (text) vs w.id (uuid). Raised 42883 once 1 was fixed.
--    content_reports stores target_id as text (varied target types —
--    see 20260424100000_content_reports.sql) so the cast runs on the
--    repair_jobs side.
--
-- On-device the founder admin dashboard's "Parts-cost outliers" tab
-- surfaced both as a generic "Couldn't load" error.

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
#variable_conflict use_column
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
      rj.equipment_type::text AS equipment_type,  -- enum -> text to match RETURNS TABLE
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
    HAVING count(*) >= 3
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
    AND NOT EXISTS (
      SELECT 1
        FROM public.content_reports cr
       WHERE cr.target_id = w.id::text          -- cast uuid to text; target_id stores varied target types
         AND cr.target_type = 'repair_job'
    )
  ORDER BY w.parts_cost / nullif(c.avg_parts, 0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_parts_cost_outliers(int, numeric) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.list_parts_cost_outliers(int, numeric) TO authenticated;
