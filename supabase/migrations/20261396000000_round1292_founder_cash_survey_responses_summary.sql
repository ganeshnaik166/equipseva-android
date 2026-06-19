BEGIN;

DROP FUNCTION IF EXISTS public.founder_cash_survey_responses_summary();

CREATE OR REPLACE FUNCTION public.founder_cash_survey_responses_summary()
RETURNS TABLE (
  -- Response mix (90d)
  responses_90d                 bigint,
  asked_cash_90d                bigint,
  no_cash_90d                   bigint,
  declined_90d                  bigint,
  asked_to_no_ratio_90d         numeric,
  -- Reporter concentration (90d, asked_cash only)
  distinct_reporters_90d        bigint,
  hospitals_reporting_2plus_90d bigint,
  top_reporter_user_id          uuid,
  top_reporter_asked_cash_90d   bigint,
  -- Recidivism cohort (90d)
  engineers_with_repeat_90d     bigint,
  max_strikes_single_engineer   bigint,
  engineers_3plus_strikes_90d   bigint,
  -- Temporal signal
  asked_cash_this_week          bigint,
  asked_cash_prior_week         bigint,
  asked_cash_wow_delta_pct      numeric,
  -- Last response (any kind)
  last_response_at              timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_user uuid;
  v_top_cnt  bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Top reporter (hospital with most asked_cash submissions in 90d)
  SELECT hospital_user_id, cnt
    INTO v_top_user, v_top_cnt
    FROM (
      SELECT hospital_user_id, count(*)::bigint AS cnt
        FROM public.cash_survey_responses
       WHERE response = 'asked_cash'
         AND responded_at >= now() - interval '90 days'
       GROUP BY hospital_user_id
       ORDER BY cnt DESC
       LIMIT 1
    ) t;

  RETURN QUERY
  WITH base AS (
    SELECT
      count(*) FILTER (WHERE responded_at >= now() - interval '90 days') AS n_90d,
      count(*) FILTER (WHERE response = 'asked_cash' AND responded_at >= now() - interval '90 days') AS ac_90d,
      count(*) FILTER (WHERE response = 'no_cash'    AND responded_at >= now() - interval '90 days') AS nc_90d,
      count(*) FILTER (WHERE response = 'declined'   AND responded_at >= now() - interval '90 days') AS dc_90d,
      count(*) FILTER (WHERE response = 'asked_cash' AND responded_at >= now() - interval '7 days')  AS ac_w0,
      count(*) FILTER (WHERE response = 'asked_cash'
                         AND responded_at >= now() - interval '14 days'
                         AND responded_at <  now() - interval '7 days')                              AS ac_w1,
      max(responded_at)                                                                              AS last_at
    FROM public.cash_survey_responses
  ),
  reporters AS (
    SELECT count(DISTINCT hospital_user_id)::bigint AS n_distinct,
           count(*)::bigint                          AS n_with_2plus
      FROM (
        SELECT hospital_user_id, count(*) AS c
          FROM public.cash_survey_responses
         WHERE response = 'asked_cash'
           AND responded_at >= now() - interval '90 days'
         GROUP BY hospital_user_id
      ) r
  ),
  reporters_distinct AS (
    SELECT count(DISTINCT hospital_user_id)::bigint AS n_distinct
      FROM public.cash_survey_responses
     WHERE response = 'asked_cash'
       AND responded_at >= now() - interval '90 days'
  ),
  reporters_2plus AS (
    SELECT count(*)::bigint AS n_2plus
      FROM (
        SELECT hospital_user_id
          FROM public.cash_survey_responses
         WHERE response = 'asked_cash'
           AND responded_at >= now() - interval '90 days'
         GROUP BY hospital_user_id
        HAVING count(*) >= 2
      ) x
  ),
  recid AS (
    SELECT
      count(*) FILTER (WHERE strikes >= 2)::bigint AS n_repeat,
      count(*) FILTER (WHERE strikes >= 3)::bigint AS n_3plus,
      coalesce(max(strikes), 0)::bigint            AS max_strikes
      FROM (
        SELECT engineer_id, count(*) AS strikes
          FROM public.cash_survey_responses
         WHERE response = 'asked_cash'
           AND responded_at >= now() - interval '90 days'
         GROUP BY engineer_id
      ) e
  )
  SELECT
    base.n_90d::bigint,
    base.ac_90d::bigint,
    base.nc_90d::bigint,
    base.dc_90d::bigint,
    CASE WHEN base.nc_90d > 0 THEN round(base.ac_90d::numeric / base.nc_90d, 3) ELSE 0 END,
    reporters_distinct.n_distinct,
    reporters_2plus.n_2plus,
    v_top_user,
    coalesce(v_top_cnt, 0)::bigint,
    recid.n_repeat,
    recid.max_strikes,
    recid.n_3plus,
    base.ac_w0::bigint,
    base.ac_w1::bigint,
    CASE WHEN base.ac_w1 > 0
         THEN round(((base.ac_w0::numeric - base.ac_w1::numeric) * 100.0) / base.ac_w1, 1)
         WHEN base.ac_w0 > 0 THEN 100.0
         ELSE 0 END,
    base.last_at
  FROM base, reporters_distinct, reporters_2plus, recid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cash_survey_responses_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cash_survey_responses_summary() TO authenticated;

COMMIT;
