BEGIN;
DROP FUNCTION IF EXISTS public.founder_at_risk_revenue();
CREATE OR REPLACE FUNCTION public.founder_at_risk_revenue()
RETURNS TABLE (
  category    text,
  count_v     bigint,
  rupees_v    numeric,
  ord         int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT 'AMCs expiring within 30d'::text, count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 1
    FROM public.amc_contracts WHERE status = 'active' AND end_date BETWEEN v_today AND (v_today + 30)
  UNION ALL
  SELECT 'AMCs paused (pool low)', count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 2
    FROM public.amc_contracts WHERE status = 'paused'
  UNION ALL
  SELECT 'AMCs renewal_failed', count(*)::bigint, coalesce(sum(monthly_fee_rupees), 0)::numeric, 3
    FROM public.amc_contracts WHERE status = 'renewal_failed'
  UNION ALL
  SELECT 'Escrow stuck >30d', count(*)::bigint, coalesce(sum(amount_rupees), 0)::numeric, 4
    FROM public.repair_job_escrow WHERE status IN ('pending','held','in_dispute') AND created_at < now() - interval '30 days'
  UNION ALL
  SELECT 'Open disputes (money at stake)', count(*)::bigint, coalesce(sum(total_money_at_stake_rupees), 0)::numeric, 5
    FROM public.dispute_evidence_packs WHERE status = 'submitted'
  UNION ALL
  SELECT 'Payouts queued/processing', count(*)::bigint, round(coalesce(sum(amount_paise), 0)::numeric / 100.0, 2), 6
    FROM public.engineer_payouts WHERE status IN ('queued','processing')
  ORDER BY ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_at_risk_revenue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_at_risk_revenue() TO authenticated;
COMMIT;
