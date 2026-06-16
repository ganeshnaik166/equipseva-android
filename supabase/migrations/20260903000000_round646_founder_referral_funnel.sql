BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_funnel();
CREATE OR REPLACE FUNCTION public.founder_referral_funnel()
RETURNS TABLE (
  stage      text,
  cnt        bigint,
  pct_signup numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cutoff timestamptz := now() - interval '90 days';
  v_signed     bigint;
  v_first_job  bigint;
  v_eligible   bigint;
  v_paid       bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signed
    FROM public.engineer_referrals r WHERE r.created_at >= v_cutoff;

  SELECT count(*)::bigint INTO v_first_job
    FROM public.engineer_referrals r
    WHERE r.created_at >= v_cutoff
      AND r.referee_first_completed_at IS NOT NULL;

  SELECT count(*)::bigint INTO v_eligible
    FROM public.engineer_referrals r
    WHERE r.created_at >= v_cutoff
      AND r.bounty_eligible = true
      AND coalesce(r.bounty_revoked, false) = false;

  SELECT count(DISTINCT bp.referral_id)::bigint INTO v_paid
    FROM public.referral_bounty_payouts bp
    JOIN public.engineer_referrals r ON r.id = bp.referral_id
    WHERE r.created_at >= v_cutoff;

  RETURN QUERY
  SELECT t.stage, t.c::bigint,
    CASE WHEN v_signed = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_signed::numeric) * 100.0, 1)
    END
  FROM (VALUES
    ('1. referee signed up'::text,         v_signed,    1),
    ('2. completed first job'::text,        v_first_job, 2),
    ('3. bounty eligible'::text,            v_eligible,  3),
    ('4. bounty paid out'::text,            v_paid,      4)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_funnel() TO authenticated;
COMMIT;
