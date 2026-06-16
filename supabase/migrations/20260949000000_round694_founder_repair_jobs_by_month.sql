BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_jobs_by_month();
CREATE OR REPLACE FUNCTION public.founder_repair_jobs_by_month()
RETURNS TABLE (
  month_ist     date,
  posted        bigint,
  completed     bigint,
  cancelled     bigint,
  gross_rupees  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE date_trunc('month', (rj.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE rj.status = 'cancelled'
         AND date_trunc('month', (rj.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::numeric
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_jobs_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_jobs_by_month() TO authenticated;
COMMIT;
