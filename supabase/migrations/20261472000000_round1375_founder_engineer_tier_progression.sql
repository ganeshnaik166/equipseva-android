BEGIN;
-- r1375 — /founder-engineer-tier-progression — engineer tier distribution + climbers.

DROP FUNCTION IF EXISTS public.founder_engineer_tier_progression_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_progression_summary()
RETURNS TABLE (
  total_engineers_active      bigint,
  bronze_count                bigint,
  silver_count                bigint,
  gold_count                  bigint,
  platinum_count              bigint,
  top_tier_engineer_user_id   uuid,
  top_tier_engineer_jobs_count int,
  median_completed_jobs_per_engineer numeric,
  total_completed_jobs_lifetime bigint,
  generated_at                timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH eng_jobs AS (
    SELECT e.user_id, coalesce(e.cached_highest_tier, 'bronze')::text AS tier,
           coalesce(jc.cnt, 0)::int AS jobs_count
    FROM public.engineers e
    LEFT JOIN (
      SELECT engineer_id, count(*) AS cnt FROM public.repair_jobs
      WHERE status = 'completed' GROUP BY engineer_id
    ) jc ON jc.engineer_id = e.id
    WHERE e.verification_status::text = 'verified'
  )
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE tier = 'bronze')::bigint,
    count(*) FILTER (WHERE tier = 'silver')::bigint,
    count(*) FILTER (WHERE tier = 'gold')::bigint,
    count(*) FILTER (WHERE tier = 'platinum')::bigint,
    (SELECT user_id FROM eng_jobs ORDER BY jobs_count DESC LIMIT 1),
    (SELECT jobs_count FROM eng_jobs ORDER BY jobs_count DESC LIMIT 1),
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY jobs_count), 0)::numeric,
    coalesce(sum(jobs_count), 0)::bigint,
    now()
  FROM eng_jobs;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_progression_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_progression_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_tier_progression_climbers(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_progression_climbers(p_limit int DEFAULT 30)
RETURNS TABLE (
  engineer_user_id      uuid,
  current_tier          text,
  jobs_completed_total  int,
  last_completed_at     timestamptz,
  jobs_to_next_tier_estimate int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH eng_data AS (
    SELECT
      e.user_id, e.id AS engineer_id,
      coalesce(e.cached_highest_tier, 'bronze')::text AS tier,
      coalesce(jc.cnt, 0)::int AS jobs_count,
      jc.last_at
    FROM public.engineers e
    LEFT JOIN (
      SELECT engineer_id, count(*) AS cnt, max(completed_at) AS last_at
      FROM public.repair_jobs WHERE status = 'completed'
      GROUP BY engineer_id
    ) jc ON jc.engineer_id = e.id
    WHERE e.verification_status::text = 'verified'
  )
  SELECT
    ed.user_id, ed.tier, ed.jobs_count, ed.last_at,
    CASE
      WHEN ed.tier = 'bronze' THEN greatest(0, 50 - ed.jobs_count)
      WHEN ed.tier = 'silver' THEN greatest(0, 200 - ed.jobs_count)
      WHEN ed.tier = 'gold'   THEN greatest(0, 500 - ed.jobs_count)
      ELSE 0
    END
  FROM eng_data ed
  WHERE ed.tier <> 'platinum'
  ORDER BY ed.jobs_count DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 30), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_progression_climbers(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_progression_climbers(int) TO authenticated;

COMMIT;
