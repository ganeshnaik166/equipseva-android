BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrals_recent();
CREATE OR REPLACE FUNCTION public.founder_referrals_recent()
RETURNS TABLE (
  id                       uuid,
  referrer_name            text,
  referee_name             text,
  referee_first_completed_at timestamptz,
  bounty_eligible          boolean,
  bounty_paid              boolean,
  created_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    coalesce(pr.full_name, '(referrer)'),
    coalesce(pe.full_name, '(referee)'),
    r.referee_first_completed_at,
    coalesce(r.bounty_eligible, false),
    EXISTS (SELECT 1 FROM public.referral_bounty_payouts bp WHERE bp.referral_id = r.id),
    r.created_at
  FROM public.engineer_referrals r
  LEFT JOIN public.profiles pr ON pr.id = r.referrer_user_id
  LEFT JOIN public.profiles pe ON pe.id = r.referee_user_id
  WHERE r.created_at >= now() - interval '30 days'
  ORDER BY r.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrals_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrals_recent() TO authenticated;
COMMIT;
