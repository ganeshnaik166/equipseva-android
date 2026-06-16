BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_engineers_30d();
CREATE OR REPLACE FUNCTION public.founder_top_engineers_30d()
RETURNS TABLE (
  engineer_user_id  uuid,
  display_name      text,
  jobs_completed    int,
  gross_rupees      numeric,
  avg_job_rupees    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    b.engineer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::int,
    coalesce(sum(rj.contracted_amount_rupees), 0)::numeric,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(coalesce(sum(rj.contracted_amount_rupees), 0)::numeric / count(*)::numeric, 2)
    END
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
  LEFT JOIN public.profiles p ON p.id = b.engineer_user_id
  WHERE rj.status = 'completed'
    AND rj.completed_at >= now() - interval '30 days'
  GROUP BY b.engineer_user_id, p.full_name
  ORDER BY gross_rupees DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_engineers_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_engineers_30d() TO authenticated;
COMMIT;
