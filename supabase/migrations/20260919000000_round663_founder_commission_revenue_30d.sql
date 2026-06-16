BEGIN;
DROP FUNCTION IF EXISTS public.founder_commission_revenue_30d();
CREATE OR REPLACE FUNCTION public.founder_commission_revenue_30d()
RETURNS TABLE (
  day_ist               date,
  completed_jobs        bigint,
  gross_rupees          numeric,
  commission_est_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS completed_jobs,
    coalesce(
      (SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric AS gross_rupees,
    coalesce(
      (SELECT round(sum(rj.contracted_amount_rupees) * 0.15, 2)::numeric FROM public.repair_jobs rj
       WHERE rj.status = 'completed'
         AND (rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric AS commission_est_rupees
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_commission_revenue_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_commission_revenue_30d() TO authenticated;
COMMIT;
