BEGIN;
-- Round 1287 — founder_spot_audit_responses_summary.
--
-- spot_audit_responses (v2.1 PR-D43) is the hospital-side completed-job
-- quality check: 1-in-20 sampled jobs get an invitation, hospital
-- responds with rating 1..5 + optional free-text. Distinct from the
-- targeted cash-flag survey (per-job single-question) and distinct
-- from spot_audits (legacy/ground-ops audit table) — this is the
-- hospital-served random-sweep response ledger.
--
-- Existing RPCs already cover invitation/response counts and aggregate
-- pass-rate. This one is laser-focused on the RESPONSES table itself:
-- volume by window, rating-band mix, free-text engagement, time-to-
-- respond from invitation, distinct hospitals + engineers covered,
-- and stream freshness — direct signal on field-integrity program
-- health (engagement compliance + tone of received feedback).

BEGIN;

DROP FUNCTION IF EXISTS public.founder_spot_audit_responses_summary();

CREATE OR REPLACE FUNCTION public.founder_spot_audit_responses_summary()
RETURNS TABLE (
  responses_24h            bigint,
  responses_7d             bigint,
  responses_30d            bigint,
  responses_90d            bigint,
  low_rating_30d           bigint,
  mid_rating_30d           bigint,
  high_rating_30d          bigint,
  avg_rating_30d           numeric,
  with_feedback_30d        bigint,
  feedback_pct_30d         numeric,
  distinct_hospitals_30d   bigint,
  distinct_engineers_30d   bigint,
  median_response_hours_30d numeric,
  last_response_at         timestamptz
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT r.id,
           r.invitation_id,
           r.rating,
           r.feedback,
           r.responded_at,
           i.hospital_user_id,
           i.engineer_id,
           i.created_at AS invited_at
      FROM public.spot_audit_responses r
      JOIN public.spot_audit_invitations i ON i.id = r.invitation_id
     WHERE r.responded_at >= now() - interval '90 days'
  ),
  thirty AS (
    SELECT * FROM recent WHERE responded_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*) FROM recent WHERE responded_at >= now() - interval '24 hours')::bigint    AS responses_24h,
    (SELECT count(*) FROM recent WHERE responded_at >= now() - interval '7 days')::bigint      AS responses_7d,
    (SELECT count(*) FROM thirty)::bigint                                                       AS responses_30d,
    (SELECT count(*) FROM recent)::bigint                                                       AS responses_90d,
    (SELECT count(*) FROM thirty WHERE rating <= 2)::bigint                                     AS low_rating_30d,
    (SELECT count(*) FROM thirty WHERE rating  = 3)::bigint                                     AS mid_rating_30d,
    (SELECT count(*) FROM thirty WHERE rating >= 4)::bigint                                     AS high_rating_30d,
    COALESCE((SELECT round(avg(rating)::numeric, 2) FROM thirty), 0)::numeric                   AS avg_rating_30d,
    (SELECT count(*) FROM thirty WHERE feedback IS NOT NULL AND length(trim(feedback)) > 0)::bigint AS with_feedback_30d,
    CASE WHEN (SELECT count(*) FROM thirty) = 0 THEN 0::numeric
         ELSE round(
           (SELECT count(*) FROM thirty WHERE feedback IS NOT NULL AND length(trim(feedback)) > 0)::numeric
           * 100.0 / (SELECT count(*) FROM thirty)::numeric, 1)
    END                                                                                          AS feedback_pct_30d,
    (SELECT count(DISTINCT hospital_user_id) FROM thirty)::bigint                                AS distinct_hospitals_30d,
    (SELECT count(DISTINCT engineer_id)      FROM thirty WHERE engineer_id IS NOT NULL)::bigint  AS distinct_engineers_30d,
    COALESCE((
      SELECT round(
        (percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (responded_at - invited_at)) / 3600.0))::numeric,
        2)
        FROM thirty
       WHERE invited_at IS NOT NULL
    ), 0)::numeric                                                                                AS median_response_hours_30d,
    (SELECT max(responded_at) FROM recent)                                                       AS last_response_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_spot_audit_responses_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spot_audit_responses_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_spot_audit_responses_summary() IS
  'Round 1287: 14-KPI snapshot over spot_audit_responses (v2.1 PR-D43). Hospital-side 1-in-20 random-sweep rating ledger — distinct from targeted cash-flag survey and from legacy spot_audits table. Field-integrity program health: volume, rating-band mix, free-text engagement, time-to-respond, hospital/engineer coverage.';

COMMIT;
