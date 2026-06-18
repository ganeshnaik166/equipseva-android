BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_ops_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_audit_ops_by_day_30d()
RETURNS TABLE (
  day_ist          date,
  total_ops        bigint,
  success_cnt      bigint,
  failed_cnt       bigint,
  distinct_actors  bigint,
  distinct_ops     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE a.outcome = 'success'
                AND (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_action_log a
              WHERE a.outcome = 'failed'
                AND (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT count(DISTINCT a.actor_user_id)::bigint FROM public.founder_action_log a
              WHERE (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0),
    coalesce((SELECT count(DISTINCT a.op_name)::bigint FROM public.founder_action_log a
              WHERE (a.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_ops_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_ops_by_day_30d() TO authenticated;
COMMIT;
