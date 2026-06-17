BEGIN;
DROP FUNCTION IF EXISTS public.founder_gmv_cumulative();
CREATE OR REPLACE FUNCTION public.founder_gmv_cumulative()
RETURNS TABLE (
  month_ist date,
  monthly_gmv  numeric,
  cumulative_gmv numeric,
  monthly_jobs bigint,
  cumulative_jobs bigint
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
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
                WHERE rj.status = 'completed'
                  AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS gmv,
      coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
                WHERE rj.status = 'completed'
                  AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS j
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.gmv,
    sum(monthly.gmv) OVER (ORDER BY monthly.month_ist),
    monthly.j,
    sum(monthly.j) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gmv_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_gmv_cumulative() TO authenticated;
COMMIT;
