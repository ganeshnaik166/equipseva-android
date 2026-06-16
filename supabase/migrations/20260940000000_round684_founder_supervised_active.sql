BEGIN;
DROP FUNCTION IF EXISTS public.founder_supervised_active();
CREATE OR REPLACE FUNCTION public.founder_supervised_active()
RETURNS TABLE (
  assignment_id        uuid,
  trainee_user_id      uuid,
  trainee_name         text,
  supervisor_user_id   uuid,
  supervisor_name      text,
  status               text,
  days_open            int,
  signoff_outcome      text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.trainee_user_id,
    coalesce(tp.full_name, '(trainee)'),
    s.supervisor_user_id,
    coalesce(sp.full_name, '(supervisor)'),
    s.status,
    (extract(epoch FROM (now() - s.requested_at))::int / 86400),
    s.signoff_outcome
  FROM public.supervised_job_assignments s
  LEFT JOIN public.profiles tp ON tp.id = s.trainee_user_id
  LEFT JOIN public.profiles sp ON sp.id = s.supervisor_user_id
  WHERE s.status IN ('pending_supervisor_accept', 'active')
  ORDER BY s.requested_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supervised_active() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supervised_active() TO authenticated;
COMMIT;
