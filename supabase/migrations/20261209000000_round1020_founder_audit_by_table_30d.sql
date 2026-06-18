BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_by_table_30d();
CREATE OR REPLACE FUNCTION public.founder_audit_by_table_30d()
RETURNS TABLE (
  target_table     text,
  total            bigint,
  distinct_ops     bigint,
  distinct_actors  bigint,
  distinct_rows    bigint,
  last_touched_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(a.target_table, '(none)')::text                        AS target_table,
    count(*)::bigint                                                 AS total,
    count(DISTINCT a.op_name)::bigint                                AS distinct_ops,
    count(DISTINCT a.actor_user_id)::bigint                          AS distinct_actors,
    count(DISTINCT a.target_row_id)::bigint                          AS distinct_rows,
    max(a.created_at)                                                AS last_touched_at
  FROM public.founder_action_log a
  WHERE a.created_at >= now() - interval '30 days'
  GROUP BY coalesce(a.target_table, '(none)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_by_table_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_by_table_30d() TO authenticated;
COMMIT;
