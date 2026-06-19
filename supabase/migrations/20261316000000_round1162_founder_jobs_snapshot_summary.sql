BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_jobs_snapshot_summary()
RETURNS TABLE (
  total_all_time          bigint,
  open_now                bigint,
  in_progress_now         bigint,
  completed_30d           bigint,
  cancelled_30d           bigint,
  unassigned_over_24h     bigint,
  bids_pending_now        bigint,
  hospitals_active_30d    bigint,
  engineers_active_30d    bigint,
  posted_today            bigint,
  completed_today         bigint,
  avg_completion_hours    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status IN ('open','posted')), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status IN ('in_progress','assigned')), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'cancelled' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status IN ('open','posted') AND engineer_id IS NULL AND created_at < now() - interval '24 hours'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids WHERE status IN ('submitted','pending')), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= v_today_start AND completed_at < v_today_end), 0),
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
              FROM public.repair_jobs
              WHERE status = 'completed' AND completed_at >= now() - interval '30 days' AND completed_at IS NOT NULL), 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_snapshot_summary() TO authenticated;
COMMIT;
