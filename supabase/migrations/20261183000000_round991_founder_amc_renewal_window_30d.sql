BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_window_30d();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_window_30d()
RETURNS TABLE (
  tier              text,
  total             bigint,
  active            bigint,
  paused            bigint,
  expired           bigint,
  total_mrr_inr     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(c.tier, 'unknown')::text                       AS tier,
    count(*)::bigint                                         AS total,
    count(*) FILTER (WHERE c.status = 'active')::bigint      AS active,
    count(*) FILTER (WHERE c.status = 'paused')::bigint      AS paused,
    count(*) FILTER (WHERE c.status = 'expired')::bigint     AS expired,
    coalesce(sum(c.amount_inr) FILTER (WHERE c.status IN ('active','paused')), 0)::bigint
                                                              AS total_mrr_inr
  FROM public.amc_contracts c
  WHERE c.end_date IS NOT NULL
    AND c.end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
    AND c.end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30
  GROUP BY coalesce(c.tier, 'unknown')
  ORDER BY total_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_window_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_window_30d() TO authenticated;
COMMIT;
