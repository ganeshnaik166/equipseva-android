BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_completion_rate();
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_rate()
RETURNS TABLE (
  week_start     date,
  posted         bigint,
  completed      bigint,
  cancelled      bigint,
  completion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  ),
  stats AS (
    SELECT
      w.week_start,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
                WHERE date_trunc('week', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint AS posted,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
                WHERE date_trunc('week', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start AND rj.status = 'completed'), 0)::bigint AS completed,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
                WHERE date_trunc('week', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start AND rj.status = 'cancelled'), 0)::bigint AS cancelled
    FROM weeks w
  )
  SELECT
    s.week_start,
    s.posted,
    s.completed,
    s.cancelled,
    CASE WHEN s.posted = 0 THEN 0::numeric
         ELSE round(s.completed::numeric / s.posted::numeric * 100.0, 1)
    END
  FROM stats s
  ORDER BY s.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_completion_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_completion_rate() TO authenticated;
COMMIT;
