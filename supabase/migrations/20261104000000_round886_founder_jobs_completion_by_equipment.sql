BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_completion_by_equipment();
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_by_equipment()
RETURNS TABLE (
  equipment_type text,
  jobs_90d       bigint,
  p50_hours      numeric,
  p90_hours      numeric,
  avg_hours      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS equipment_type,
      extract(epoch FROM (rj.completed_at - rj.created_at)) / 3600.0 AS hrs
    FROM public.repair_jobs rj
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    b.equipment_type,
    count(*)::bigint,
    coalesce(round(percentile_cont(0.5) WITHIN GROUP (ORDER BY b.hrs)::numeric, 1), 0)::numeric,
    coalesce(round(percentile_cont(0.9) WITHIN GROUP (ORDER BY b.hrs)::numeric, 1), 0)::numeric,
    coalesce(round(avg(b.hrs)::numeric, 1), 0)::numeric
  FROM base b
  GROUP BY b.equipment_type
  ORDER BY jobs_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_completion_by_equipment() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_completion_by_equipment() TO authenticated;
COMMIT;
