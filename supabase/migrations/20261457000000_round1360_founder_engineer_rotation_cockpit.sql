BEGIN;
-- r1360 — Founder Engineer Rotation Cockpit.
-- Read-only aggregator over engineer_audit_compliance (r1310) + spot_audit_invitations/responses (v2.1).
-- Surfaces: who is frozen now, who is approaching freeze (2 ignored in 90d), response signal, freeze churn.

-- ============================================================================
-- founder_engineer_rotation_cockpit_summary — 14 KPI roll-up
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_rotation_cockpit_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_cockpit_summary()
RETURNS TABLE (
  total_engineers_active             bigint,
  engineers_frozen_now               bigint,
  engineers_unfrozen_30d             bigint,
  engineers_with_recent_invite       bigint,
  engineers_ignored_invite_count_30d bigint,
  engineers_responded_invite_count_30d bigint,
  response_rate_pct_30d              numeric,
  avg_rating_30d                     numeric,
  repeat_low_rating_engineers        bigint,
  frozen_avg_age_days                numeric,
  newest_freeze_engineer_id          uuid,
  newest_freeze_engineer_label       text,
  newest_freeze_age_days             int,
  last_audit_run_at                  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_inv_30d bigint;
  v_resp_30d bigint;
  v_newest_id uuid;
  v_newest_label text;
  v_newest_age int;
  v_newest_at timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_inv_30d
    FROM public.spot_audit_invitations
   WHERE created_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_resp_30d
    FROM public.spot_audit_responses
   WHERE responded_at >= now() - interval '30 days';

  SELECT eac.engineer_user_id,
         coalesce(p.full_name, '(engineer)'),
         extract(day from (now() - eac.rotation_frozen_at))::int,
         eac.rotation_frozen_at
    INTO v_newest_id, v_newest_label, v_newest_age, v_newest_at
    FROM public.engineer_audit_compliance eac
    LEFT JOIN public.profiles p ON p.id = eac.engineer_user_id
   WHERE eac.rotation_frozen = true
   ORDER BY eac.rotation_frozen_at DESC NULLS LAST
   LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineers e
                WHERE e.verification_status::text = 'verified'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance
                WHERE rotation_frozen = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_audit_compliance
                WHERE rotation_unfrozen_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT eng.user_id)::bigint
                FROM public.spot_audit_invitations si
                JOIN public.engineers eng ON eng.id = si.engineer_id
               WHERE si.created_at >= now() - interval '90 days'), 0),
    coalesce((SELECT count(DISTINCT eng.user_id)::bigint
                FROM public.spot_audit_invitations si
                JOIN public.engineers eng ON eng.id = si.engineer_id
               WHERE si.created_at >= now() - interval '30 days'
                 AND si.expires_at < now()
                 AND NOT EXISTS (SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = si.id)), 0),
    coalesce((SELECT count(DISTINCT eng.user_id)::bigint
                FROM public.spot_audit_responses sr
                JOIN public.spot_audit_invitations si ON si.id = sr.invitation_id
                JOIN public.engineers eng ON eng.id = si.engineer_id
               WHERE sr.responded_at >= now() - interval '30 days'), 0),
    CASE WHEN v_inv_30d = 0 THEN 0::numeric
         ELSE round(100.0 * v_resp_30d / v_inv_30d, 1) END,
    coalesce((SELECT round(avg(sr.rating)::numeric, 2)
                FROM public.spot_audit_responses sr
               WHERE sr.responded_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM (
                SELECT eng.user_id
                  FROM public.spot_audit_responses sr
                  JOIN public.spot_audit_invitations si ON si.id = sr.invitation_id
                  JOIN public.engineers eng ON eng.id = si.engineer_id
                 WHERE sr.rating <= 2
                   AND sr.responded_at >= now() - interval '180 days'
                 GROUP BY eng.user_id
                HAVING count(*) >= 3
              ) low), 0),
    coalesce((SELECT round(avg(extract(day from (now() - rotation_frozen_at)))::numeric, 1)
                FROM public.engineer_audit_compliance
               WHERE rotation_frozen = true AND rotation_frozen_at IS NOT NULL), 0),
    v_newest_id,
    v_newest_label,
    coalesce(v_newest_age, 0),
    (SELECT max(updated_at) FROM public.engineer_audit_compliance);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_summary() TO authenticated;

-- ============================================================================
-- founder_engineer_rotation_cockpit_frozen — per-engineer frozen ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_rotation_cockpit_frozen(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_cockpit_frozen(p_limit int DEFAULT 50)
RETURNS TABLE (
  engineer_user_id     uuid,
  engineer_label       text,
  invitations_sent     int,
  responses_received   int,
  ignored_in_90d       int,
  rotation_frozen_at   timestamptz,
  age_days             int,
  last_invite_at       timestamptz,
  last_invite_age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    eac.engineer_user_id,
    coalesce(p.full_name, '(engineer)') AS engineer_label,
    eac.invitations_sent,
    eac.responses_received,
    eac.ignored_in_90d,
    eac.rotation_frozen_at,
    coalesce(extract(day from (now() - eac.rotation_frozen_at))::int, 0) AS age_days,
    eac.last_invite_at,
    coalesce(extract(day from (now() - eac.last_invite_at))::int, 0) AS last_invite_age_days
  FROM public.engineer_audit_compliance eac
  LEFT JOIN public.profiles p ON p.id = eac.engineer_user_id
  WHERE eac.rotation_frozen = true
  ORDER BY eac.rotation_frozen_at DESC NULLS LAST
  LIMIT greatest(1, least(p_limit, 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_frozen(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_frozen(int) TO authenticated;

-- ============================================================================
-- founder_engineer_rotation_cockpit_at_risk — engineers approaching freeze
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_rotation_cockpit_at_risk(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_rotation_cockpit_at_risk(p_limit int DEFAULT 50)
RETURNS TABLE (
  engineer_user_id   uuid,
  engineer_label     text,
  invitations_sent   int,
  responses_received int,
  ignored_in_90d     int,
  last_invite_at     timestamptz,
  last_invite_age_days int,
  response_rate_pct  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    eac.engineer_user_id,
    coalesce(p.full_name, '(engineer)') AS engineer_label,
    eac.invitations_sent,
    eac.responses_received,
    eac.ignored_in_90d,
    eac.last_invite_at,
    coalesce(extract(day from (now() - eac.last_invite_at))::int, 0) AS last_invite_age_days,
    CASE WHEN eac.invitations_sent = 0 THEN 0::numeric
         ELSE round(100.0 * eac.responses_received / eac.invitations_sent, 1) END AS response_rate_pct
  FROM public.engineer_audit_compliance eac
  LEFT JOIN public.profiles p ON p.id = eac.engineer_user_id
  WHERE eac.rotation_frozen = false
    AND eac.ignored_in_90d >= 2
  ORDER BY eac.ignored_in_90d DESC, eac.last_invite_at DESC NULLS LAST
  LIMIT greatest(1, least(p_limit, 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_at_risk(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_rotation_cockpit_at_risk(int) TO authenticated;

COMMIT;