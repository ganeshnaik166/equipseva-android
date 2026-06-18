BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_contracts_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_amc_contracts_by_day_30d()
RETURNS TABLE (
  day_ist        date,
  new_amcs       bigint,
  total_mrr_inr  numeric,
  distinct_tiers bigint
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
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS new_amcs,
    coalesce((SELECT sum(c.amount_inr)::numeric FROM public.amc_contracts c
              WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS total_mrr_inr,
    coalesce((SELECT count(DISTINCT c.tier)::bigint FROM public.amc_contracts c
              WHERE (c.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS distinct_tiers
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_contracts_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_contracts_by_day_30d() TO authenticated;
COMMIT;
