BEGIN;
DROP FUNCTION IF EXISTS public.founder_admin_actions_recent();
CREATE OR REPLACE FUNCTION public.founder_admin_actions_recent()
RETURNS TABLE (
  created_at     timestamptz,
  actor_email    text,
  op_name        text,
  target_table   text,
  target_row_id  uuid,
  outcome        text,
  reason         text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    a.created_at,
    coalesce(a.actor_email, '(unknown)')::text                AS actor_email,
    coalesce(a.op_name, '(unknown)')::text                    AS op_name,
    coalesce(a.target_table, '(none)')::text                  AS target_table,
    a.target_row_id,
    coalesce(a.outcome, '(unknown)')::text                    AS outcome,
    coalesce(a.reason, '')::text                              AS reason
  FROM public.founder_action_log a
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_admin_actions_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_admin_actions_recent() TO authenticated;
COMMIT;
