BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrals_cumulative();
CREATE OR REPLACE FUNCTION public.founder_referrals_cumulative()
RETURNS TABLE (
  month_ist     date,
  referrals     bigint,
  cum_referrals bigint,
  first_jobs    bigint,
  cum_first_jobs bigint
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
      coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
                WHERE date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
                WHERE r.referee_first_completed_at IS NOT NULL
                  AND date_trunc('month', (r.referee_first_completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS f
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    sum(monthly.n) OVER (ORDER BY monthly.month_ist),
    monthly.f,
    sum(monthly.f) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrals_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrals_cumulative() TO authenticated;
COMMIT;
