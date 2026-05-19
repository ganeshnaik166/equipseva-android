-- Round 368 — engineer-facing self-rank RPC. Sibling of r349
-- admin_top_engineers (founder-gated leaderboard); this version is
-- scoped by auth.uid() so the engineer sees their own monthly rank +
-- jobs + revenue without exposing peers' numbers.
--
-- Surface: engineer Earnings screen sub-card "Your last 30 days" —
-- the rank number is the motivational anchor; jobs + revenue are the
-- supporting detail.

CREATE OR REPLACE FUNCTION public.engineer_my_rank(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  window_days int,
  jobs_completed bigint,
  revenue_inr numeric,
  rank int,
  total_ranked int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days   int := greatest(1, least(coalesce(p_days, 30), 365));
  v_cutoff timestamptz := now() - make_interval(days => v_days);
  v_uid    uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    WITH per_engineer AS (
      SELECT
        e.engineer_user_id,
        count(*)::bigint                   AS jobs,
        sum(e.amount_rupees)::numeric      AS revenue
      FROM public.repair_job_escrow e
      WHERE e.status      = 'released'
        AND e.released_at >= v_cutoff
      GROUP BY e.engineer_user_id
    ),
    ranked AS (
      SELECT
        engineer_user_id,
        jobs,
        revenue,
        rank() OVER (ORDER BY revenue DESC, jobs DESC)::int AS rk
      FROM per_engineer
    ),
    total AS (SELECT count(*)::int AS n FROM per_engineer)
    SELECT
      v_days,
      coalesce(r.jobs, 0)::bigint,
      coalesce(r.revenue, 0)::numeric,
      r.rk,
      (SELECT n FROM total)
    FROM (SELECT 1) one
    LEFT JOIN ranked r ON r.engineer_user_id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.engineer_my_rank(int) TO authenticated;
