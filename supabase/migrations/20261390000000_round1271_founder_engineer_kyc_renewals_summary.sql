BEGIN;
-- =====================================================================
-- Round 1271 — Founder engineer KYC renewals summary
-- =====================================================================
-- Aggregates engineer_kyc_renewals (round 497) into a 14-KPI cockpit:
-- queue depth by status, due-window buckets, grace-overdue, item-refresh
-- progress, IST-day intake/closure throughput, oldest-pending age,
-- expired-this-week count, waived count, avg-completion-days 30d.
-- Distinct from kyc-pipeline (initial onboarding) and buyer-kyc-pipeline
-- (hospital-buyer). This domain = engineer ANNUAL re-verification queue.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_engineer_kyc_renewals_summary();

CREATE OR REPLACE FUNCTION public.founder_engineer_kyc_renewals_summary()
RETURNS TABLE(
  renewals_total           bigint,
  status_pending           bigint,
  status_in_progress       bigint,
  status_completed         bigint,
  status_expired           bigint,
  status_waived            bigint,
  due_next_7d              bigint,
  due_next_30d             bigint,
  overdue_in_grace         bigint,
  oldest_pending_days      numeric,
  avg_completion_days_30d  numeric,
  scheduled_today          bigint,
  completed_today          bigint,
  expired_last_7d          bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT r.* FROM public.engineer_kyc_renewals r
  )
  SELECT
    (SELECT count(*) FROM base)::bigint                                                                    AS renewals_total,
    (SELECT count(*) FROM base WHERE status = 'pending')::bigint                                           AS status_pending,
    (SELECT count(*) FROM base WHERE status = 'in_progress')::bigint                                       AS status_in_progress,
    (SELECT count(*) FROM base WHERE status = 'completed')::bigint                                         AS status_completed,
    (SELECT count(*) FROM base WHERE status = 'expired')::bigint                                           AS status_expired,
    (SELECT count(*) FROM base WHERE status = 'waived')::bigint                                            AS status_waived,
    (SELECT count(*) FROM base
       WHERE status IN ('pending','in_progress')
         AND due_at >= now() AND due_at < now() + interval '7 days')::bigint                               AS due_next_7d,
    (SELECT count(*) FROM base
       WHERE status IN ('pending','in_progress')
         AND due_at >= now() AND due_at < now() + interval '30 days')::bigint                              AS due_next_30d,
    (SELECT count(*) FROM base
       WHERE status IN ('pending','in_progress')
         AND due_at < now()
         AND grace_until >= now())::bigint                                                                 AS overdue_in_grace,
    coalesce(
      (SELECT EXTRACT(EPOCH FROM (now() - min(cycle_started_at))) / 86400
         FROM base WHERE status IN ('pending','in_progress')),
      0)::numeric                                                                                          AS oldest_pending_days,
    coalesce(
      (SELECT avg(EXTRACT(EPOCH FROM (completed_at - cycle_started_at)) / 86400)
         FROM base
        WHERE status = 'completed'
          AND completed_at >= now() - interval '30 days'),
      0)::numeric                                                                                          AS avg_completion_days_30d,
    (SELECT count(*) FROM base
       WHERE cycle_started_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')::bigint
                                                                                                           AS scheduled_today,
    (SELECT count(*) FROM base
       WHERE status = 'completed'
         AND completed_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')::bigint
                                                                                                           AS completed_today,
    (SELECT count(*) FROM base
       WHERE status = 'expired'
         AND expired_at >= now() - interval '7 days')::bigint                                              AS expired_last_7d;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_kyc_renewals_summary()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_kyc_renewals_summary()
  TO authenticated;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 1271 founder_engineer_kyc_renewals_summary: 14-KPI cockpit ready';
END;
$$;
