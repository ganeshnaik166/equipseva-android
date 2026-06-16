BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrals_by_month();
CREATE OR REPLACE FUNCTION public.founder_referrals_by_month()
RETURNS TABLE (
  month_ist      date,
  referrals      bigint,
  first_jobs     bigint,
  bounties_paid  bigint
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
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE date_trunc('month', (r.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE r.referee_first_completed_at IS NOT NULL
         AND date_trunc('month', (r.referee_first_completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
       WHERE date_trunc('month', (bp.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrals_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrals_by_month() TO authenticated;
COMMIT;
