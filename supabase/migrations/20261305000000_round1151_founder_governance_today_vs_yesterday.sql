BEGIN;
DROP FUNCTION IF EXISTS public.founder_governance_today_vs_yesterday();
CREATE OR REPLACE FUNCTION public.founder_governance_today_vs_yesterday()
RETURNS TABLE (
  metric         text,
  metric_order   int,
  today_val      bigint,
  yesterday_val  bigint,
  delta          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_yest_start  timestamptz := v_today_start - interval '1 day';
  v_yest_end    timestamptz := v_today_start;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH metrics AS (
    SELECT 'Total ops'::text AS metric, 1 AS metric_order,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint  AS today_val,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint  AS yesterday_val
    UNION ALL
    SELECT 'Success', 2,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'success' AND a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'success' AND a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint
    UNION ALL
    SELECT 'Failed', 3,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'failed' AND a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint,
      coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'failed' AND a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint
    UNION ALL
    SELECT 'Distinct actors', 4,
      coalesce((SELECT count(DISTINCT a.actor_user_id)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint,
      coalesce((SELECT count(DISTINCT a.actor_user_id)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint
    UNION ALL
    SELECT 'Distinct ops', 5,
      coalesce((SELECT count(DISTINCT a.op_name)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint,
      coalesce((SELECT count(DISTINCT a.op_name)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint
    UNION ALL
    SELECT 'Distinct tables', 6,
      coalesce((SELECT count(DISTINCT a.target_table)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)::bigint,
      coalesce((SELECT count(DISTINCT a.target_table)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_yest_start AND a.created_at < v_yest_end), 0)::bigint
  )
  SELECT m.metric, m.metric_order, m.today_val, m.yesterday_val, (m.today_val - m.yesterday_val)::bigint
  FROM metrics m
  ORDER BY m.metric_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_governance_today_vs_yesterday() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_governance_today_vs_yesterday() TO authenticated;
COMMIT;
