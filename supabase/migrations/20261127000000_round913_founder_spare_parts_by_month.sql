BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_by_month();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_month()
RETURNS TABLE (
  month_ist  date,
  orders     bigint,
  rupees     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::bigint,
    coalesce((SELECT sum(o.total_amount)::numeric FROM public.spare_part_orders o
              WHERE date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_by_month() TO authenticated;
COMMIT;
