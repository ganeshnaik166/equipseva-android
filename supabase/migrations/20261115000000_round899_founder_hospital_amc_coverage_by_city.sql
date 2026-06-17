BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_amc_coverage_by_city();
CREATE OR REPLACE FUNCTION public.founder_hospital_amc_coverage_by_city()
RETURNS TABLE (
  city            text,
  hospitals_total bigint,
  with_amc        bigint,
  without_amc     bigint,
  coverage_pct    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      p.id AS hospital_id,
      EXISTS (
        SELECT 1 FROM public.amc_contracts c
        WHERE c.hospital_user_id = p.id AND c.status = 'active'
      ) AS has_amc
    FROM public.profiles p
    WHERE p.role = 'hospital'
  )
  SELECT
    b.city,
    count(*)::bigint,
    count(*) FILTER (WHERE b.has_amc)::bigint,
    count(*) FILTER (WHERE NOT b.has_amc)::bigint,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(count(*) FILTER (WHERE b.has_amc)::numeric / count(*)::numeric * 100.0, 1)
    END
  FROM base b
  GROUP BY b.city
  ORDER BY hospitals_total DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_amc_coverage_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_amc_coverage_by_city() TO authenticated;
COMMIT;
