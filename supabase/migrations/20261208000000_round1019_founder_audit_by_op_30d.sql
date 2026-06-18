BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_by_op_30d();
CREATE OR REPLACE FUNCTION public.founder_audit_by_op_30d()
RETURNS TABLE (
  op_name        text,
  total          bigint,
  success_cnt    bigint,
  failed_cnt     bigint,
  distinct_actors bigint,
  last_called_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(a.op_name, '(unknown)')::text                          AS op_name,
    count(*)::bigint                                                 AS total,
    count(*) FILTER (WHERE a.outcome = 'success')::bigint            AS success_cnt,
    count(*) FILTER (WHERE a.outcome = 'failed')::bigint             AS failed_cnt,
    count(DISTINCT a.actor_user_id)::bigint                          AS distinct_actors,
    max(a.created_at)                                                AS last_called_at
  FROM public.founder_action_log a
  WHERE a.created_at >= now() - interval '30 days'
  GROUP BY coalesce(a.op_name, '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_by_op_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_by_op_30d() TO authenticated;
COMMIT;
