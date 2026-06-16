BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_amc_coverage();
CREATE OR REPLACE FUNCTION public.founder_hospital_amc_coverage()
RETURNS TABLE (
  bucket             text,
  hospital_count     bigint,
  total_jobs_30d     bigint,
  gross_30d_rupees   numeric
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
  classified AS (
    SELECT
      h.hospital_user_id,
      CASE WHEN EXISTS (
        SELECT 1 FROM public.amc_contracts c
         WHERE c.hospital_user_id = h.hospital_user_id AND c.status = 'active'
      ) THEN 'With active AMC' ELSE 'No active AMC' END AS bucket
    FROM hospitals h
  )
  SELECT
    c.bucket,
    count(DISTINCT c.hospital_user_id)::bigint,
    coalesce(
      (SELECT count(*)::bigint FROM public.repair_jobs rj2
        WHERE rj2.hospital_user_id IN (SELECT hospital_user_id FROM classified c2 WHERE c2.bucket = c.bucket)
          AND rj2.created_at >= now() - interval '30 days'
      ), 0),
    coalesce(
      (SELECT sum(rj2.contracted_amount_rupees)::numeric FROM public.repair_jobs rj2
        WHERE rj2.hospital_user_id IN (SELECT hospital_user_id FROM classified c3 WHERE c3.bucket = c.bucket)
          AND rj2.status = 'completed'
          AND rj2.completed_at >= now() - interval '30 days'
      ), 0)
  FROM classified c
  GROUP BY c.bucket
  ORDER BY c.bucket DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_amc_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_amc_coverage() TO authenticated;
COMMIT;
