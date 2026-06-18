BEGIN;
DROP FUNCTION IF EXISTS public.founder_notifications_engagement_30d();
CREATE OR REPLACE FUNCTION public.founder_notifications_engagement_30d()
RETURNS TABLE (
  day_ist           date,
  sent              bigint,
  read              bigint,
  unread_ratio_pct  numeric
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
    coalesce((SELECT count(*)::bigint FROM public.notifications n
              WHERE (n.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)               AS sent,
    coalesce((SELECT count(*)::bigint FROM public.notifications n
              WHERE n.read_at IS NOT NULL
                AND (n.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS read,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.notifications n
                     WHERE (n.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 - (100.0 * coalesce((SELECT count(*)::numeric FROM public.notifications n
                                   WHERE n.read_at IS NOT NULL
                                     AND (n.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)
                 / coalesce((SELECT count(*)::numeric FROM public.notifications n
                             WHERE (n.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 1)),
        1)
    END                                                                                            AS unread_ratio_pct
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_notifications_engagement_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_notifications_engagement_30d() TO authenticated;
COMMIT;
