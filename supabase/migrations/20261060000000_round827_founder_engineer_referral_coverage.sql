BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_referral_coverage();
CREATE OR REPLACE FUNCTION public.founder_engineer_referral_coverage()
RETURNS TABLE (
  total_engineers   bigint,
  with_referrals    bigint,
  paid_referrals    bigint,
  coverage_pct      numeric,
  paid_pct          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_with  bigint;
  v_paid  bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_total
    FROM public.profiles p WHERE p.role = 'engineer';
  SELECT count(DISTINCT referrer_user_id)::bigint INTO v_with
    FROM public.engineer_referrals;
  SELECT count(DISTINCT r.referrer_user_id)::bigint INTO v_paid
    FROM public.engineer_referrals r
    JOIN public.referral_bounty_payouts b ON b.referral_id = r.id;
  RETURN QUERY
  SELECT
    v_total,
    v_with,
    v_paid,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(v_with::numeric / v_total::numeric * 100.0, 1)
    END,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(v_paid::numeric / v_total::numeric * 100.0, 1)
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_referral_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_referral_coverage() TO authenticated;
COMMIT;
