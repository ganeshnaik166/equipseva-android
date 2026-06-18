BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_completion_by_tier();
CREATE OR REPLACE FUNCTION public.founder_jobs_completion_by_tier()
RETURNS TABLE (
  tier             text,
  accepted_90d     bigint,
  completed_90d    bigint,
  cancelled_90d    bigint,
  completion_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(tier, ord) AS (
    VALUES ('none'::text, 1), ('bronze', 2), ('silver', 3), ('gold', 4)
  ),
  base AS (
    SELECT
      coalesce(ecp.current_tier, 'none') AS tier,
      rj.status
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
    LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = b.engineer_user_id
    WHERE b.status = 'accepted'
      AND b.created_at >= now() - interval '90 days'
  )
  SELECT
    t.tier,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier AND b.status = 'completed'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM base b WHERE b.tier = t.tier AND b.status = 'cancelled'), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM base b WHERE b.tier = t.tier), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM base b WHERE b.tier = t.tier AND b.status = 'completed')
           / (SELECT count(*)::numeric FROM base b WHERE b.tier = t.tier)
           * 100.0, 1)
    END
  FROM tiers t
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_completion_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_completion_by_tier() TO authenticated;
COMMIT;
