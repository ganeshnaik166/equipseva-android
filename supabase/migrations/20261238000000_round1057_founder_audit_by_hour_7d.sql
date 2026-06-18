BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_by_hour_7d();
CREATE OR REPLACE FUNCTION public.founder_audit_by_hour_7d()
RETURNS TABLE (
  hour_ist      int,
  cnt           bigint,
  pct_of_total  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total
  FROM public.founder_action_log
  WHERE created_at >= now() - interval '7 days';
  IF v_total IS NULL THEN v_total := 0; END IF;

  RETURN QUERY
  WITH hours AS (
    SELECT generate_series(0, 23) AS hour_ist
  )
  SELECT
    h.hour_ist,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE a.created_at >= now() - interval '7 days'
                AND extract(hour FROM (a.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)
                                                              AS cnt,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(
           100.0 * coalesce((SELECT count(*)::numeric FROM public.founder_action_log a
                             WHERE a.created_at >= now() - interval '7 days'
                               AND extract(hour FROM (a.created_at AT TIME ZONE 'Asia/Kolkata'))::int = h.hour_ist), 0)
           / v_total, 1)
    END                                                       AS pct_of_total
  FROM hours h
  ORDER BY h.hour_ist;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_by_hour_7d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_by_hour_7d() TO authenticated;
COMMIT;
