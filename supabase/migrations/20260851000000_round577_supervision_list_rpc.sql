-- Round 577 — founder_list_supervision_assignments RPC
--
-- r576 RLS-locks supervised_job_assignments deny-all + REVOKEs table-
-- level grants from authenticated. The Web Console runs as `authenticated`
-- via PostgREST so a direct supabase.from('supervised_job_assignments')
-- query yields zero rows. Add a thin SECDEF list RPC so the /training
-- founder cockpit can render the full table without dropping the
-- deny-all RLS.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_list_supervision_assignments(int);
CREATE OR REPLACE FUNCTION public.founder_list_supervision_assignments(
  p_limit int DEFAULT 200
)
RETURNS TABLE (
  id                              uuid,
  trainee_user_id                 uuid,
  supervisor_user_id              uuid,
  repair_job_id                   uuid,
  trainee_tier_at_assignment      text,
  supervisor_tier_at_assignment   text,
  status                          text,
  decline_reason                  text,
  signoff_outcome                 text,
  signoff_notes                   text,
  requested_at                    timestamptz,
  accepted_at                     timestamptz,
  completed_at                    timestamptz,
  signoff_at                      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_limit := least(greatest(coalesce(p_limit, 200), 1), 500);

  RETURN QUERY
  SELECT
    s.id,
    s.trainee_user_id,
    s.supervisor_user_id,
    s.repair_job_id,
    s.trainee_tier_at_assignment,
    s.supervisor_tier_at_assignment,
    s.status,
    s.decline_reason,
    s.signoff_outcome,
    s.signoff_notes,
    s.requested_at,
    s.accepted_at,
    s.completed_at,
    s.signoff_at
  FROM public.supervised_job_assignments s
  ORDER BY s.requested_at DESC
  LIMIT v_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_supervision_assignments(int)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_list_supervision_assignments(int)
  TO authenticated;

COMMIT;
