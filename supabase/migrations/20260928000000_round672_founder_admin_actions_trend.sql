BEGIN;
DROP FUNCTION IF EXISTS public.founder_admin_actions_trend();
CREATE OR REPLACE FUNCTION public.founder_admin_actions_trend()
RETURNS TABLE (
  day_ist   date,
  actions   bigint,
  distinct_actors bigint,
  distinct_ops    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 13,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.founder_action_log l
       WHERE (l.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(DISTINCT l.actor_user_id)::bigint FROM public.founder_action_log l
       WHERE (l.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint,
    coalesce(
      (SELECT count(DISTINCT l.op_name)::bigint FROM public.founder_action_log l
       WHERE (l.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist
      ), 0)::bigint
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_admin_actions_trend() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_admin_actions_trend() TO authenticated;
COMMIT;
