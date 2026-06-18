BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_assignments_recent();
CREATE OR REPLACE FUNCTION public.founder_supervised_assignments_recent()
RETURNS TABLE (
  id                uuid,
  trainee_name      text,
  supervisor_name   text,
  status            text,
  requested_at      timestamptz,
  completed_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    coalesce(pt.full_name, '(trainee)'),
    coalesce(ps.full_name, '(supervisor)'),
    s.status,
    s.requested_at,
    s.completed_at
  FROM public.supervised_job_assignments s
  LEFT JOIN public.profiles pt ON pt.id = s.trainee_user_id
  LEFT JOIN public.profiles ps ON ps.id = s.supervisor_user_id
  WHERE s.requested_at >= now() - interval '30 days'
  ORDER BY s.requested_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_assignments_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_assignments_recent() TO authenticated;
COMMIT;
