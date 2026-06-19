BEGIN;
-- r1310 — v0.5 Phase 8: Spot-audit cron + engineer-rotation enforcement.
-- Auto-invites hospitals for spot audit on every 10th completed job per engineer.
-- Tracks engineer compliance — if engineer accumulates 3 ignored invites in 90d,
-- they enter the "rotation_frozen" state until they respond to a fresh invite.
--
-- Two new state-tracking constructs:
--   • engineer_audit_compliance — running tally of skipped vs responded invites per engineer
--   • spot_audit_auto_invitation cron job — runs hourly

CREATE TABLE IF NOT EXISTS public.engineer_audit_compliance (
  engineer_user_id     uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  invitations_sent     int  NOT NULL DEFAULT 0,
  responses_received   int  NOT NULL DEFAULT 0,
  ignored_in_90d       int  NOT NULL DEFAULT 0,
  rotation_frozen      boolean NOT NULL DEFAULT false,
  rotation_frozen_at   timestamptz,
  rotation_unfrozen_at timestamptz,
  last_invite_at       timestamptz,
  updated_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.engineer_audit_compliance IS
  'Per-engineer spot-audit compliance signal · drives rotation-freeze if ≥3 ignored in 90d.';

ALTER TABLE public.engineer_audit_compliance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS engineer_audit_compliance_no_direct ON public.engineer_audit_compliance;
CREATE POLICY engineer_audit_compliance_no_direct ON public.engineer_audit_compliance FOR ALL USING (false);
REVOKE ALL ON TABLE public.engineer_audit_compliance FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Cron job: spot_audit_auto_invite (runs hourly)
--   For each engineer with > 0 completed jobs whose count is a multiple of 10
--   and who has no open invitation, create one for the latest completed job's
--   hospital_user_id.
-- ============================================================================
DROP FUNCTION IF EXISTS public.spot_audit_auto_invite();
CREATE OR REPLACE FUNCTION public.spot_audit_auto_invite()
RETURNS TABLE (invited_count int, frozen_count int, unfrozen_count int)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_invited int := 0;
  v_frozen int := 0;
  v_unfrozen int := 0;
BEGIN
  -- 1. Refresh compliance tallies from spot_audit_invitations + responses
  INSERT INTO public.engineer_audit_compliance
    (engineer_user_id, invitations_sent, responses_received, ignored_in_90d, last_invite_at, updated_at)
  SELECT
    e.user_id,
    coalesce((SELECT count(*) FROM public.spot_audit_invitations si
              JOIN public.engineers eng ON eng.id = si.engineer_id
              WHERE eng.user_id = e.user_id), 0)::int,
    coalesce((SELECT count(*) FROM public.spot_audit_responses sr
              JOIN public.spot_audit_invitations si ON si.id = sr.invitation_id
              JOIN public.engineers eng ON eng.id = si.engineer_id
              WHERE eng.user_id = e.user_id), 0)::int,
    coalesce((SELECT count(*) FROM public.spot_audit_invitations si
              JOIN public.engineers eng ON eng.id = si.engineer_id
              WHERE eng.user_id = e.user_id
                AND si.created_at >= now() - interval '90 days'
                AND si.expires_at < now()
                AND NOT EXISTS (SELECT 1 FROM public.spot_audit_responses sr WHERE sr.invitation_id = si.id)), 0)::int,
    (SELECT max(si.created_at) FROM public.spot_audit_invitations si
      JOIN public.engineers eng ON eng.id = si.engineer_id WHERE eng.user_id = e.user_id),
    now()
  FROM public.engineers e
  ON CONFLICT (engineer_user_id) DO UPDATE SET
    invitations_sent = EXCLUDED.invitations_sent,
    responses_received = EXCLUDED.responses_received,
    ignored_in_90d = EXCLUDED.ignored_in_90d,
    last_invite_at = EXCLUDED.last_invite_at,
    updated_at = now();

  -- 2. Freeze engineers with ≥3 ignored invites in 90d (if not already frozen)
  WITH frozen AS (
    UPDATE public.engineer_audit_compliance
    SET rotation_frozen = true, rotation_frozen_at = now()
    WHERE ignored_in_90d >= 3 AND rotation_frozen = false
    RETURNING 1
  )
  SELECT count(*)::int INTO v_frozen FROM frozen;

  -- 3. Unfreeze engineers who've dropped below 3 ignored
  WITH unfrozen AS (
    UPDATE public.engineer_audit_compliance
    SET rotation_frozen = false, rotation_unfrozen_at = now()
    WHERE ignored_in_90d < 3 AND rotation_frozen = true
    RETURNING 1
  )
  SELECT count(*)::int INTO v_unfrozen FROM unfrozen;

  -- 4. For each engineer with completed_job_count % 10 == 0 in last 24h and no open invite,
  -- create a new invitation. Use the latest completed job's hospital_user_id.
  WITH completed_per_engineer AS (
    SELECT j.engineer_id, count(*) AS completed
    FROM public.repair_jobs j
    WHERE j.status = 'completed' AND j.engineer_id IS NOT NULL
    GROUP BY j.engineer_id
  ),
  candidates AS (
    SELECT DISTINCT ON (j.engineer_id)
      j.id AS repair_job_id,
      j.hospital_user_id,
      j.engineer_id,
      cpe.completed
    FROM public.repair_jobs j
    JOIN completed_per_engineer cpe ON cpe.engineer_id = j.engineer_id
    WHERE j.status = 'completed'
      AND cpe.completed > 0 AND cpe.completed % 10 = 0
      AND j.completed_at >= now() - interval '24 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.spot_audit_invitations si
        WHERE si.repair_job_id = j.id
      )
    ORDER BY j.engineer_id, j.completed_at DESC
  ),
  inserted_inv AS (
    INSERT INTO public.spot_audit_invitations (repair_job_id, hospital_user_id, engineer_id)
    SELECT c.repair_job_id, c.hospital_user_id, c.engineer_id FROM candidates c
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  SELECT count(*)::int INTO v_invited FROM inserted_inv;

  RETURN QUERY SELECT v_invited, v_frozen, v_unfrozen;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.spot_audit_auto_invite() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.spot_audit_auto_invite() TO authenticated;

-- ============================================================================
-- founder_spot_audit_rotation_summary — for founder UI
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_spot_audit_rotation_summary();
CREATE OR REPLACE FUNCTION public.founder_spot_audit_rotation_summary()
RETURNS TABLE (
  engineers_tracked            bigint,
  engineers_with_any_invite    bigint,
  engineers_frozen             bigint,
  engineers_at_risk_2_ignored  bigint,
  pending_invitations_now      bigint,
  invitations_created_today    bigint,
  response_rate_pct            numeric,
  avg_responses_per_engineer   numeric,
  rotation_freezes_30d         bigint,
  rotation_unfreezes_30d       bigint,
  oldest_unresponded_invite_age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_total_inv bigint;
  v_total_resp bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT sum(invitations_sent)::bigint, sum(responses_received)::bigint INTO v_total_inv, v_total_resp
  FROM public.engineer_audit_compliance;
  IF v_total_inv IS NULL THEN v_total_inv := 0; END IF;
  IF v_total_resp IS NULL THEN v_total_resp := 0; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance WHERE invitations_sent > 0), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance WHERE rotation_frozen = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance WHERE ignored_in_90d = 2 AND rotation_frozen = false), 0),
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations
              WHERE expires_at > now() AND NOT EXISTS (SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = spot_audit_invitations.id)), 0),
    coalesce((SELECT count(*)::bigint FROM public.spot_audit_invitations WHERE created_at >= v_today_start), 0),
    CASE WHEN v_total_inv = 0 THEN 0::numeric ELSE round(100.0 * v_total_resp / v_total_inv, 1) END,
    CASE WHEN (SELECT count(*) FROM public.engineer_audit_compliance) = 0 THEN 0::numeric
         ELSE round(v_total_resp::numeric / (SELECT count(*) FROM public.engineer_audit_compliance), 2) END,
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance WHERE rotation_frozen_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance WHERE rotation_unfrozen_at >= now() - interval '30 days'), 0),
    coalesce((SELECT extract(day from (now() - min(si.created_at)))::int FROM public.spot_audit_invitations si
              WHERE NOT EXISTS (SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = si.id)
                AND si.expires_at > now()), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spot_audit_rotation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audit_rotation_summary() TO authenticated;

-- Bootstrap run
SELECT public.spot_audit_auto_invite();

COMMIT;
