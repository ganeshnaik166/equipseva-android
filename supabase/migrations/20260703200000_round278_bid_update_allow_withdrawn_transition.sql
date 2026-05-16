-- Round 278 — fix accidental side-effect of round 234's edit-window policy.
--
-- 20260626180000 added a strict WITH CHECK requiring the post-state
-- bid row to satisfy `status = 'pending' AND created_at > now() -
-- interval '24 hours'`. The intent was to lock the bid AMOUNT after
-- 24h so engineers can't raise-the-quote right before the hospital
-- taps Accept.
--
-- Side-effect: the policy's WITH CHECK also runs on a withdraw
-- transition (`UPDATE SET status='withdrawn'`). Post-state status is
-- 'withdrawn', not 'pending', so the policy REJECTS the update. The
-- engineer's `withdrawBid()` client call (SupabaseRepairBidRepository)
-- silently fails with permission_denied. The comment in the original
-- migration even says "engineer must withdraw and submit a new one"
-- — meaning withdraw was intended to work; the policy just
-- accidentally broke it.
--
-- accept_repair_bid escapes this because it's SECURITY DEFINER and
-- bypasses RLS entirely. withdraw goes through normal PostgREST and
-- gets rejected.
--
-- Fix: split the WITH CHECK so it permits two distinct transitions:
--   • amount/eta/note edits — only within 24h, post-state stays 'pending'
--   • status flip to 'withdrawn' — allowed any time (engineer pulls bid)
-- All other status transitions (accepted/rejected) remain forbidden
-- via this policy because they're driven by SECDEF RPCs.

DROP POLICY IF EXISTS "Engineers update own pending bid" ON public.repair_job_bids;

CREATE POLICY "Engineers update own pending bid"
  ON public.repair_job_bids
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = engineer_user_id
    AND status = 'pending'
  )
  WITH CHECK (
    auth.uid() = engineer_user_id
    AND (
      -- Allowed transition 1: stay 'pending' with edits, but only
      -- inside the 24h amount-edit window.
      (status = 'pending' AND created_at > now() - interval '24 hours')
      -- Allowed transition 2: withdraw anytime. Engineer pulls the
      -- bid; hospital sees it disappear from the bid list. No
      -- raise-the-quote risk because the bid is now off the table.
      OR (status = 'withdrawn')
    )
  );

COMMENT ON POLICY "Engineers update own pending bid" ON public.repair_job_bids IS
  'Round 278 — engineers can edit their pending bid within 24h, or '
  'withdraw it anytime. accept/reject transitions are driven by '
  'SECDEF RPCs (accept_repair_bid / reject_repair_bid) which bypass '
  'RLS, so this policy does not need to allow them.';
