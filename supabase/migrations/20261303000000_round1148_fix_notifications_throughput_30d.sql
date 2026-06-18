BEGIN;
-- Fix r1148: original used created_at + push_dispatched_at + push_sent_at which
-- don't exist on public.notifications (table uses sent_at). plpgsql doesn't
-- validate column refs at CREATE time so the broken fn shipped silently.
-- Replace with sent_at + drop the push column.

DROP FUNCTION IF EXISTS public.founder_notifications_throughput_30d();
CREATE OR REPLACE FUNCTION public.founder_notifications_throughput_30d()
RETURNS TABLE (
  total_sent       bigint,
  total_read       bigint,
  read_pct         numeric,
  distinct_users   bigint,
  distinct_kinds   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.notifications WHERE sent_at >= now() - interval '30 days'), 0)                                    AS total_sent,
    coalesce((SELECT count(*)::bigint FROM public.notifications WHERE sent_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)            AS total_read,
    CASE WHEN coalesce((SELECT count(*)::bigint FROM public.notifications WHERE sent_at >= now() - interval '30 days'), 0) = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.notifications WHERE sent_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)
                    / coalesce((SELECT count(*)::numeric FROM public.notifications WHERE sent_at >= now() - interval '30 days'), 1), 1)
    END                                                                                                                                              AS read_pct,
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.notifications WHERE sent_at >= now() - interval '30 days'), 0)                      AS distinct_users,
    coalesce((SELECT count(DISTINCT kind)::bigint FROM public.notifications WHERE sent_at >= now() - interval '30 days'), 0)                         AS distinct_kinds;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_notifications_throughput_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_notifications_throughput_30d() TO authenticated;
COMMIT;
