-- Round 364 — drill-down RPC for the round 352 dashboard "Expiring 30d" KPI.
-- Founder taps the KPI cell and sees the actual list of contracts
-- ending in the window so they can plan outreach instead of seeing a
-- bare number.

CREATE OR REPLACE FUNCTION public.admin_amc_expiring_soon(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  contract_id uuid,
  hospital_user_id uuid,
  hospital_name text,
  primary_engineer_id uuid,
  primary_engineer_name text,
  end_date date,
  days_remaining int,
  monthly_fee_rupees numeric,
  auto_renew boolean,
  renewal_notifications_sent int
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
      c.id,
      c.hospital_user_id,
      coalesce(hp.full_name, hp.email, '(unknown)'),
      c.primary_engineer_id,
      coalesce(ep.full_name, ep.email, '(unknown)'),
      c.end_date,
      (c.end_date - current_date)::int,
      c.monthly_fee_rupees,
      coalesce(c.auto_renew, false),
      coalesce(c.renewal_notifications_sent, 0)
    FROM public.amc_contracts c
    LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
    LEFT JOIN public.engineers e ON e.id = c.primary_engineer_id
    LEFT JOIN public.profiles ep ON ep.id = e.user_id
    WHERE c.status = 'active'
      AND c.end_date IS NOT NULL
      AND c.end_date >= current_date
      AND c.end_date <= current_date + make_interval(days => v_days)
    ORDER BY c.end_date ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_amc_expiring_soon(int) TO authenticated;
