BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_by_actor();
CREATE OR REPLACE FUNCTION public.founder_audit_by_actor()
RETURNS TABLE (
  actor_user_id  uuid,
  actor_email    text,
  display_name   text,
  ops_30d        bigint,
  distinct_ops   bigint,
  last_op_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    l.actor_user_id,
    coalesce((SELECT email FROM auth.users u WHERE u.id = l.actor_user_id), 'unknown'),
    coalesce((SELECT full_name FROM public.profiles p WHERE p.id = l.actor_user_id), '(no profile)'),
    count(*)::bigint,
    count(DISTINCT l.op_name)::bigint,
    max(l.created_at)
  FROM public.founder_action_log l
  WHERE l.created_at >= now() - interval '30 days'
  GROUP BY l.actor_user_id
  ORDER BY ops_30d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_by_actor() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_by_actor() TO authenticated;
COMMIT;
