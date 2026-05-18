-- Round 349 — admin_top_engineers: revenue + volume leaderboard for the
-- Founder Dashboard. Ranks by released escrow within the window (the
-- only money the engineer actually earned), tie-breaks on job count.
--
-- AMC visits don't have their own table — `auto_create_due_amc_visits`
-- materializes them as `repair_jobs` rows that flow through the same
-- `repair_job_escrow` pipeline, so a single sum over escrow.status
-- 'released' captures both surfaces.

CREATE OR REPLACE FUNCTION public.admin_top_engineers(
  p_days  int DEFAULT 30,
  p_limit int DEFAULT 5
)
RETURNS TABLE (
  engineer_user_id  uuid,
  full_name         text,
  jobs_completed    bigint,
  revenue_inr       numeric,
  last_completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days   int := greatest(1, least(coalesce(p_days, 30), 365));
  v_limit  int := greatest(1, least(coalesce(p_limit, 5), 50));
  v_cutoff timestamptz := now() - make_interval(days => v_days);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      e.engineer_user_id,
      coalesce(p.full_name, p.email, '(unknown)') AS full_name,
      count(*)::bigint                            AS jobs_completed,
      coalesce(sum(e.amount_rupees), 0)::numeric  AS revenue_inr,
      max(e.released_at)                          AS last_completed_at
    FROM public.repair_job_escrow e
    LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
    WHERE e.status     = 'released'
      AND e.released_at >= v_cutoff
    GROUP BY e.engineer_user_id, p.full_name, p.email
    ORDER BY revenue_inr DESC, jobs_completed DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_top_engineers(int, int) TO authenticated;
