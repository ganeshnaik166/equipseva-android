-- v2.1 PR-D26: admin escrow event timeline drill-down.
--
-- Admin dispute resolution surface (PR-D21 + PR-D22 push trigger) lets
-- founder pick release/refund directly from the queue row, but they
-- decide based on `dispute_reason` text only. The repair_job_escrow_events
-- audit table records every state transition (created -> paid ->
-- release_scheduled -> disputed -> ...) — exposing that timeline
-- gives the founder ground truth on the dispute timing + the actor
-- behind each step.
--
-- Returns the events list joined to profiles (actor full_name) so the
-- screen renders without N+1 lookups. SECDEF + admin/founder gate.
-- Ordered chronologically (occurred_at ASC) so the founder can read
-- the story top-to-bottom.

CREATE OR REPLACE FUNCTION public.admin_escrow_event_timeline(
  p_escrow_id uuid
)
RETURNS TABLE (
  event_id      uuid,
  event_kind    text,
  occurred_at   timestamptz,
  actor_user_id uuid,
  actor_name    text,
  payload       jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id           AS event_id,
    e.event_kind,
    e.occurred_at,
    e.actor_user_id,
    coalesce(p.full_name, '(system)') AS actor_name,
    e.payload
    FROM public.repair_job_escrow_events e
    LEFT JOIN public.profiles p ON p.id = e.actor_user_id
   WHERE e.escrow_id = p_escrow_id
   ORDER BY e.occurred_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_escrow_event_timeline(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_escrow_event_timeline(uuid) TO authenticated;
