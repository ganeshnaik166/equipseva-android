BEGIN;

-- Round 1235 — founder_equipment_pm_schedule_summary
-- ---------------------------------------------------------------------
-- Backs /equipment-pm-schedule-summary on the founder console.
-- Source tables (verified against r507 migration):
--   * public.equipment_pm_schedule (hospital_user_id, equipment_type,
--     equipment_brand, interval_days, next_pm_due_at, status,
--     last_service_at, reminder_sent_at, prequote_sent_at, created_at)
--   * public.equipment_pm_intervals (equipment_type, interval_days, active)
-- Returns a single row of headline counters that summarise the PM plan
-- across the entire fleet: upcoming / due / overdue, time-windowed
-- breakdowns, breadth (distinct types + hospitals), and reminder reach.
-- ---------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.founder_equipment_pm_schedule_summary();

CREATE OR REPLACE FUNCTION public.founder_equipment_pm_schedule_summary()
RETURNS TABLE (
  total_scheduled            bigint,
  upcoming_count             bigint,
  due_count                  bigint,
  overdue_count              bigint,
  completed_count            bigint,
  cancelled_count            bigint,
  due_next_7d                bigint,
  due_next_30d               bigint,
  overdue_gt_30d             bigint,
  distinct_equipment_types   bigint,
  distinct_hospitals         bigint,
  reminders_sent_30d         bigint,
  prequotes_sent_30d         bigint,
  active_intervals_seeded    bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH s AS (
    SELECT
      status,
      next_pm_due_at,
      hospital_user_id,
      equipment_type,
      reminder_sent_at,
      prequote_sent_at
    FROM public.equipment_pm_schedule
  ),
  i AS (
    SELECT count(*)::bigint AS n
    FROM public.equipment_pm_intervals
    WHERE active = true
  )
  SELECT
    (SELECT count(*) FROM s)::bigint                                                                AS total_scheduled,
    (SELECT count(*) FROM s WHERE status = 'upcoming')::bigint                                      AS upcoming_count,
    (SELECT count(*) FROM s WHERE status = 'due')::bigint                                           AS due_count,
    (SELECT count(*) FROM s WHERE status = 'overdue')::bigint                                       AS overdue_count,
    (SELECT count(*) FROM s WHERE status = 'completed')::bigint                                     AS completed_count,
    (SELECT count(*) FROM s WHERE status = 'cancelled')::bigint                                     AS cancelled_count,
    (SELECT count(*) FROM s
       WHERE status IN ('scheduled','upcoming','due')
         AND next_pm_due_at >= now()
         AND next_pm_due_at <  now() + interval '7 days')::bigint                                   AS due_next_7d,
    (SELECT count(*) FROM s
       WHERE status IN ('scheduled','upcoming','due')
         AND next_pm_due_at >= now()
         AND next_pm_due_at <  now() + interval '30 days')::bigint                                  AS due_next_30d,
    (SELECT count(*) FROM s
       WHERE status = 'overdue'
         AND next_pm_due_at < now() - interval '30 days')::bigint                                   AS overdue_gt_30d,
    (SELECT count(DISTINCT equipment_type) FROM s)::bigint                                          AS distinct_equipment_types,
    (SELECT count(DISTINCT hospital_user_id) FROM s)::bigint                                        AS distinct_hospitals,
    (SELECT count(*) FROM s
       WHERE reminder_sent_at >= now() - interval '30 days')::bigint                                AS reminders_sent_30d,
    (SELECT count(*) FROM s
       WHERE prequote_sent_at >= now() - interval '30 days')::bigint                                AS prequotes_sent_30d,
    (SELECT n FROM i)                                                                               AS active_intervals_seeded
$$;

REVOKE ALL ON FUNCTION public.founder_equipment_pm_schedule_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_equipment_pm_schedule_summary() TO authenticated;

DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'founder_equipment_pm_schedule_summary'
  ) THEN
    RAISE EXCEPTION 'round 1235: founder_equipment_pm_schedule_summary not created';
  END IF;
END
$verify$;

COMMIT;
