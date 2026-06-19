BEGIN;
-- r1333 — CRITICAL audit-fix sweep for r1325 + r1326 from workflow wsau9r0wz.
--
-- 5 confirmed bugs (3 CRITICAL on r1325, 1 HIGH on r1325, 1 HIGH on r1326):
--
-- 1. r1325 CRITICAL: founder_payroll_batch_dryrun + log_founder_payroll_batch_create
--    reference public.repair_job_disputes — table DOES NOT EXIST. Real dispute
--    tracking is via repair_job_escrow.status='in_dispute' (CHECK in
--    'pending','held','in_dispute','released','refunded','cancelled').
--    First call would 500 with "relation does not exist".
--
-- 2. r1326 HIGH: log_founder_nps_record_response signature missed p_respondent_role
--    even though the column exists in founder_nps_responses + the RECENT RPC
--    returns it. Result: respondent_role always NULL.

-- ============================================================================
-- 1. r1325 founder_payroll_batch_dryrun — fix dispute check
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_payroll_batch_dryrun(date, date);
CREATE OR REPLACE FUNCTION public.founder_payroll_batch_dryrun(
  p_period_start date,
  p_period_end   date
)
RETURNS TABLE (
  candidate_payout_count              bigint,
  total_amount_rupees                 numeric,
  engineer_count                      bigint,
  median_payout_rupees                numeric,
  largest_payout_rupees               numeric,
  smallest_payout_rupees              numeric,
  payouts_blocked_missing_kyc         bigint,
  payouts_blocked_missing_upi_or_bank bigint,
  payouts_blocked_disputed            bigint,
  payouts_ok_to_authorize             bigint,
  sample_top_5_amounts                jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      p.id,
      p.engineer_user_id,
      p.amount_rupees::numeric                                  AS amt,
      coalesce(e.verification_status::text, 'pending')          AS vstatus,
      (p.payout_method_id IS NOT NULL)                          AS has_method,
      -- r1333 FIX: repair_job_disputes does not exist → use repair_job_escrow
      EXISTS (
        SELECT 1
        FROM public.repair_job_escrow esc
        WHERE esc.repair_job_id = p.repair_job_id
          AND esc.status = 'in_dispute'
      ) AS is_disputed
    FROM public.engineer_payouts p
    LEFT JOIN public.engineers e ON e.user_id = p.engineer_user_id
    WHERE p.status = 'queued'
      AND p.queued_at >= p_period_start::timestamptz
      AND p.queued_at <  (p_period_end + 1)::timestamptz
  )
  SELECT
    coalesce(count(*), 0)::bigint,
    coalesce(sum(amt), 0)::numeric,
    coalesce(count(DISTINCT engineer_user_id), 0)::bigint,
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY amt), 0)::numeric,
    coalesce(max(amt), 0)::numeric,
    coalesce(min(amt), 0)::numeric,
    coalesce(count(*) FILTER (WHERE vstatus <> 'verified'), 0)::bigint,
    coalesce(count(*) FILTER (WHERE NOT has_method), 0)::bigint,
    coalesce(count(*) FILTER (WHERE is_disputed), 0)::bigint,
    coalesce(count(*) FILTER (
      WHERE vstatus = 'verified' AND has_method AND NOT is_disputed
    ), 0)::bigint,
    coalesce((
      SELECT jsonb_agg(jsonb_build_object('payout_id', id, 'amount_rupees', amt)
                       ORDER BY amt DESC)
      FROM (SELECT id, amt FROM base ORDER BY amt DESC LIMIT 5) t
    ), '[]'::jsonb)
  FROM base;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payroll_batch_dryrun(date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payroll_batch_dryrun(date, date) TO authenticated;

-- ============================================================================
-- 2. r1325 log_founder_payroll_batch_create — same dispute fix + materialize
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_payroll_batch_create(date, date);
CREATE OR REPLACE FUNCTION public.log_founder_payroll_batch_create(
  p_period_start date,
  p_period_end   date
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id    uuid;
  v_label text;
  v_ids   uuid[];
  v_count int;
  v_total numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_period_end < p_period_start THEN RAISE EXCEPTION 'period_end must be >= period_start'; END IF;

  SELECT
    coalesce(array_agg(p.id ORDER BY p.queued_at), ARRAY[]::uuid[]),
    coalesce(count(*), 0)::int,
    coalesce(sum(p.amount_rupees), 0)::numeric
  INTO v_ids, v_count, v_total
  FROM public.engineer_payouts p
  LEFT JOIN public.engineers e ON e.user_id = p.engineer_user_id
  WHERE p.status = 'queued'
    AND p.queued_at >= p_period_start::timestamptz
    AND p.queued_at <  (p_period_end + 1)::timestamptz
    AND coalesce(e.verification_status::text, 'pending') = 'verified'
    AND p.payout_method_id IS NOT NULL
    -- r1333 FIX: repair_job_disputes does not exist → use repair_job_escrow
    AND NOT EXISTS (
      SELECT 1 FROM public.repair_job_escrow esc
      WHERE esc.repair_job_id = p.repair_job_id
        AND esc.status = 'in_dispute'
    );

  v_label := 'payroll-' || to_char(p_period_start, 'YYYYMMDD') || '-'
                       || to_char(p_period_end,   'YYYYMMDD') || '-'
                       || to_char(now() AT TIME ZONE 'Asia/Kolkata', 'HH24MISS');

  INSERT INTO public.founder_payroll_batches (
    batch_label, period_start, period_end,
    total_payouts_count, total_amount_rupees,
    payout_ids, status
  )
  VALUES (
    v_label, p_period_start, p_period_end,
    v_count, v_total, v_ids, 'draft'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_payroll_batch_create(date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_payroll_batch_create(date, date) TO authenticated;

-- ============================================================================
-- 3. r1326 log_founder_nps_record_response — add missing p_respondent_role
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_record_response(uuid, uuid, int, text, text);
DROP FUNCTION IF EXISTS public.log_founder_nps_record_response(uuid, uuid, int, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_nps_record_response(
  p_survey_id        uuid,
  p_org_id           uuid,
  p_score            int,
  p_feedback         text,
  p_respondent_name  text DEFAULT NULL,
  p_respondent_role  text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_score < 0 OR p_score > 10 THEN
    RAISE EXCEPTION 'score must be 0..10';
  END IF;

  INSERT INTO public.founder_nps_responses
    (survey_id, hospital_org_id, score, qualitative_feedback, respondent_name, respondent_role)
  VALUES (p_survey_id, p_org_id, p_score, p_feedback, p_respondent_name, p_respondent_role)
  ON CONFLICT (survey_id, hospital_org_id)
  DO UPDATE SET score = EXCLUDED.score,
                qualitative_feedback = EXCLUDED.qualitative_feedback,
                respondent_name = EXCLUDED.respondent_name,
                respondent_role = EXCLUDED.respondent_role,
                responded_at = now()
  RETURNING id INTO v_id;

  UPDATE public.founder_nps_surveys s
  SET response_count  = (SELECT count(*) FROM public.founder_nps_responses WHERE survey_id = s.id),
      promoter_count  = (SELECT count(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'promoter'),
      passive_count   = (SELECT count(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'passive'),
      detractor_count = (SELECT count(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'detractor'),
      status          = CASE WHEN s.status = 'draft' THEN 'collecting' ELSE s.status END
  WHERE s.id = p_survey_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_nps_record_response(uuid, uuid, int, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_nps_record_response(uuid, uuid, int, text, text, text) TO authenticated;

COMMIT;
