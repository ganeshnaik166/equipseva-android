-- Round 234 — engineer_my_amc_earnings RPC.
--
-- AMC visit payouts flow through amc_payment_pool (ledger_kind='debit',
-- source_visit_id = repair_jobs.id). The engineer's Earnings screen
-- only pulled from repair_job_bids though, so AMC visit completions
-- never surfaced and engineers thought they weren't being paid.
--
-- This RPC joins the pool ledger to repair_jobs and filters to the
-- signed-in engineer's visits. The 15% platform take is hard-coded
-- here as the v2.1 default; if/when AMC fees become tier-aware we
-- swap to a derived column lookup.

CREATE OR REPLACE FUNCTION public.engineer_my_amc_earnings()
RETURNS TABLE (
  visit_id uuid,
  visit_completed_at timestamptz,
  amc_contract_id uuid,
  per_visit_cost_rupees numeric,
  engineer_payout_rupees numeric,
  platform_take_rupees numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH my AS (
    SELECT id FROM public.engineers WHERE user_id = auth.uid()
  )
  SELECT
    rj.id AS visit_id,
    rj.completed_at AS visit_completed_at,
    rj.amc_contract_id,
    p.amount_rupees AS per_visit_cost_rupees,
    round(p.amount_rupees * 0.85, 2) AS engineer_payout_rupees,
    round(p.amount_rupees * 0.15, 2) AS platform_take_rupees
  FROM public.amc_payment_pool p
  JOIN public.repair_jobs rj
    ON rj.id = p.source_visit_id
  WHERE p.ledger_kind = 'debit'
    AND rj.engineer_id IN (SELECT id FROM my)
    AND rj.status::text = 'completed'
  ORDER BY rj.completed_at DESC NULLS LAST
  LIMIT 200;
$$;

ALTER FUNCTION public.engineer_my_amc_earnings() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.engineer_my_amc_earnings() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.engineer_my_amc_earnings() TO authenticated;

COMMENT ON FUNCTION public.engineer_my_amc_earnings() IS
  'Round 234 — engineer self-view of AMC visit payouts. 85% take per '
  'v2.1 default; hospital owes per_visit_cost_rupees (already debited '
  'from their amc_payment_pool on visit complete).';
