BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_signals_trend();
CREATE OR REPLACE FUNCTION public.founder_demand_signals_trend()
RETURNS TABLE (
  day_ist          date,
  signals          bigint,
  distinct_skus    bigint,
  distinct_users   bigint
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
      (SELECT count(*)::bigint
       FROM public.spare_part_demand_signals s
       WHERE (s.occurred_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS signals,
    coalesce(
      (SELECT count(DISTINCT (
         coalesce(lower(s.equipment_brand),'?')||'|'||
         coalesce(lower(s.equipment_model),'?')||'|'||
         coalesce(lower(s.part_number),'?')))::bigint
       FROM public.spare_part_demand_signals s
       WHERE (s.occurred_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS distinct_skus,
    coalesce(
      (SELECT count(DISTINCT s.reporter_user_id)::bigint
       FROM public.spare_part_demand_signals s
       WHERE (s.occurred_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint AS distinct_users
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_signals_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signals_trend() TO authenticated;
COMMIT;
