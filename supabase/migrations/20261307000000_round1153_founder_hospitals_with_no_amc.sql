BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospitals_with_no_amc();
CREATE OR REPLACE FUNCTION public.founder_hospitals_with_no_amc()
RETURNS TABLE (
  total_hospitals          bigint,
  with_no_amc              bigint,
  with_no_amc_pct          numeric,
  with_active_amc          bigint,
  with_only_expired_amc    bigint,
  with_only_paused_amc     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_tot FROM public.profiles WHERE role = 'hospital';
  IF v_tot IS NULL THEN v_tot := 0; END IF;
  RETURN QUERY
  SELECT
    v_tot AS total_hospitals,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND NOT EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id)), 0) AS with_no_amc,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.profiles p
                                      WHERE p.role = 'hospital'
                                        AND NOT EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id)), 0)
                    / v_tot, 1) END                                                            AS with_no_amc_pct,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id AND c.status = 'active')), 0) AS with_active_amc,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id AND c.status = 'expired')
                AND NOT EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id AND c.status IN ('active','paused'))), 0) AS with_only_expired_amc,
    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id AND c.status = 'paused')
                AND NOT EXISTS (SELECT 1 FROM public.amc_contracts c WHERE c.hospital_user_id = p.id AND c.status = 'active')), 0) AS with_only_paused_amc;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospitals_with_no_amc() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospitals_with_no_amc() TO authenticated;
COMMIT;
