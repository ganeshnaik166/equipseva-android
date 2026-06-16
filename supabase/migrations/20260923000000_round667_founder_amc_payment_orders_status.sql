BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_payment_orders_status();
CREATE OR REPLACE FUNCTION public.founder_amc_payment_orders_status()
RETURNS TABLE (
  status         text,
  order_count    bigint,
  total_rupees   numeric,
  oldest_days    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    o.status,
    count(*)::bigint,
    coalesce(sum(o.amount_rupees), 0)::numeric,
    (extract(epoch FROM (now() - min(o.created_at)))::int / 86400)
  FROM public.amc_payment_orders o
  GROUP BY o.status
  ORDER BY total_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_payment_orders_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_payment_orders_status() TO authenticated;
COMMIT;
