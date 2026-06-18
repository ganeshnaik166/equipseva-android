BEGIN;
DROP FUNCTION IF EXISTS public.founder_audit_failed_events_30d();
CREATE OR REPLACE FUNCTION public.founder_audit_failed_events_30d()
RETURNS TABLE (
  created_at      timestamptz,
  actor_email     text,
  op_name         text,
  target_table    text,
  reason          text,
  age_h           int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    a.created_at,
    coalesce(a.actor_email, '(unknown)')::text                          AS actor_email,
    coalesce(a.op_name, '(unknown)')::text                              AS op_name,
    coalesce(a.target_table, '(none)')::text                            AS target_table,
    coalesce(a.reason, '(no reason)')::text                             AS reason,
    extract(hour from (now() - a.created_at))::int                      AS age_h
  FROM public.founder_action_log a
  WHERE a.created_at >= now() - interval '30 days'
    AND a.outcome = 'failed'
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_audit_failed_events_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_audit_failed_events_30d() TO authenticated;
COMMIT;
