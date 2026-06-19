BEGIN;
DROP FUNCTION IF EXISTS public.founder_virtual_call_sessions_summary();
CREATE OR REPLACE FUNCTION public.founder_virtual_call_sessions_summary()
RETURNS TABLE (
  total_all_time          bigint,
  created_today           bigint,
  created_7d              bigint,
  created_30d             bigint,
  answered_30d            bigint,
  failed_30d              bigint,
  released_30d            bigint,
  answer_rate_pct_30d     numeric,
  fail_rate_pct_30d       numeric,
  avg_call_count_30d      numeric,
  high_call_count_30d     bigint,
  active_engineers_30d    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_total_30d   bigint;
  v_answered_30d bigint;
  v_failed_30d  bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total_30d
    FROM public.virtual_call_sessions
   WHERE created_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_answered_30d
    FROM public.virtual_call_sessions
   WHERE created_at >= now() - interval '30 days'
     AND status IN ('answered','completed','released');

  SELECT count(*)::bigint INTO v_failed_30d
    FROM public.virtual_call_sessions
   WHERE created_at >= now() - interval '30 days'
     AND status = 'failed';

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.virtual_call_sessions), 0),
    coalesce((SELECT count(*)::bigint FROM public.virtual_call_sessions
               WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.virtual_call_sessions
               WHERE created_at >= now() - interval '7 days'), 0),
    coalesce(v_total_30d, 0),
    coalesce(v_answered_30d, 0),
    coalesce(v_failed_30d, 0),
    coalesce((SELECT count(*)::bigint FROM public.virtual_call_sessions
               WHERE created_at >= now() - interval '30 days'
                 AND status = 'released'), 0),
    CASE WHEN coalesce(v_total_30d, 0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_answered_30d / v_total_30d, 1) END,
    CASE WHEN coalesce(v_total_30d, 0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_failed_30d / v_total_30d, 1) END,
    coalesce((SELECT round(avg(call_count)::numeric, 2) FROM public.virtual_call_sessions
               WHERE created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.virtual_call_sessions
               WHERE created_at >= now() - interval '30 days'
                 AND call_count >= 10), 0),
    coalesce((SELECT count(DISTINCT engineer_user_id)::bigint FROM public.virtual_call_sessions
               WHERE created_at >= now() - interval '30 days'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_virtual_call_sessions_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_virtual_call_sessions_summary() TO authenticated;
COMMIT;
