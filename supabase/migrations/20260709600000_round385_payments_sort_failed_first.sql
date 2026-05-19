-- Round 385 — admin_recent_payments: sort failed payments first.
--
-- The Payments queue ordered by created_at DESC, which buried failed
-- payments mid-list. Founder triaging Razorpay failures had to scan
-- visually. Match the r376/r377 urgency-sort pattern: surfaces that
-- carry an urgency signal should order on it.
--
-- New order:
--   1. payment_status='failed' first (urgency).
--   2. created_at DESC tie-break (recency).
--
-- r351's buyer_failed_integrity_count column is preserved unchanged.

DROP FUNCTION IF EXISTS public.admin_recent_payments(int);

CREATE OR REPLACE FUNCTION public.admin_recent_payments(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  order_id uuid,
  order_number text,
  buyer_user_id uuid,
  buyer_name text,
  total_amount numeric,
  payment_status text,
  order_status text,
  razorpay_order_id text,
  payment_id text,
  invoice_url text,
  created_at timestamptz,
  buyer_failed_integrity_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    WITH integrity_counts AS (
      SELECT user_id, count(*)::int AS failed_count
        FROM public.device_integrity_checks
       WHERE pass = false
       GROUP BY user_id
    )
    SELECT
      o.id,
      o.order_number,
      o.buyer_user_id,
      coalesce(p.full_name, p.email, '(unknown)'),
      o.total_amount,
      o.payment_status::text,
      o.order_status::text,
      o.razorpay_order_id,
      o.payment_id,
      o.invoice_url,
      o.created_at,
      coalesce(ic.failed_count, 0)
    FROM public.spare_part_orders o
    LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
    LEFT JOIN integrity_counts ic ON ic.user_id = o.buyer_user_id
    -- Round 385 — failed payments first, recency tie-break.
    ORDER BY CASE WHEN o.payment_status::text = 'failed' THEN 0 ELSE 1 END,
             o.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_recent_payments(int) TO authenticated;
