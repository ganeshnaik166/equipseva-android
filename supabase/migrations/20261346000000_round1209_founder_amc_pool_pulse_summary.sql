BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_pulse_summary()
RETURNS TABLE (
  total_pool_balance_inr        numeric,
  active_amc_count              bigint,
  avg_balance_per_amc_inr       numeric,
  zero_balance_amc_count        bigint,
  zero_balance_blocked_mrr_inr  numeric,
  credits_30d_inr               numeric,
  debits_30d_inr                numeric,
  refunds_30d_inr               numeric,
  net_flow_30d_inr              numeric,
  top_up_events_30d             bigint,
  debit_events_30d              bigint,
  hospitals_at_zero_balance     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_credits_30d numeric;
  v_debits_30d numeric;
  v_refunds_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_credits_30d
    FROM public.amc_pool_ledger WHERE ledger_kind = 'credit' AND created_at >= now() - interval '30 days';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_debits_30d
    FROM public.amc_pool_ledger WHERE ledger_kind = 'debit' AND created_at >= now() - interval '30 days';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_refunds_30d
    FROM public.amc_pool_ledger WHERE ledger_kind = 'refund' AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce((SELECT sum(coalesce(v.balance_rupees, 0))::numeric
              FROM public.amc_contracts c
              LEFT JOIN public.v_amc_pool_balance v ON v.amc_contract_id = c.id
              WHERE c.status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT round(avg(coalesce(v.balance_rupees, 0))::numeric, 2)
              FROM public.amc_contracts c
              LEFT JOIN public.v_amc_pool_balance v ON v.amc_contract_id = c.id
              WHERE c.status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    v_credits_30d,
    v_debits_30d,
    v_refunds_30d,
    (v_credits_30d - v_debits_30d - v_refunds_30d)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.amc_pool_ledger WHERE ledger_kind = 'credit' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_pool_ledger WHERE ledger_kind = 'debit' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT c.hospital_user_id)::bigint FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_pulse_summary() TO authenticated;
COMMIT;
