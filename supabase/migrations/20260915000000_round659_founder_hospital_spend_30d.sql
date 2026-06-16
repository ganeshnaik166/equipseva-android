BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_spend_30d();
CREATE OR REPLACE FUNCTION public.founder_hospital_spend_30d()
RETURNS TABLE (
  hospital_user_id  uuid,
  display_name      text,
  spend_30d_rupees  numeric,
  jobs_completed    int,
  avg_job_rupees    numeric,
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
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric,
    count(*)::int,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END,
    EXISTS (
      SELECT 1 FROM public.amc_contracts c
       WHERE c.hospital_user_id = rj.hospital_user_id AND c.status = 'active'
    )
  FROM public.repair_jobs rj
  LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '30 days'
  GROUP BY rj.hospital_user_id, p.full_name
  ORDER BY spend_30d_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_spend_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_spend_30d() TO authenticated;
COMMIT;
