BEGIN;

-- r1185 — founder_spot_audits_snapshot_summary()
-- 14-KPI consolidated dashboard for the spot-audit QA pipeline.
-- Backed by public.spot_audit_invitations + public.spot_audit_responses
-- (schema from migration 20260619100000_v21_spot_audits.sql).
--
-- Column truth-table verified by Read:
--   spot_audit_invitations:
--     id, repair_job_id, hospital_user_id, engineer_id (FK engineers.id),
--     created_at, expires_at
--   spot_audit_responses:
--     id, invitation_id, rating (1..5), feedback, responded_at
--
-- IST-day boundary pattern used for the *_today KPIs.

DROP FUNCTION IF EXISTS public.founder_spot_audits_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_spot_audits_snapshot_summary()
RETURNS TABLE (
  invitations_all_time     bigint,
  responses_all_time       bigint,
  response_pct_all_time    numeric,
  invitations_today        bigint,
  responses_today          bigint,
  invitations_30d          bigint,
  responses_30d            bigint,
  response_pct_30d         numeric,
  avg_rating_30d           numeric,
  five_star_pct_30d        numeric,
  low_rating_count_30d     bigint,
  open_invitations_now     bigint,
  expiring_within_24h      bigint,
  stuck_open_over_5d       bigint,
  hospitals_audited_30d    bigint,
  engineers_audited_30d    bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH
    inv_all AS (
      SELECT count(*)::bigint AS c FROM public.spot_audit_invitations
    ),
    resp_all AS (
      SELECT count(*)::bigint AS c FROM public.spot_audit_responses
    ),
    inv_today AS (
      SELECT count(*)::bigint AS c FROM public.spot_audit_invitations
      WHERE created_at >= v_today_start AND created_at < v_today_end
    ),
    resp_today AS (
      SELECT count(*)::bigint AS c FROM public.spot_audit_responses
      WHERE responded_at >= v_today_start AND responded_at < v_today_end
    ),
    inv_30d AS (
      SELECT count(*)::bigint AS c FROM public.spot_audit_invitations
      WHERE created_at >= now() - interval '30 days'
    ),
    resp_30d AS (
      SELECT
        count(*)::bigint                                              AS c,
        coalesce(round(avg(r.rating)::numeric, 2), 0)                 AS avg_rating,
        count(*) FILTER (WHERE r.rating = 5)::bigint                  AS five_star,
        count(*) FILTER (WHERE r.rating <= 2)::bigint                 AS low_rating
      FROM public.spot_audit_responses r
      WHERE r.responded_at >= now() - interval '30 days'
    ),
    open_now AS (
      SELECT count(*)::bigint AS c
      FROM public.spot_audit_invitations i
      WHERE i.expires_at > now()
        AND NOT EXISTS (
          SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id
        )
    ),
    expiring_24h AS (
      SELECT count(*)::bigint AS c
      FROM public.spot_audit_invitations i
      WHERE i.expires_at > now()
        AND i.expires_at <= now() + interval '24 hours'
        AND NOT EXISTS (
          SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id
        )
    ),
    stuck_5d AS (
      -- Invitation issued > 5 days ago, still no response, still alive
      SELECT count(*)::bigint AS c
      FROM public.spot_audit_invitations i
      WHERE i.created_at <= now() - interval '5 days'
        AND i.expires_at > now()
        AND NOT EXISTS (
          SELECT 1 FROM public.spot_audit_responses r WHERE r.invitation_id = i.id
        )
    ),
    hosp_30d AS (
      SELECT count(DISTINCT i.hospital_user_id)::bigint AS c
      FROM public.spot_audit_responses r
      JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
      WHERE r.responded_at >= now() - interval '30 days'
    ),
    eng_30d AS (
      SELECT count(DISTINCT i.engineer_id)::bigint AS c
      FROM public.spot_audit_responses r
      JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
      WHERE r.responded_at >= now() - interval '30 days'
        AND i.engineer_id IS NOT NULL
    )
  SELECT
    (SELECT c FROM inv_all)                                              AS invitations_all_time,
    (SELECT c FROM resp_all)                                             AS responses_all_time,
    CASE WHEN (SELECT c FROM inv_all) = 0 THEN 0::numeric
         ELSE round((SELECT c FROM resp_all)::numeric
                  / (SELECT c FROM inv_all)::numeric * 100.0, 1)
    END                                                                  AS response_pct_all_time,
    (SELECT c FROM inv_today)                                            AS invitations_today,
    (SELECT c FROM resp_today)                                           AS responses_today,
    (SELECT c FROM inv_30d)                                              AS invitations_30d,
    (SELECT c FROM resp_30d)                                             AS responses_30d,
    CASE WHEN (SELECT c FROM inv_30d) = 0 THEN 0::numeric
         ELSE round((SELECT c FROM resp_30d)::numeric
                  / (SELECT c FROM inv_30d)::numeric * 100.0, 1)
    END                                                                  AS response_pct_30d,
    (SELECT avg_rating  FROM resp_30d)                                   AS avg_rating_30d,
    CASE WHEN (SELECT c FROM resp_30d) = 0 THEN 0::numeric
         ELSE round((SELECT five_star FROM resp_30d)::numeric
                  / (SELECT c FROM resp_30d)::numeric * 100.0, 1)
    END                                                                  AS five_star_pct_30d,
    (SELECT low_rating FROM resp_30d)                                    AS low_rating_count_30d,
    (SELECT c FROM open_now)                                             AS open_invitations_now,
    (SELECT c FROM expiring_24h)                                         AS expiring_within_24h,
    (SELECT c FROM stuck_5d)                                             AS stuck_open_over_5d,
    (SELECT c FROM hosp_30d)                                             AS hospitals_audited_30d,
    (SELECT c FROM eng_30d)                                              AS engineers_audited_30d;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_spot_audits_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audits_snapshot_summary() TO authenticated;

COMMIT;
