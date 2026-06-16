-- =====================================================================
-- Round 602 — Founder daily activity summary RPC
-- =====================================================================
--
-- A single-call read RPC that returns today's key counts for the
-- founder digest / dashboard "today at a glance" card. Cheap to call
-- (one query per metric, all bounded by the day window). Designed
-- so a future edge function can call it once at 08:00 IST and email
-- the founder a one-paragraph summary.
--
-- "Today" = current IST date. We compute the IST day-window in UTC
-- so the SECDEF runs identically regardless of session timezone.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_daily_activity_summary();

CREATE OR REPLACE FUNCTION public.founder_daily_activity_summary()
RETURNS TABLE (
  metric         text,
  count_today    bigint,
  count_yesterday bigint,
  delta          bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start    timestamptz;
  v_today_end      timestamptz;
  v_yest_start     timestamptz;
  v_yest_end       timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- IST day boundaries expressed as timestamptz so column predicates
  -- can match repair_jobs.created_at, dsr_reports.created_at, etc.
  v_today_start := (current_date::timestamp AT TIME ZONE 'Asia/Kolkata');
  v_today_end   := v_today_start + interval '1 day';
  v_yest_start  := v_today_start - interval '1 day';
  v_yest_end    := v_today_start;

  RETURN QUERY
  WITH metrics AS (
    SELECT 'new_repair_jobs'::text AS metric, 1 AS ord, (
      SELECT count(*)::bigint FROM public.repair_jobs
       WHERE created_at >= v_today_start AND created_at < v_today_end
    ) AS today, (
      SELECT count(*)::bigint FROM public.repair_jobs
       WHERE created_at >= v_yest_start AND created_at < v_yest_end
    ) AS yesterday
    UNION ALL
    SELECT 'accepted_bids', 2, (
      SELECT count(*)::bigint FROM public.repair_job_bids
       WHERE status = 'accepted'
         AND updated_at >= v_today_start AND updated_at < v_today_end
    ), (
      SELECT count(*)::bigint FROM public.repair_job_bids
       WHERE status = 'accepted'
         AND updated_at >= v_yest_start AND updated_at < v_yest_end
    )
    UNION ALL
    SELECT 'completed_jobs', 3, (
      SELECT count(*)::bigint FROM public.repair_jobs
       WHERE status = 'completed'
         AND completed_at >= v_today_start AND completed_at < v_today_end
    ), (
      SELECT count(*)::bigint FROM public.repair_jobs
       WHERE status = 'completed'
         AND completed_at >= v_yest_start AND completed_at < v_yest_end
    )
    UNION ALL
    SELECT 'signed_dsr_reports', 4, (
      SELECT count(*)::bigint FROM public.dsr_reports
       WHERE status = 'signed'
         AND updated_at >= v_today_start AND updated_at < v_today_end
    ), (
      SELECT count(*)::bigint FROM public.dsr_reports
       WHERE status = 'signed'
         AND updated_at >= v_yest_start AND updated_at < v_yest_end
    )
    UNION ALL
    SELECT 'new_amc_contracts', 5, (
      SELECT count(*)::bigint FROM public.amc_contracts
       WHERE created_at >= v_today_start AND created_at < v_today_end
    ), (
      SELECT count(*)::bigint FROM public.amc_contracts
       WHERE created_at >= v_yest_start AND created_at < v_yest_end
    )
    UNION ALL
    SELECT 'new_demand_signals', 6, (
      SELECT count(*)::bigint FROM public.spare_part_demand_signals
       WHERE occurred_at >= v_today_start AND occurred_at < v_today_end
    ), (
      SELECT count(*)::bigint FROM public.spare_part_demand_signals
       WHERE occurred_at >= v_yest_start AND occurred_at < v_yest_end
    )
    UNION ALL
    SELECT 'tier_promotions', 7, (
      SELECT count(*)::bigint FROM public.engineer_tier_history h
       WHERE h.changed_at >= v_today_start AND h.changed_at < v_today_end
         AND CASE h.new_tier
               WHEN 'none' THEN 0 WHEN 'bronze' THEN 1
               WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0
             END >
             CASE h.prev_tier
               WHEN 'none' THEN 0 WHEN 'bronze' THEN 1
               WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0
             END
    ), (
      SELECT count(*)::bigint FROM public.engineer_tier_history h
       WHERE h.changed_at >= v_yest_start AND h.changed_at < v_yest_end
         AND CASE h.new_tier
               WHEN 'none' THEN 0 WHEN 'bronze' THEN 1
               WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0
             END >
             CASE h.prev_tier
               WHEN 'none' THEN 0 WHEN 'bronze' THEN 1
               WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 0
             END
    )
  )
  SELECT m.metric, m.today AS count_today, m.yesterday AS count_yesterday,
         m.today - m.yesterday AS delta
  FROM metrics m
  ORDER BY m.ord;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_daily_activity_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_daily_activity_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_daily_activity_summary() IS
  'r602: founder daily-activity summary — 7 metrics × today vs yesterday × delta. IST day window. Future edge fn can email this at 08:00 IST.';

COMMIT;
