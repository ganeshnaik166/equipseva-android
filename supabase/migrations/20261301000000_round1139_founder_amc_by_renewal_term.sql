BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_by_renewal_term();
CREATE OR REPLACE FUNCTION public.founder_amc_by_renewal_term()
RETURNS TABLE (
  renewal_term_months   int,
  total                 bigint,
  active                bigint,
  paused                bigint,
  expired               bigint,
  total_mrr_inr         numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.renewal_term_months,
    count(*)::bigint                                                    AS total,
    count(*) FILTER (WHERE c.status = 'active')::bigint                 AS active,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                 AS paused,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                AS expired,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status IN ('active','paused')), 0)::numeric AS total_mrr_inr
  FROM public.amc_contracts c
  GROUP BY c.renewal_term_months
  ORDER BY c.renewal_term_months;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_by_renewal_term() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_by_renewal_term() TO authenticated;
COMMIT;
