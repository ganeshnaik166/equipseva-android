BEGIN;

DROP FUNCTION IF EXISTS public.founder_engineer_payout_methods_summary();

CREATE OR REPLACE FUNCTION public.founder_engineer_payout_methods_summary()
RETURNS TABLE (
  total_methods           bigint,
  distinct_engineers      bigint,
  default_methods         bigint,
  upi_methods             bigint,
  bank_methods            bigint,
  verified_methods        bigint,
  unverified_methods      bigint,
  invalid_methods         bigint,
  razorpay_bound_methods  bigint,
  added_7d                bigint,
  added_30d               bigint,
  updated_7d              bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint                                                                AS total_methods,
    COUNT(DISTINCT user_id)::bigint                                                 AS distinct_engineers,
    COUNT(*) FILTER (WHERE is_default = true)::bigint                               AS default_methods,
    COUNT(*) FILTER (WHERE kind = 'upi')::bigint                                    AS upi_methods,
    COUNT(*) FILTER (WHERE kind = 'bank')::bigint                                   AS bank_methods,
    COUNT(*) FILTER (WHERE status = 'verified')::bigint                             AS verified_methods,
    COUNT(*) FILTER (WHERE status = 'unverified')::bigint                           AS unverified_methods,
    COUNT(*) FILTER (WHERE status = 'invalid')::bigint                              AS invalid_methods,
    COUNT(*) FILTER (WHERE razorpay_fund_account_id IS NOT NULL)::bigint            AS razorpay_bound_methods,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::bigint         AS added_7d,
    COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::bigint        AS added_30d,
    COUNT(*) FILTER (WHERE updated_at >= now() - interval '7 days')::bigint         AS updated_7d
  FROM public.engineer_payout_methods;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_payout_methods_summary() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_payout_methods_summary() TO authenticated;

COMMIT;
