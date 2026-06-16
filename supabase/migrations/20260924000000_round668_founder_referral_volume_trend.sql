BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_volume_trend();
CREATE OR REPLACE FUNCTION public.founder_referral_volume_trend()
RETURNS TABLE (
  day_ist        date,
  referrals      bigint,
  first_jobs     bigint,
  bounties_paid  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS referrals,
    coalesce(
      (SELECT count(*)::bigint FROM public.engineer_referrals r
       WHERE r.referee_first_completed_at IS NOT NULL
         AND (r.referee_first_completed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS first_jobs,
    coalesce(
      (SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
       WHERE (bp.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS bounties_paid
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_volume_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_volume_trend() TO authenticated;
COMMIT;
