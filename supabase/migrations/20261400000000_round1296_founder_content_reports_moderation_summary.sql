BEGIN;

-- =====================================================================
-- Round 1282 — founder_content_reports_moderation_summary
-- =====================================================================
-- Community-safety domain: content_reports (user-flagged spam/abuse/scam/
-- illegal/harassment/inappropriate against chat_message | part_listing |
-- repair_job | rfq | profile) + user_blocks (blocker -> blocked edges).
-- chat-moderation summary (r1213) only covered chat_message_moderation_events
-- (PII regex). This RPC layers the human-reported safety queue + block-list
-- velocity, repeat-offender accounts, action-latency.
--
-- 14 KPIs (today / 7d / 30d windows, IST day boundary):
--   1.  reports_today                  — content_reports created today
--   2.  reports_7d                     — reports 7d
--   3.  reports_30d                    — reports 30d
--   4.  pending_reports                — status='pending' (queue depth)
--   5.  pending_over_24h               — pending older than 24h (SLA breach)
--   6.  actioned_30d                   — status='actioned' reviewed in 30d
--   7.  dismissed_30d                  — status='dismissed' reviewed in 30d
--   8.  avg_resolution_hours_30d       — avg (reviewed_at - created_at) hrs
--   9.  abuse_reports_30d              — reason='abuse' OR 'harassment' 30d
--   10. scam_reports_30d               — reason='scam' OR 'illegal' 30d
--   11. distinct_targets_30d           — distinct (target_type,target_id) 30d
--   12. repeat_reporters_30d           — reporters with >=3 reports 30d
--   13. blocks_created_30d             — user_blocks rows in 30d
--   14. top_blocked_count_30d          — max blocks against a single user 30d
--
-- Every column ref verified against:
--   migrations/20260424100000_content_reports.sql
--   migrations/20260424110000_user_blocks.sql
--   migrations/20260425170000_admin_content_reports_rpcs.sql
--
-- IMPORTANT: never project notes / target_id bodies. Counts only.

DROP FUNCTION IF EXISTS public.founder_content_reports_moderation_summary();

CREATE OR REPLACE FUNCTION public.founder_content_reports_moderation_summary()
RETURNS TABLE (
  reports_today              bigint,
  reports_7d                 bigint,
  reports_30d                bigint,
  pending_reports            bigint,
  pending_over_24h           bigint,
  actioned_30d               bigint,
  dismissed_30d              bigint,
  avg_resolution_hours_30d   numeric,
  abuse_reports_30d          bigint,
  scam_reports_30d           bigint,
  distinct_targets_30d       bigint,
  repeat_reporters_30d       bigint,
  blocks_created_30d         bigint,
  top_blocked_count_30d      bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_7d_start    timestamptz := v_today_end - interval '7 days';
  v_30d_start   timestamptz := v_today_end - interval '30 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- 1. reports_today
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE created_at >= v_today_start
        AND created_at <  v_today_end),
    -- 2. reports_7d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE created_at >= v_7d_start
        AND created_at <  v_today_end),
    -- 3. reports_30d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end),
    -- 4. pending_reports (queue depth, all-time)
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE status = 'pending'),
    -- 5. pending_over_24h (SLA breach)
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE status = 'pending'
        AND created_at < (now() - interval '24 hours')),
    -- 6. actioned_30d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE status = 'actioned'
        AND reviewed_at >= v_30d_start
        AND reviewed_at <  v_today_end),
    -- 7. dismissed_30d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE status = 'dismissed'
        AND reviewed_at >= v_30d_start
        AND reviewed_at <  v_today_end),
    -- 8. avg_resolution_hours_30d
    (SELECT COALESCE(
              round(
                avg(EXTRACT(EPOCH FROM (reviewed_at - created_at)) / 3600.0)::numeric,
                2
              ),
              0
            )
       FROM public.content_reports
      WHERE reviewed_at IS NOT NULL
        AND reviewed_at >= v_30d_start
        AND reviewed_at <  v_today_end),
    -- 9. abuse_reports_30d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end
        AND reason IN ('abuse', 'harassment')),
    -- 10. scam_reports_30d
    (SELECT count(*)::bigint
       FROM public.content_reports
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end
        AND reason IN ('scam', 'illegal')),
    -- 11. distinct_targets_30d
    (SELECT count(*)::bigint FROM (
       SELECT DISTINCT target_type, target_id
         FROM public.content_reports
        WHERE created_at >= v_30d_start
          AND created_at <  v_today_end
     ) dt),
    -- 12. repeat_reporters_30d (reporter with >=3 reports in 30d)
    (SELECT count(*)::bigint FROM (
       SELECT reporter_user_id
         FROM public.content_reports
        WHERE created_at >= v_30d_start
          AND created_at <  v_today_end
        GROUP BY reporter_user_id
       HAVING count(*) >= 3
     ) rr),
    -- 13. blocks_created_30d
    (SELECT count(*)::bigint
       FROM public.user_blocks
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end),
    -- 14. top_blocked_count_30d (max blocks against a single user in 30d)
    (SELECT COALESCE(max(c), 0)::bigint FROM (
       SELECT count(*) AS c
         FROM public.user_blocks
        WHERE created_at >= v_30d_start
          AND created_at <  v_today_end
        GROUP BY blocked_user_id
     ) tb);
END;
$$;

ALTER FUNCTION public.founder_content_reports_moderation_summary() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.founder_content_reports_moderation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_content_reports_moderation_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_content_reports_moderation_summary() IS
  'Round 1282 — founder content-reports + user-blocks 14-KPI snapshot. Tracks community-safety velocity, queue depth, SLA breach, repeat reporters/offenders, block-list spread. Never projects report notes or target ids. Founder-only via is_founder().';

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertion
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'founder_content_reports_moderation_summary'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'round 1282: founder_content_reports_moderation_summary not installed';
  END IF;
  RAISE NOTICE 'round 1282 content reports moderation summary fn installed';
END;
$$;
