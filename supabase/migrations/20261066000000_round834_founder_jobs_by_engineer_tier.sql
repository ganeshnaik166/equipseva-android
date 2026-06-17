BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_by_engineer_tier();
CREATE OR REPLACE FUNCTION public.founder_jobs_by_engineer_tier()
RETURNS TABLE (
  tier            text,
  jobs_90d        bigint,
  gross_90d       numeric,
  engineers       bigint,
  avg_per_engineer numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze'::text, 2), ('silver'::text, 3), ('gold'::text, 4)
  ),
  per_tier AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      rj.contracted_amount_rupees,
      b.engineer_user_id
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = b.engineer_user_id
    WHERE rj.status = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    coalesce((SELECT sum(pt.contracted_amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)::numeric,
    coalesce((SELECT count(DISTINCT pt.engineer_user_id)::bigint FROM per_tier pt WHERE pt.tier = t.tier), 0)::bigint,
    CASE WHEN coalesce((SELECT count(DISTINCT pt.engineer_user_id) FROM per_tier pt WHERE pt.tier = t.tier), 0) = 0 THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(pt.contracted_amount_rupees)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 0)
           / coalesce((SELECT count(DISTINCT pt.engineer_user_id)::numeric FROM per_tier pt WHERE pt.tier = t.tier), 1)
         , 2)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_by_engineer_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_by_engineer_tier() TO authenticated;
COMMIT;
