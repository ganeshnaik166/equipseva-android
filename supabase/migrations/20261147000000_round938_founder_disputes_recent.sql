BEGIN;
DROP FUNCTION IF EXISTS public.founder_disputes_recent();
CREATE OR REPLACE FUNCTION public.founder_disputes_recent()
RETURNS TABLE (
  id                  uuid,
  repair_job_id       uuid,
  submitter_name      text,
  status              text,
  submitted_at        timestamptz,
  mediator_decision_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id,
    d.repair_job_id,
    coalesce(p.full_name, '(submitter)'),
    d.status,
    d.submitted_at,
    d.mediator_decision_at
  FROM public.dispute_evidence_packs d
  LEFT JOIN public.profiles p ON p.id = d.filed_by_user_id
  WHERE d.submitted_at >= now() - interval '90 days'
    OR d.created_at >= now() - interval '90 days'
  ORDER BY coalesce(d.submitted_at, d.created_at) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_disputes_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_disputes_recent() TO authenticated;
COMMIT;
