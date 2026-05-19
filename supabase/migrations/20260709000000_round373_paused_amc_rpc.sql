-- Round 373 — drill-down for the r366 "AMC paused" KPI. Mirror of r364
-- (expiring) + r372 (inactive engineers). Founder taps the cell, sees
-- the actual contracts, can contact the hospital to top up the pool.

CREATE OR REPLACE FUNCTION public.admin_amc_paused(
  p_limit int DEFAULT 200
)
RETURNS TABLE (
  contract_id uuid,
  hospital_user_id uuid,
  hospital_name text,
  primary_engineer_id uuid,
  primary_engineer_name text,
  start_date date,
  end_date date,
  monthly_fee_rupees numeric,
  visits_completed int,
  visits_per_year int,
  paused_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int := greatest(1, least(coalesce(p_limit, 200), 500));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT
      c.id,
      c.hospital_user_id,
      coalesce(hp.full_name, hp.email, '(unknown)'),
      c.primary_engineer_id,
      coalesce(ep.full_name, ep.email, '(unknown)'),
      c.start_date,
      c.end_date,
      c.monthly_fee_rupees,
      coalesce(c.visits_completed, 0),
      coalesce(c.visits_per_year, 0),
      -- paused_at is implicit on amc_contracts (no dedicated column).
      -- Use updated_at as the proxy since the v21 status guard touches
      -- updated_at on every status flip.
      c.updated_at
    FROM public.amc_contracts c
    LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
    LEFT JOIN public.engineers e ON e.id = c.primary_engineer_id
    LEFT JOIN public.profiles ep ON ep.id = e.user_id
    WHERE c.status = 'paused'
    ORDER BY c.updated_at DESC NULLS LAST
    LIMIT v_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_amc_paused(int) TO authenticated;
