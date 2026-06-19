BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_bounty_payouts_by_month();
CREATE OR REPLACE FUNCTION public.founder_referral_bounty_payouts_by_month()
RETURNS TABLE (
  month_ist     date,
  queued        bigint,
  paid          bigint,
  cancelled     bigint,
  paid_inr      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE date_trunc('month', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS queued,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE b.status = 'paid'
                AND date_trunc('month', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS paid,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE b.status = 'cancelled'
                AND date_trunc('month', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS cancelled,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts b
              WHERE b.status = 'paid'
                AND date_trunc('month', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS paid_inr
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_bounty_payouts_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_bounty_payouts_by_month() TO authenticated;
COMMIT;
