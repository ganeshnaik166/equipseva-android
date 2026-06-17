BEGIN;
DROP FUNCTION IF EXISTS public.founder_verified_engineer_growth();
CREATE OR REPLACE FUNCTION public.founder_verified_engineer_growth()
RETURNS TABLE (
  month_ist  date,
  new_verified bigint,
  cumulative   bigint
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
      coalesce((SELECT count(*)::bigint FROM public.engineers e
                WHERE e.verification_status = 'verified'
                  AND date_trunc('month', (e.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint AS new_verified
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.new_verified,
    sum(monthly.new_verified) OVER (ORDER BY monthly.month_ist) AS cumulative
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_verified_engineer_growth() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_verified_engineer_growth() TO authenticated;
COMMIT;
