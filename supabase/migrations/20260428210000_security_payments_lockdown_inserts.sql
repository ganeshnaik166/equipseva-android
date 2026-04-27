-- payments INSERT policy let any signed-in user insert a row with
-- payer_user_id IS NULL and an arbitrary payee_user_id. Combined with the
-- SELECT policy gating on payer/payee match, an attacker could fabricate
-- payment rows where they are the payee, then hit any earnings view that
-- sums payments by payee_user_id to inflate their own number. The
-- Razorpay client flow was already stripped in v1 cleanup, so the app
-- has no remaining client-side reason to write to this table.
--
-- Drop the user-INSERT policy entirely. Service-role bypass keeps webhook
-- inserts working; admin tooling can still use the existing admin RPCs.

DROP POLICY IF EXISTS "Users can create payments" ON public.payments;
