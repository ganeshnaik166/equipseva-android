BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_time_to_complete();
CREATE OR REPLACE FUNCTION public.founder_jobs_time_to_complete()
RETURNS TABLE (
  window_label  text,
  completed     bigint,
  avg_hours     numeric,
  p50_hours     numeric,
  p90_hours     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH paired AS (
    SELECT
      rj.completed_at,
      extract(epoch FROM (rj.completed_at - b.created_at)) / 3600.0 AS hrs
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE rj.status = 'completed'
      AND rj.completed_at IS NOT NULL
      AND b.created_at IS NOT NULL
      AND rj.completed_at >= b.created_at
  ),
  w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text,  1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days'),
      ('90d'::text, 3, now() - interval '90 days')
  )
  SELECT
    w.label,
    count(*)::bigint,
    coalesce(round(avg(p.hrs)::numeric, 1), 0),
    coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY p.hrs))::numeric, 1), 0),
    coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY p.hrs))::numeric, 1), 0)
  FROM w
  LEFT JOIN paired p ON p.completed_at >= w.cutoff
  GROUP BY w.label, w.ord
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_time_to_complete() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_time_to_complete() TO authenticated;
COMMIT;
