BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_by_visit_frequency();
CREATE OR REPLACE FUNCTION public.founder_amc_by_visit_frequency()
RETURNS TABLE (
  visit_frequency   text,
  total             bigint,
  active            bigint,
  paused            bigint,
  expired           bigint,
  total_mrr_inr     numeric,
  avg_mrr_inr       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(c.visit_frequency, '(unknown)')::text                                 AS visit_frequency,
    count(*)::bigint                                                                AS total,
    count(*) FILTER (WHERE c.status = 'active')::bigint                             AS active,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                             AS paused,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                            AS expired,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status IN ('active','paused')), 0)::numeric AS total_mrr_inr,
    coalesce(round(avg(c.monthly_fee_rupees) FILTER (WHERE c.status IN ('active','paused'))::numeric, 2), 0)::numeric AS avg_mrr_inr
  FROM public.amc_contracts c
  GROUP BY coalesce(c.visit_frequency, '(unknown)')
  ORDER BY total_mrr_inr DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_by_visit_frequency() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_by_visit_frequency() TO authenticated;
COMMIT;
