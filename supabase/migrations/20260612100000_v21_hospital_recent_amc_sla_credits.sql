-- v2.1 PR-D34: hospital home — recent AMC SLA breach credits summary.
--
-- PR-C4 detects SLA breaches on AMC visits and issues a goodwill
-- credit (25% of per-visit cost, capped at ₹10K) into the
-- amc_payment_pool. Today the hospital sees:
--   * a push when the breach lands (PR-D22 amc_sla_breach kind)
--   * the breach inline on the SLA tab of AMC contract detail
--
-- ...but no aggregated visibility on the hospital home that says
-- "EquipSeva credited you ₹X this month for SLA misses". That's a
-- trust signal we're losing — a real engineer-bypass deterrent
-- when the hospital can SEE we paid them back automatically.
--
-- This RPC returns a single-row summary for the caller (hospital):
--   * total credit_issued_rupees in the trailing 30-day window
--   * breach_count contributing to the total
--   * most_recent_at — the latest breach detected_at (if any)
-- Card hides when total is zero (no breaches in window).
--
-- Caller mapped via auth.uid; only sees their own contracts'
-- breaches. is_admin / is_founder also pass — useful for ops eyes.

CREATE OR REPLACE FUNCTION public.hospital_recent_amc_sla_credits(
  p_window_days int DEFAULT 30
)
RETURNS TABLE (
  total_credit_rupees   numeric,
  breach_count          int,
  most_recent_at        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_window_days <= 0 OR p_window_days > 365 THEN
    RAISE EXCEPTION 'window_days must be 1..365' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    coalesce(sum(b.credit_issued_rupees), 0)::numeric  AS total_credit_rupees,
    coalesce(count(*) FILTER (WHERE b.credit_issued_rupees > 0), 0)::int AS breach_count,
    max(b.detected_at)                                  AS most_recent_at
    FROM public.amc_sla_breaches b
    JOIN public.amc_contracts c ON c.id = b.amc_contract_id
   WHERE b.detected_at >= now() - make_interval(days => p_window_days)
     AND (
       c.hospital_user_id = v_caller
       OR public.is_admin(v_caller)
       OR public.is_founder()
     );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_recent_amc_sla_credits(int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.hospital_recent_amc_sla_credits(int) TO authenticated;
