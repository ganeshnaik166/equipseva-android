BEGIN;
DROP FUNCTION IF EXISTS public.founder_commission_by_month();
CREATE OR REPLACE FUNCTION public.founder_commission_by_month()
RETURNS TABLE (
  month_ist               date,
  gross_rupees            numeric,
  commission_est_rupees   numeric,
  commission_pct          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT round(sum(rj.contracted_amount_rupees) * 0.07, 2)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    7::numeric
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_commission_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_commission_by_month() TO authenticated;
COMMIT;
