BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_part_orders_recent();
CREATE OR REPLACE FUNCTION public.founder_spare_part_orders_recent()
RETURNS TABLE (
  order_id           uuid,
  order_number       text,
  buyer_name         text,
  total_amount       numeric,
  payment_status     text,
  order_status       text,
  created_at         timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.order_number,
    coalesce(p.full_name, '(buyer)'),
    o.total_amount,
    coalesce(o.payment_status, '(unknown)'),
    coalesce(o.order_status, '(unknown)'),
    o.created_at
  FROM public.spare_part_orders o
  LEFT JOIN public.profiles p ON p.id = o.buyer_user_id
  WHERE o.created_at >= now() - interval '30 days'
  ORDER BY o.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_part_orders_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_part_orders_recent() TO authenticated;
COMMIT;
