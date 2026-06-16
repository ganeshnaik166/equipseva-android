BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_hospitals_30d();
CREATE OR REPLACE FUNCTION public.founder_top_hospitals_30d()
RETURNS TABLE (
  hospital_user_id  uuid,
  display_name      text,
  jobs_posted       int,
  jobs_completed    int,
  gross_rupees      numeric,
  has_active_amc    boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    rj.hospital_user_id,
    coalesce(p.full_name, '(hospital)')                                     AS display_name,
    count(*)::int                                                            AS jobs_posted,
    count(*) FILTER (WHERE rj.status = 'completed')::int                     AS jobs_completed,
    coalesce(sum(rj.contracted_amount_rupees) FILTER (WHERE rj.status = 'completed'), 0) AS gross_rupees,
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
       WHERE c.hospital_user_id = rj.hospital_user_id
         AND c.status = 'active'
    )                                                                        AS has_active_amc
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at >= now() - interval '30 days'
  GROUP BY rj.hospital_user_id, p.full_name
  ORDER BY jobs_posted DESC, gross_rupees DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_hospitals_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_hospitals_30d() TO authenticated;
COMMIT;
