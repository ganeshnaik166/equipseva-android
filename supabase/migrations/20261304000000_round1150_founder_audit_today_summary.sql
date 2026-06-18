BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_today_summary();
CREATE OR REPLACE FUNCTION public.founder_audit_today_summary()
RETURNS TABLE (
  total_today          bigint,
  success_today        bigint,
  failed_today         bigint,
  distinct_actors      bigint,
  distinct_ops         bigint,
  distinct_tables      bigint,
  first_action_at      timestamptz,
  last_action_at       timestamptz
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
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)                              AS total_today,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'success' AND a.created_at >= v_today_start AND a.created_at < v_today_end), 0)    AS success_today,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a WHERE a.outcome = 'failed' AND a.created_at >= v_today_start AND a.created_at < v_today_end), 0)     AS failed_today,
    coalesce((SELECT count(DISTINCT a.actor_user_id)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)        AS distinct_actors,
    coalesce((SELECT count(DISTINCT a.op_name)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)             AS distinct_ops,
    coalesce((SELECT count(DISTINCT a.target_table)::bigint FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end), 0)        AS distinct_tables,
    (SELECT min(a.created_at) FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end)                                          AS first_action_at,
    (SELECT max(a.created_at) FROM public.founder_action_log a WHERE a.created_at >= v_today_start AND a.created_at < v_today_end)                                          AS last_action_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_today_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_today_summary() TO authenticated;
COMMIT;
