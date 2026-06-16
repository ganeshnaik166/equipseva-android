BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_geo();
CREATE OR REPLACE FUNCTION public.founder_hospital_geo()
RETURNS TABLE (
  city            text,
  hospital_cnt    bigint,
  jobs_30d        bigint,
  active_amc_cnt  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH hospitals AS (
    SELECT DISTINCT rj.hospital_user_id
    FROM public.repair_jobs rj
  ),
  with_city AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      h.hospital_user_id
    FROM hospitals h
    LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint AS hospital_cnt,
    coalesce((
      SELECT count(*)::bigint
      FROM public.repair_jobs rj
      WHERE rj.hospital_user_id IN (
        SELECT hospital_user_id FROM with_city wc2 WHERE wc2.city = wc.city
      )
      AND rj.created_at >= now() - interval '30 days'
    ), 0) AS jobs_30d,
    coalesce((
      SELECT count(DISTINCT c.hospital_user_id)::bigint
      FROM public.amc_contracts c
      WHERE c.hospital_user_id IN (
        SELECT hospital_user_id FROM with_city wc3 WHERE wc3.city = wc.city
      )
      AND c.status = 'active'
    ), 0) AS active_amc_cnt
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY hospital_cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_geo() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_geo() TO authenticated;
COMMIT;
