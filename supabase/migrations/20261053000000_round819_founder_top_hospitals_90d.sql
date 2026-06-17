BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_hospitals_90d();
CREATE OR REPLACE FUNCTION public.founder_top_hospitals_90d()
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
    coalesce(p.full_name, '(hospital)'),
    count(*)::int,
    count(*) FILTER (WHERE rj.status = 'completed')::int,
    coalesce(sum(rj.contracted_amount_rupees) FILTER (WHERE rj.status = 'completed'), 0),
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
       WHERE c.hospital_user_id = rj.hospital_user_id
         AND c.status = 'active'
    )
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.created_at >= now() - interval '90 days'
  GROUP BY rj.hospital_user_id, p.full_name
  ORDER BY jobs_posted DESC, gross_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_hospitals_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_hospitals_90d() TO authenticated;
COMMIT;
