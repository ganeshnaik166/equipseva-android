BEGIN;
-- r1183 — founder_notifications_snapshot_summary
-- 12-KPI snapshot for push/notification channel: today (IST) volume,
-- 30d throughput + read rate, all-time totals, stuck-unread alerts,
-- distinct users + kinds, and channel mix. Pairs with engagement_30d
-- (r1016) + by_kind_30d (r1017) + throughput_30d (r1148).
--
-- Schema notes (verified from 20260425001745_notifications_baseline.sql):
--   columns: id, user_id, title, body, kind, notification_type, channel,
--            related_entity_type, related_entity_id, action_url, data jsonb,
--            sent_at, read_at, is_read, created_at
--   sent_at is the canonical send-time (server-stamped).

DROP FUNCTION IF EXISTS public.founder_notifications_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_notifications_snapshot_summary()
RETURNS TABLE (
  total_all_time            bigint,
  sent_today                bigint,
  read_today                bigint,
  sent_30d                  bigint,
  read_30d                  bigint,
  read_pct_30d              numeric,
  unread_over_7d            bigint,
  distinct_users_30d        bigint,
  distinct_kinds_30d        bigint,
  push_channel_30d          bigint,
  top_kind_30d              text,
  avg_read_latency_minutes  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- 1. total all-time
    coalesce((SELECT count(*)::bigint FROM public.notifications), 0)                                                  AS total_all_time,

    -- 2. sent today (IST day boundary)
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE sent_at >= v_today_start AND sent_at < v_today_end), 0)                                           AS sent_today,

    -- 3. read today — any notification whose read_at landed in today (IST)
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE read_at >= v_today_start AND read_at < v_today_end), 0)                                           AS read_today,

    -- 4. sent 30d
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE sent_at >= now() - interval '30 days'), 0)                                                        AS sent_30d,

    -- 5. read 30d (subset of sent_30d with read_at not null)
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE sent_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)                                AS read_30d,

    -- 6. read_pct_30d
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.notifications
                     WHERE sent_at >= now() - interval '30 days'), 0) = 0
      THEN 0::numeric
      ELSE round(
        100.0 * coalesce((SELECT count(*)::numeric FROM public.notifications
                          WHERE sent_at >= now() - interval '30 days' AND read_at IS NOT NULL), 0)
        / coalesce((SELECT count(*)::numeric FROM public.notifications
                    WHERE sent_at >= now() - interval '30 days'), 1),
        1)
    END                                                                                                                AS read_pct_30d,

    -- 7. stuck unread > 7 days (sent at least 7d ago, still no read_at) — engagement health alert
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE sent_at < now() - interval '7 days'
                AND sent_at >= now() - interval '60 days'
                AND read_at IS NULL), 0)                                                                              AS unread_over_7d,

    -- 8. distinct users reached 30d
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.notifications
              WHERE sent_at >= now() - interval '30 days'), 0)                                                        AS distinct_users_30d,

    -- 9. distinct kinds 30d
    coalesce((SELECT count(DISTINCT kind)::bigint FROM public.notifications
              WHERE sent_at >= now() - interval '30 days' AND kind IS NOT NULL), 0)                                   AS distinct_kinds_30d,

    -- 10. push-channel 30d (channel column — push vs in-app vs email mix)
    coalesce((SELECT count(*)::bigint FROM public.notifications
              WHERE sent_at >= now() - interval '30 days' AND channel = 'push'), 0)                                   AS push_channel_30d,

    -- 11. top kind 30d
    coalesce((SELECT coalesce(kind, '(unknown)')::text FROM public.notifications
              WHERE sent_at >= now() - interval '30 days'
              GROUP BY coalesce(kind, '(unknown)')
              ORDER BY count(*) DESC
              LIMIT 1), '(none)')                                                                                     AS top_kind_30d,

    -- 12. avg read latency (minutes between sent_at and read_at) 30d
    coalesce((SELECT round(avg(EXTRACT(EPOCH FROM (read_at - sent_at)) / 60.0)::numeric, 1)
              FROM public.notifications
              WHERE sent_at >= now() - interval '30 days'
                AND read_at IS NOT NULL
                AND read_at >= sent_at), 0)                                                                           AS avg_read_latency_minutes;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_notifications_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_notifications_snapshot_summary() TO authenticated;

COMMIT;
