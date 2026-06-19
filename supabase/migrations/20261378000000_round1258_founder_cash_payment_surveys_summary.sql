BEGIN;

DROP FUNCTION IF EXISTS public.founder_cash_payment_surveys_summary();

CREATE OR REPLACE FUNCTION public.founder_cash_payment_surveys_summary()
RETURNS TABLE (
  -- Volume (all-time + 90d)
  surveys_total                bigint,
  surveys_90d                  bigint,
  surveys_30d                  bigint,
  surveys_7d                   bigint,
  -- Response breakdown (90d)
  asked_cash_90d               bigint,
  no_cash_90d                  bigint,
  declined_90d                 bigint,
  -- Conversion / leakage rates
  asked_cash_rate_pct_90d      numeric,
  asked_cash_rate_pct_30d      numeric,
  declined_rate_pct_90d        numeric,
  -- Distinct offending engineers
  distinct_flagged_engineers_90d  bigint,
  -- Engineers currently over 3-strike threshold (90d)
  engineers_over_threshold_90d bigint,
  -- Most recent confession
  last_asked_cash_at           timestamptz,
  -- Top offender (90d)
  top_offender_name            text,
  top_offender_asked_cash_90d  bigint,
  top_offender_engineer_id     uuid,
  -- Top hotspot state (where hospitals report most cash asks, 90d)
  top_hotspot_state            text,
  top_hotspot_state_asked_cash bigint,
  -- Coverage: how many completed jobs in last 7d still missing a survey
  pending_surveys_7d           bigint,
  completed_jobs_7d            bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_off_id    uuid;
  v_top_off_name  text;
  v_top_off_cnt   bigint;
  v_top_state     text;
  v_top_state_cnt bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Top offender lookup (90d window)
  SELECT csr.engineer_id, coalesce(p.full_name, '(unnamed)'), cnt
    INTO v_top_off_id, v_top_off_name, v_top_off_cnt
    FROM (
      SELECT engineer_id, count(*)::bigint AS cnt
        FROM public.cash_survey_responses
       WHERE response = 'asked_cash'
         AND responded_at >= now() - interval '90 days'
       GROUP BY engineer_id
       ORDER BY cnt DESC
       LIMIT 1
    ) csr
    JOIN public.engineers e ON e.id = csr.engineer_id
    LEFT JOIN public.profiles p ON p.id = e.user_id;

  -- Top hotspot state (joining hospital profile state)
  SELECT pr.state, cnt
    INTO v_top_state, v_top_state_cnt
    FROM (
      SELECT csr.hospital_user_id, count(*)::bigint AS cnt
        FROM public.cash_survey_responses csr
       WHERE csr.response = 'asked_cash'
         AND csr.responded_at >= now() - interval '90 days'
       GROUP BY csr.hospital_user_id
    ) h
    JOIN public.profiles pr ON pr.id = h.hospital_user_id
   WHERE pr.state IS NOT NULL
   GROUP BY pr.state
   ORDER BY sum(h.cnt) DESC
   LIMIT 1;

  RETURN QUERY
  WITH base AS (
    SELECT
      count(*)                                                                              AS total,
      count(*) FILTER (WHERE responded_at >= now() - interval '90 days')                    AS n_90d,
      count(*) FILTER (WHERE responded_at >= now() - interval '30 days')                    AS n_30d,
      count(*) FILTER (WHERE responded_at >= now() - interval '7 days')                     AS n_7d,
      count(*) FILTER (WHERE response = 'asked_cash'  AND responded_at >= now() - interval '90 days') AS ac_90d,
      count(*) FILTER (WHERE response = 'no_cash'     AND responded_at >= now() - interval '90 days') AS nc_90d,
      count(*) FILTER (WHERE response = 'declined'    AND responded_at >= now() - interval '90 days') AS dc_90d,
      count(*) FILTER (WHERE response = 'asked_cash'  AND responded_at >= now() - interval '30 days') AS ac_30d,
      max(responded_at) FILTER (WHERE response = 'asked_cash')                              AS last_ac
    FROM public.cash_survey_responses
  ),
  flagged AS (
    SELECT count(DISTINCT engineer_id)::bigint AS n
      FROM public.cash_survey_responses
     WHERE response = 'asked_cash'
       AND responded_at >= now() - interval '90 days'
  ),
  over_thresh AS (
    SELECT count(*)::bigint AS n
      FROM (
        SELECT engineer_id
          FROM public.cash_survey_responses
         WHERE response = 'asked_cash'
           AND responded_at >= now() - interval '90 days'
         GROUP BY engineer_id
        HAVING count(*) >= 3
      ) x
  ),
  jobs7 AS (
    SELECT
      count(*) FILTER (
        WHERE rj.status::text = 'completed'
          AND rj.completed_at IS NOT NULL
          AND rj.completed_at >= now() - interval '7 days'
          AND rj.completed_at <= now() - interval '24 hours'
          AND rj.hospital_user_id IS NOT NULL
          AND rj.engineer_id IS NOT NULL
      )::bigint AS completed_in_window,
      count(*) FILTER (
        WHERE rj.status::text = 'completed'
          AND rj.completed_at IS NOT NULL
          AND rj.completed_at >= now() - interval '7 days'
          AND rj.completed_at <= now() - interval '24 hours'
          AND rj.hospital_user_id IS NOT NULL
          AND rj.engineer_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM public.cash_survey_responses csr
             WHERE csr.repair_job_id = rj.id
          )
      )::bigint AS pending_in_window
    FROM public.repair_jobs rj
  )
  SELECT
    base.total::bigint,
    base.n_90d::bigint,
    base.n_30d::bigint,
    base.n_7d::bigint,
    base.ac_90d::bigint,
    base.nc_90d::bigint,
    base.dc_90d::bigint,
    CASE WHEN base.n_90d > 0 THEN round((base.ac_90d::numeric * 100.0) / base.n_90d, 1) ELSE 0 END,
    CASE WHEN base.n_30d > 0 THEN round((base.ac_30d::numeric * 100.0) / base.n_30d, 1) ELSE 0 END,
    CASE WHEN base.n_90d > 0 THEN round((base.dc_90d::numeric * 100.0) / base.n_90d, 1) ELSE 0 END,
    flagged.n,
    over_thresh.n,
    base.last_ac,
    v_top_off_name,
    coalesce(v_top_off_cnt, 0)::bigint,
    v_top_off_id,
    v_top_state,
    coalesce(v_top_state_cnt, 0)::bigint,
    jobs7.pending_in_window,
    jobs7.completed_in_window
  FROM base, flagged, over_thresh, jobs7;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cash_payment_surveys_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cash_payment_surveys_summary() TO authenticated;

COMMIT;
