-- Round 430 — founder dashboard summary RPC for the engineer_payouts queue.
--
-- Without a visible hint on the founder dashboard, the founder has to
-- remember to open the round-428 admin screen to find out whether any
-- engineers are waiting on a manual GPay. Especially during the
-- RazorpayX-less period (~14 days from GSTIN approval), missing a
-- queued payout means an engineer waits longer to be paid for work
-- already done.
--
-- New SECDEF RPC `founder_engineer_payouts_summary()` returns the
-- counts + ₹ totals the dashboard tile renders. Single row, founder-
-- only.

CREATE OR REPLACE FUNCTION public.founder_engineer_payouts_summary()
RETURNS TABLE (
  queued_count            integer,
  queued_amount_paise     bigint,
  processing_count        integer,
  failed_count            integer,
  failed_amount_paise     bigint,
  last_processed_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN status = 'queued'     THEN 1 ELSE 0 END), 0)::int,
    COALESCE(SUM(CASE WHEN status = 'queued'     THEN amount_paise ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END), 0)::int,
    COALESCE(SUM(CASE WHEN status = 'failed'     THEN 1 ELSE 0 END), 0)::int,
    COALESCE(SUM(CASE WHEN status = 'failed'     THEN amount_paise ELSE 0 END), 0)::bigint,
    MAX(CASE WHEN status = 'processed' THEN processed_at END)
  FROM public.engineer_payouts;
END
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_payouts_summary() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_payouts_summary() TO authenticated;
