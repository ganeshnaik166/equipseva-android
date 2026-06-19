BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineers_with_no_payouts();
CREATE OR REPLACE FUNCTION public.founder_engineers_with_no_payouts()
RETURNS TABLE (
  total_engineers           bigint,
  verified_engineers        bigint,
  with_zero_payouts_ever    bigint,
  with_zero_payouts_pct     numeric,
  with_at_least_one_paid    bigint,
  with_only_failed_payouts  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_tot FROM public.engineers;
  IF v_tot IS NULL THEN v_tot := 0; END IF;
  RETURN QUERY
  SELECT
    v_tot                                                                                       AS total_engineers,
    coalesce((SELECT count(*)::bigint FROM public.engineers e WHERE e.verification_status = 'verified'), 0) AS verified_engineers,
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_id = e.id)), 0) AS with_zero_payouts_ever,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.engineers e
                                      WHERE NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_id = e.id)), 0)
                    / v_tot, 1) END                                                                AS with_zero_payouts_pct,
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_id = e.id AND p.status IN ('processed','paid'))), 0) AS with_at_least_one_paid,
    coalesce((SELECT count(*)::bigint FROM public.engineers e
              WHERE EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_id = e.id AND p.status = 'failed')
                AND NOT EXISTS (SELECT 1 FROM public.engineer_payouts p WHERE p.engineer_id = e.id AND p.status IN ('processed','paid'))), 0) AS with_only_failed_payouts;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_with_no_payouts() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_with_no_payouts() TO authenticated;
COMMIT;
