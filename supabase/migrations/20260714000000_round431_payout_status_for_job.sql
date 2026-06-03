-- Round 431 — payout status visible on both sides of a repair job.
--
-- Symmetric to the engineer's Earnings screen "Transfers to your
-- account" section (round 427). Without this, the hospital pays ₹10,
-- escrow releases, and the hospital has no visibility that the
-- engineer was paid ₹9.30 — looks like the money disappeared into the
-- platform. Surfacing the engineer payout's status + UTR on the
-- hospital's repair-job-detail screen closes the trust gap and
-- reinforces the anti-disintermediation moat (the engineer was paid
-- through the platform, with a verifiable bank trail).
--
-- New SECDEF RPC `payout_status_for_job(p_repair_job_id)` returns the
-- engineer_payouts row for that job, enriched with engineer name +
-- destination label. Caller must be one of:
--   * the hospital that owns the job
--   * the engineer who was assigned
--   * the founder
-- Others get nothing (NULL, not an error — so the call is safe to
-- include in the detail-screen fetch without breaking for pre-payout
-- viewers).

CREATE OR REPLACE FUNCTION public.payout_status_for_job(
  p_repair_job_id uuid
)
RETURNS TABLE (
  id                 uuid,
  amount_paise       bigint,
  status             text,
  mode               text,
  utr                text,
  failure_reason     text,
  destination_label  text,
  engineer_name      text,
  queued_at          timestamptz,
  processed_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_authorised boolean := false;
BEGIN
  IF v_caller IS NULL THEN
    RETURN;  -- empty result, not an error
  END IF;

  -- Authorisation: hospital that owns the job OR the engineer who did
  -- it OR the founder. We resolve once, then return the row.
  SELECT
    public.is_founder()
    OR EXISTS (
      SELECT 1 FROM public.repair_jobs rj
       WHERE rj.id = p_repair_job_id
         AND (rj.hospital_user_id = v_caller OR rj.engineer_id = v_caller)
    )
  INTO v_authorised;

  IF NOT v_authorised THEN
    RETURN;  -- empty result, not an error
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.amount_paise,
    p.status,
    p.mode,
    p.utr,
    p.failure_reason,
    CASE
      WHEN m.id IS NULL              THEN NULL
      WHEN m.kind = 'upi'            THEN m.vpa
      WHEN m.kind = 'bank' AND m.bank_name IS NOT NULL
                                     THEN m.bank_name || ' •••• ' || m.account_number_last4
      ELSE                                'Bank •••• ' || m.account_number_last4
    END AS destination_label,
    pr.full_name AS engineer_name,
    p.queued_at,
    p.processed_at
  FROM public.engineer_payouts p
  LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.repair_job_id = p_repair_job_id
  LIMIT 1;
END
$$;
REVOKE EXECUTE ON FUNCTION public.payout_status_for_job(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.payout_status_for_job(uuid) TO authenticated;
