BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_intake_trend();
CREATE OR REPLACE FUNCTION public.founder_bonded_intake_trend()
RETURNS TABLE (
  day_ist        date,
  intake_rows    bigint,
  qty_received   bigint,
  total_cost     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.bonded_parts_intake i
       WHERE (i.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(i.quantity_received)::bigint FROM public.bonded_parts_intake i
       WHERE (i.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(i.total_cost_rupees)::numeric FROM public.bonded_parts_intake i
       WHERE (i.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::numeric
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_intake_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_intake_trend() TO authenticated;
COMMIT;
