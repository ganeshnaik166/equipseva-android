-- Round 374 — admin_top_engineers: include engineers.id so the
-- dashboard row tap can deep-link to the engineer public profile.
-- r349 returned engineer_user_id only; engineer_public_profile takes
-- engineers.id (different surrogate key).
--
-- DROP + CREATE because adding a RETURNS TABLE column changes the
-- signature in a way CREATE OR REPLACE can't do in place.

DROP FUNCTION IF EXISTS public.admin_top_engineers(int, int);

CREATE OR REPLACE FUNCTION public.admin_top_engineers(
  p_days  int DEFAULT 30,
  p_limit int DEFAULT 5
)
RETURNS TABLE (
  engineer_user_id  uuid,
  engineer_id       uuid,
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
      en.id                                       AS engineer_id,
      coalesce(p.full_name, p.email, '(unknown)') AS full_name,
      count(*)::bigint                            AS jobs_completed,
      coalesce(sum(e.amount_rupees), 0)::numeric  AS revenue_inr,
      max(e.released_at)                          AS last_completed_at
    FROM public.repair_job_escrow e
    LEFT JOIN public.profiles p ON p.id = e.engineer_user_id
    LEFT JOIN public.engineers en ON en.user_id = e.engineer_user_id
    WHERE e.status     = 'released'
      AND e.released_at >= v_cutoff
    GROUP BY e.engineer_user_id, en.id, p.full_name, p.email
    ORDER BY revenue_inr DESC, jobs_completed DESC
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_top_engineers(int, int) TO authenticated;
