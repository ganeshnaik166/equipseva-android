BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_week();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_week()
RETURNS TABLE (
  week_start   date,
  posted       bigint,
  completed    bigint,
  cancelled    bigint,
  gross_rupees numeric
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
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE date_trunc('week', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.status = 'completed' AND date_trunc('week', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              WHERE rj.status = 'cancelled' AND date_trunc('week', (rj.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status = 'completed' AND date_trunc('week', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_week() TO authenticated;
COMMIT;
