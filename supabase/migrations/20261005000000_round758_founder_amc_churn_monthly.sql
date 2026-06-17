BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_churn_monthly();
CREATE OR REPLACE FUNCTION public.founder_amc_churn_monthly()
RETURNS TABLE (
  month_ist     date,
  churned       bigint,
  active_atend  bigint,
  churn_pct     numeric
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status IN ('cancelled','renewal_failed','expired')
                AND date_trunc('month', (c.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'active' AND c.created_at <= (m.month_ist + interval '1 month')::timestamptz), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.amc_contracts c
                        WHERE c.status = 'active' AND c.created_at <= (m.month_ist + interval '1 month')::timestamptz), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.amc_contracts c
            WHERE c.status IN ('cancelled','renewal_failed','expired')
              AND date_trunc('month', (c.updated_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist)
           / (SELECT count(*)::numeric FROM public.amc_contracts c
              WHERE c.status = 'active' AND c.created_at <= (m.month_ist + interval '1 month')::timestamptz) * 100.0,
         2)
    END
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_monthly() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_monthly() TO authenticated;
COMMIT;
