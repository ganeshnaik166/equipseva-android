-- Round 376 — admin_inactive_engineers: sort by longest-quiet first so
-- the founder's outreach queue surfaces the highest-urgency engineers
-- at the top. Previous ORDER BY (created_at DESC) put newest-verified
-- at top, which buried the engineers who haven't shipped in months.
--
-- New order:
--   1. last_released_at ASC NULLS FIRST — engineers who NEVER shipped
--      sit first, then longest-quiet next.
--   2. created_at DESC — tie-break (recent verified comes before old).

CREATE OR REPLACE FUNCTION public.admin_inactive_engineers(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  engineer_id uuid,
  user_id uuid,
  full_name text,
  email text,
  phone text,
  city text,
  state text,
  specializations text[],
  experience_years int,
  rating_avg numeric,
  total_jobs int,
  verified_at timestamptz,
  last_released_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    WITH q AS (
      SELECT
        e.id           AS engineer_id,
        e.user_id      AS user_id,
        coalesce(p.full_name, '(unnamed)')                  AS full_name,
        p.email        AS email,
        p.phone        AS phone,
        e.city         AS city,
        e.state        AS state,
        e.specializations::text[]                           AS specializations,
        coalesce(e.experience_years, e.years_experience, 0) AS experience_years,
        coalesce(e.rating_avg, 0)::numeric                  AS rating_avg,
        coalesce(e.total_jobs, 0)                           AS total_jobs,
        e.created_at   AS verified_at,
        (SELECT max(rje.released_at)
           FROM public.repair_job_escrow rje
          WHERE rje.engineer_user_id = e.user_id
            AND rje.status = 'released')                    AS last_released_at
      FROM public.engineers e
      LEFT JOIN public.profiles p ON p.id = e.user_id
      WHERE coalesce(e.verification_status,'pending') = 'verified'
        AND e.created_at < now() - interval '7 days'
        AND NOT EXISTS (
          SELECT 1 FROM public.repair_job_escrow rje
           WHERE rje.engineer_user_id = e.user_id
             AND rje.status = 'released'
             AND rje.released_at >= now() - make_interval(days => v_days)
        )
    )
    SELECT * FROM q
    ORDER BY last_released_at ASC NULLS FIRST, verified_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_inactive_engineers(int) TO authenticated;
