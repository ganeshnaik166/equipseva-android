-- Round 351 — admin_recent_payments: include the buyer's failed
-- integrity-check count so the Founder Payments row can flag risky
-- buyers inline without a second round-trip per row. Per-row drilldown
-- still goes through the Integrity queue.
--
-- Drop + recreate because adding a RETURNS TABLE column changes the
-- signature in a way CREATE OR REPLACE can't do in place.

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
      -- Pre-aggregate per buyer to keep the outer SELECT a simple JOIN
      -- and let pg pick whichever index plan is cheaper on
      -- device_integrity_checks (user_id, pass) is the round-342 index.
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
    ORDER BY o.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_recent_payments(int) TO authenticated;
