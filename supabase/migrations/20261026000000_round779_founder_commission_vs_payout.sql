BEGIN;
DROP FUNCTION IF EXISTS public.founder_commission_vs_payout();
CREATE OR REPLACE FUNCTION public.founder_commission_vs_payout()
RETURNS TABLE (
  month_ist date,
  gmv numeric,
  commission_est numeric,
  payouts_paid numeric,
  net_take numeric
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
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status = 'completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric AS gmv,
    coalesce((SELECT round(sum(rj.contracted_amount_rupees) * 0.07, 2)::numeric FROM public.repair_jobs rj
              WHERE rj.status = 'completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric AS commission_est,
    coalesce((SELECT round(sum(p.amount_paise)::numeric / 100.0, 2)::numeric FROM public.engineer_payouts p
              WHERE p.status = 'processed'
                AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric AS payouts_paid,
    (coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status = 'completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
     - coalesce((SELECT round(sum(p.amount_paise)::numeric / 100.0, 2)::numeric FROM public.engineer_payouts p
                WHERE p.status = 'processed'
                  AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0))::numeric AS net_take
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_commission_vs_payout() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_commission_vs_payout() TO authenticated;
COMMIT;
