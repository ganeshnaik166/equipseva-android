BEGIN;
DROP FUNCTION IF EXISTS public.founder_admin_top_ops();
CREATE OR REPLACE FUNCTION public.founder_admin_top_ops()
RETURNS TABLE (
  op_name        text,
  count_30d      bigint,
  count_total    bigint,
  last_used_at   timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    l.op_name,
    count(*) FILTER (WHERE l.created_at >= now() - interval '30 days')::bigint,
    count(*)::bigint,
    max(l.created_at)
  FROM public.founder_action_log l
  GROUP BY l.op_name
  ORDER BY count_30d DESC, count_total DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_admin_top_ops() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_admin_top_ops() TO authenticated;
COMMIT;
