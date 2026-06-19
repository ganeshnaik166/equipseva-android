BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_code_red_snapshot_summary()
RETURNS TABLE (
  total_all_time            bigint,
  open_now                  bigint,
  stuck_over_4h             bigint,
  resolved_30d              bigint,
  timed_out_30d             bigint,
  sla_breach_30d            bigint,
  sla_breach_pct_30d        numeric,
  created_today             bigint,
  resolved_today            bigint,
  active_hospitals_30d      bigint,
  responders_30d            bigint,
  avg_resolve_minutes_30d   numeric,
  avg_ceiling_inr_30d       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_resolved_30d_count bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_resolved_30d_count
    FROM public.code_red_requests
    WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days';
  IF v_resolved_30d_count IS NULL THEN v_resolved_30d_count := 0; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status NOT IN ('resolved','timed_out')), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status NOT IN ('resolved','timed_out') AND created_at < now() - interval '4 hours'), 0),
    v_resolved_30d_count,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status = 'timed_out' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days' AND resolved_at > sla_deadline_at), 0),
    CASE WHEN v_resolved_30d_count = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT count(*)::numeric FROM public.code_red_requests
                                      WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days' AND resolved_at > sla_deadline_at), 0)
                    / v_resolved_30d_count, 1) END,
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.code_red_requests WHERE status = 'resolved' AND resolved_at >= v_today_start AND resolved_at < v_today_end), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.code_red_requests WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT accepted_engineer_user_id)::bigint FROM public.code_red_requests
              WHERE accepted_engineer_user_id IS NOT NULL AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(extract(epoch FROM (resolved_at - created_at)) / 60.0)::numeric, 1)
              FROM public.code_red_requests
              WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT round(avg(emergency_fee_ceiling_rupees)::numeric, 2)
              FROM public.code_red_requests
              WHERE created_at >= now() - interval '30 days'), 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_snapshot_summary() TO authenticated;
COMMIT;
