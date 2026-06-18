BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_code_red_by_day_30d()
RETURNS TABLE (
  day_ist          date,
  total            bigint,
  resolved         bigint,
  timed_out        bigint,
  open_now         bigint,
  resolved_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)             AS total,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.status = 'resolved'
                AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS resolved,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.status = 'timed_out'
                AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS timed_out,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
              WHERE r.status NOT IN ('resolved','timed_out')
                AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS open_now,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.code_red_requests r
                     WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.code_red_requests r
                          WHERE r.status = 'resolved'
                            AND (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)
        / coalesce((SELECT count(*)::numeric FROM public.code_red_requests r
                    WHERE (r.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 1),
        1)
    END                                                                                            AS resolved_pct
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_by_day_30d() TO authenticated;
COMMIT;
