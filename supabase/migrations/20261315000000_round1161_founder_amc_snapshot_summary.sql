BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_snapshot_summary()
RETURNS TABLE (
  total_contracts          bigint,
  active_count             bigint,
  paused_count             bigint,
  expired_count            bigint,
  active_mrr_inr           numeric,
  paused_mrr_inr           numeric,
  avg_active_mrr_inr       numeric,
  expiring_30d             bigint,
  expiring_30d_mrr_inr     numeric,
  total_pool_balance_inr   numeric,
  zero_balance_active      bigint,
  new_amcs_30d             bigint,
  expired_30d              bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'paused'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'expired'), 0),
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'paused'), 0),
    CASE WHEN (SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active') = 0 THEN 0::numeric
         ELSE round(coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0)
                    / (SELECT count(*)::numeric FROM public.amc_contracts WHERE status = 'active'), 2) END,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'
              AND end_date IS NOT NULL AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30), 0),
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'
              AND end_date IS NOT NULL AND end_date < (now() AT TIME ZONE 'Asia/Kolkata')::date + 30), 0),
    coalesce((SELECT sum(balance_rupees)::numeric FROM public.v_amc_pool_balance), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c WHERE c.status = 'active'
              AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'expired'
              AND end_date IS NOT NULL AND end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - 30
              AND end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_snapshot_summary() TO authenticated;
COMMIT;
