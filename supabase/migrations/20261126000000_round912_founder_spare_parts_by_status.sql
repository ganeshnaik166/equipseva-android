BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_by_status();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_status()
RETURNS TABLE (
  status         text,
  cnt_90d        bigint,
  rupees_90d     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(o.order_status, '(unknown)'),
    count(*)::bigint,
    coalesce(sum(o.total_amount), 0)::numeric
  FROM public.spare_part_orders o
  WHERE o.created_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY rupees_90d DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_by_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_by_status() TO authenticated;
COMMIT;
