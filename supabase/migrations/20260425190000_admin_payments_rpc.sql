-- Founder admin RPC for the Payments page.
-- Returns recent spare-part orders with Razorpay metadata so the founder can
-- spot anomalies (failed payments, missing invoices, late deliveries).

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
  created_at timestamptz
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
      o.created_at
    FROM public.spare_part_orders o
    LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
    ORDER BY o.created_at DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_recent_payments(int) TO authenticated;
