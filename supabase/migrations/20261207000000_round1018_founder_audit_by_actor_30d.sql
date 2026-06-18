BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_by_actor_30d();
CREATE OR REPLACE FUNCTION public.founder_audit_by_actor_30d()
RETURNS TABLE (
  actor_email     text,
  total_actions   bigint,
  distinct_ops    bigint,
  distinct_tables bigint,
  success_cnt     bigint,
  failed_cnt      bigint,
  last_action_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(a.actor_email, '(unknown)')::text                       AS actor_email,
    count(*)::bigint                                                  AS total_actions,
    count(DISTINCT a.op_name)::bigint                                 AS distinct_ops,
    count(DISTINCT a.target_table)::bigint                            AS distinct_tables,
    count(*) FILTER (WHERE a.outcome = 'success')::bigint             AS success_cnt,
    count(*) FILTER (WHERE a.outcome = 'failed')::bigint              AS failed_cnt,
    max(a.created_at)                                                  AS last_action_at
  FROM public.founder_action_log a
  WHERE a.created_at >= now() - interval '30 days'
  GROUP BY coalesce(a.actor_email, '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_by_actor_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_by_actor_30d() TO authenticated;
COMMIT;
