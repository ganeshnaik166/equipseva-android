BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_tier_current_snapshot();
CREATE OR REPLACE FUNCTION public.founder_amc_tier_current_snapshot()
RETURNS TABLE (
  tier              text,
  active_cnt        bigint,
  paused_cnt        bigint,
  expired_cnt       bigint,
  avg_amount_inr    numeric,
  total_mrr_inr     numeric,
  avg_pool_inr      numeric,
  avg_days_to_end   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(c.tier, 'unknown')::text                                                AS tier,
    count(*) FILTER (WHERE c.status = 'active')::bigint                              AS active_cnt,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                              AS paused_cnt,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                             AS expired_cnt,
    round(avg(c.amount_inr) FILTER (WHERE c.status = 'active')::numeric, 2)          AS avg_amount_inr,
    coalesce(sum(c.amount_inr) FILTER (WHERE c.status = 'active'), 0)::numeric        AS total_mrr_inr,
    round(avg(coalesce(
        (SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0
      )) FILTER (WHERE c.status = 'active')::numeric, 2)                              AS avg_pool_inr,
    round(avg(c.end_date - (now() AT TIME ZONE 'Asia/Kolkata')::date)::numeric FILTER (WHERE c.status = 'active' AND c.end_date IS NOT NULL), 1) AS avg_days_to_end
  FROM public.amc_contracts c
  GROUP BY coalesce(c.tier, 'unknown')
  ORDER BY total_mrr_inr DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_tier_current_snapshot() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_tier_current_snapshot() TO authenticated;
COMMIT;
