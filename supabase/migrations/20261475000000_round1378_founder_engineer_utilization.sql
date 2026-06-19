BEGIN;
-- r1378 — /founder-engineer-utilization — % utilization per active engineer.
-- Utilization = jobs_completed_30d. Workhorse = top decile. Idle = 0 jobs 30d.

DROP FUNCTION IF EXISTS public.founder_engineer_utilization_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_utilization_summary()
RETURNS TABLE (
  total_active_engineers      bigint,
  engineers_with_zero_jobs_30d bigint,
  engineers_with_zero_jobs_90d bigint,
  workhorse_count             bigint,
  avg_jobs_per_engineer_30d   numeric,
  median_jobs_per_engineer_30d numeric,
  p90_jobs_per_engineer_30d   numeric,
  top_engineer_jobs_30d       int,
  total_jobs_30d              bigint,
  total_jobs_completed_lifetime bigint,
  engineers_active_in_30d     bigint,
  active_engagement_pct       numeric,
  generated_at                timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_total bigint; v_workhorse_threshold int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  SELECT count(*) INTO v_total FROM public.engineers WHERE verification_status::text = 'verified';

  WITH per_eng AS (
    SELECT e.user_id, e.id AS engineer_id,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  )
  SELECT (percentile_cont(0.9) WITHIN GROUP (ORDER BY jobs_30d))::int
  INTO v_workhorse_threshold FROM per_eng;
  v_workhorse_threshold := coalesce(v_workhorse_threshold, 0);

  RETURN QUERY
  WITH per_eng AS (
    SELECT e.user_id, e.id AS engineer_id,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '90 days'), 0)::int AS jobs_90d,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'), 0)::int AS jobs_lifetime
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  )
  SELECT
    v_total,
    count(*) FILTER (WHERE jobs_30d = 0)::bigint,
    count(*) FILTER (WHERE jobs_90d = 0)::bigint,
    count(*) FILTER (WHERE jobs_30d >= GREATEST(v_workhorse_threshold, 1))::bigint,
    coalesce(avg(jobs_30d), 0)::numeric,
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY jobs_30d), 0)::numeric,
    coalesce(percentile_cont(0.9) WITHIN GROUP (ORDER BY jobs_30d), 0)::numeric,
    coalesce(max(jobs_30d), 0)::int,
    coalesce(sum(jobs_30d), 0)::bigint,
    coalesce(sum(jobs_lifetime), 0)::bigint,
    count(*) FILTER (WHERE jobs_30d > 0)::bigint,
    CASE WHEN v_total > 0
         THEN round((count(*) FILTER (WHERE jobs_30d > 0))::numeric * 100 / v_total, 2)
         ELSE 0 END,
    now()
  FROM per_eng;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_utilization_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_utilization_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_utilization_by_engineer(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_utilization_by_engineer(p_limit int DEFAULT 100)
RETURNS TABLE (
  engineer_user_id    uuid,
  cached_highest_tier text,
  jobs_30d            int,
  jobs_90d            int,
  jobs_lifetime       int,
  last_completed_at   timestamptz,
  utilization_band    text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH per_eng AS (
    SELECT e.user_id, e.id AS engineer_id,
           coalesce(e.cached_highest_tier, 'bronze')::text AS tier,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '90 days'), 0)::int AS jobs_90d,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'), 0)::int AS jobs_lifetime,
           (SELECT max(completed_at) FROM public.repair_jobs rj
            WHERE rj.engineer_id = e.id AND rj.status = 'completed') AS last_at
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  )
  SELECT
    p.user_id, p.tier, p.jobs_30d, p.jobs_90d, p.jobs_lifetime, p.last_at,
    CASE WHEN p.jobs_30d = 0 THEN 'idle'
         WHEN p.jobs_30d >= 20 THEN 'workhorse'
         WHEN p.jobs_30d >= 10 THEN 'active'
         WHEN p.jobs_30d >= 3 THEN 'normal'
         ELSE 'low' END
  FROM per_eng p
  ORDER BY p.jobs_30d DESC NULLS LAST, p.jobs_lifetime DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_utilization_by_engineer(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_utilization_by_engineer(int) TO authenticated;

COMMIT;
