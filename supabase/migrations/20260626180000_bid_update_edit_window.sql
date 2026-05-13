-- Round 234 — engineers can only edit their pending bid within 24h.
--
-- Today the UPDATE policy on repair_job_bids gates on
--   (auth.uid() = engineer_user_id AND status = 'pending')
-- so an engineer can mutate amount_rupees on their own pending bid
-- forever. Scenario: engineer submits ₹500, hospital deliberates for
-- a month, then engineer raises to ₹15 000 right before the hospital
-- taps Accept. Hospital sees the new amount only at decision time and
-- has no audit of the swap.
--
-- Add a 24-hour edit window from bid creation. Engineers can correct
-- typos and respond to questions within a day; after that the bid is
-- effectively locked at the displayed amount. To raise the bid later,
-- the engineer must withdraw and submit a new one — which the hospital
-- gets notified about, restoring the "what you see is what you'll get"
-- contract.

DROP POLICY IF EXISTS "Engineers update own pending bid" ON public.repair_job_bids;

CREATE POLICY "Engineers update own pending bid"
  ON public.repair_job_bids
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = engineer_user_id
    AND status = 'pending'
    AND created_at > now() - interval '24 hours'
  )
  WITH CHECK (
    auth.uid() = engineer_user_id
    AND status = 'pending'
    AND created_at > now() - interval '24 hours'
  );

COMMENT ON POLICY "Engineers update own pending bid" ON public.repair_job_bids IS
  'Round 234 — 24h edit window from creation. Engineer-side raise-the-quote-'
  'right-before-accept attacks are blocked once the window closes; engineer '
  'must withdraw + rebid, which re-notifies the hospital.';
