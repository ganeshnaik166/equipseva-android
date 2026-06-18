BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_bounty_payouts_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_referral_bounty_payouts_by_week_13wk()
RETURNS TABLE (
  week_start    date,
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
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE date_trunc('week', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS queued,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE b.status = 'paid'
                AND date_trunc('week', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS paid,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts b
              WHERE b.status = 'cancelled'
                AND date_trunc('week', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS cancelled,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts b
              WHERE b.status = 'paid'
                AND date_trunc('week', (b.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS paid_inr
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_bounty_payouts_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_bounty_payouts_by_week_13wk() TO authenticated;
COMMIT;
