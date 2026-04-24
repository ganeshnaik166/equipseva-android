-- Add razorpay_order_id column to spare_part_orders.
--
-- Closes a critical signature-binding gap in verify-razorpay-payment: the
-- function verified HMAC(razorpay_order_id + "|" + razorpay_payment_id)
-- but never checked that the razorpay_order_id submitted by the client
-- actually matches the one create-razorpay-order had issued for this
-- spare_part_orders.id. An attacker with two orders (one cheap, one
-- expensive) could pay the cheap one through Razorpay, then replay the
-- resulting signature to complete the expensive one.
--
-- Fix: persist the Razorpay order id returned by Razorpay at
-- create-razorpay-order time, and require an exact match at
-- verify-razorpay-payment time.
--
-- Column is nullable because legacy rows (pre-fix) don't have it; the
-- updated verify function rejects rows with NULL razorpay_order_id with a
-- "re-create the Razorpay order" error. At time of migration there is 1
-- order on the whole platform and 0 completed payments, so no legacy
-- cleanup is needed.

ALTER TABLE public.spare_part_orders
  ADD COLUMN IF NOT EXISTS razorpay_order_id text;

COMMENT ON COLUMN public.spare_part_orders.razorpay_order_id IS
  'Razorpay Orders API id (order_XXXXXX) issued by create-razorpay-order. '
  'verify-razorpay-payment requires the client-submitted razorpay_order_id '
  'to match this value; protects against cross-order signature replay.';
