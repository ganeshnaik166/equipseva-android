-- Round 372 — drill-down RPC for the r371 "Inactive engineers" KPI.
-- Founder taps the KPI and sees the actual list so they can plan
-- outreach (email/call) instead of seeing a bare count.

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
    SELECT
      e.id,
      e.user_id,
      coalesce(p.full_name, '(unnamed)'),
      p.email,
      p.phone,
      e.city,
      e.state,
      e.specializations::text[],
      coalesce(e.experience_years, e.years_experience, 0),
      coalesce(e.rating_avg, 0)::numeric,
      coalesce(e.total_jobs, 0),
      e.created_at,
      (SELECT max(rje.released_at)
         FROM public.repair_job_escrow rje
        WHERE rje.engineer_user_id = e.user_id
          AND rje.status = 'released')
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
    ORDER BY e.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_inactive_engineers(int) TO authenticated;
