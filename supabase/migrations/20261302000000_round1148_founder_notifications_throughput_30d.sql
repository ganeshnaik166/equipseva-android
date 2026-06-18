BEGIN;
DROP FUNCTION IF EXISTS public.founder_notifications_throughput_30d();
CREATE OR REPLACE FUNCTION public.founder_notifications_throughput_30d()
RETURNS TABLE (
  total_sent       bigint,
  total_read       bigint,
  read_pct         numeric,
  distinct_users   bigint,
  distinct_kinds   bigint,
  push_sent        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.notifications WHERE created_at >= now() - interval '30 days'), 0)                                AS total_sent,
    coalesce((SELECT count(*)::bigint FROM public.notifications WHERE created_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)        AS total_read,
    CASE WHEN coalesce((SELECT count(*)::bigint FROM public.notifications WHERE created_at >= now() - interval '30 days'), 0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.notifications WHERE created_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)
                    / coalesce((SELECT count(*)::numeric FROM public.notifications WHERE created_at >= now() - interval '30 days'), 1), 1)
    END                                                                                                                                              AS read_pct,
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.notifications WHERE created_at >= now() - interval '30 days'), 0)                  AS distinct_users,
    coalesce((SELECT count(DISTINCT kind)::bigint FROM public.notifications WHERE created_at >= now() - interval '30 days'), 0)                     AS distinct_kinds,
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE created_at >= now() - interval '30 days' AND coalesce(push_dispatched_at, push_sent_at) IS NOT NULL), 0)                          AS push_sent;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_notifications_throughput_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_notifications_throughput_30d() TO authenticated;
COMMIT;
