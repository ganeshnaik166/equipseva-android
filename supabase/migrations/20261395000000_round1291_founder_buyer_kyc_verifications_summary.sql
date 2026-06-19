BEGIN;
DROP FUNCTION IF EXISTS public.founder_buyer_kyc_verifications_summary();
CREATE OR REPLACE FUNCTION public.founder_buyer_kyc_verifications_summary()
RETURNS TABLE (
  decisions_lifetime           bigint,
  approval_rate_pct            numeric,
  rejection_rate_pct           numeric,
  decisions_30d                bigint,
  approval_rate_30d_pct        numeric,
  median_decision_hours        numeric,
  p95_decision_hours           numeric,
  decisions_under_24h_30d_pct  numeric,
  manual_review_backlog        bigint,
  backlog_breach_48h           bigint,
  doc_type_gst_share_pct       numeric,
  doc_type_shop_reg_share_pct  numeric,
  doc_type_drug_license_share_pct numeric,
  doc_type_medical_id_share_pct   numeric,
  distinct_reviewers_30d       bigint,
  rejections_with_reason_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_dec_life    bigint;
  v_appr_life   bigint;
  v_rej_life    bigint;
  v_dec_30d     bigint;
  v_appr_30d    bigint;
  v_rej_total   bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT
    count(*) FILTER (WHERE status IN ('verified','rejected')),
    count(*) FILTER (WHERE status = 'verified'),
    count(*) FILTER (WHERE status = 'rejected')
  INTO v_dec_life, v_appr_life, v_rej_life
  FROM public.buyer_kyc_verifications;

  SELECT
    count(*) FILTER (WHERE status IN ('verified','rejected') AND reviewed_at >= now() - interval '30 days'),
    count(*) FILTER (WHERE status = 'verified'              AND reviewed_at >= now() - interval '30 days')
  INTO v_dec_30d, v_appr_30d
  FROM public.buyer_kyc_verifications;

  v_rej_total := v_rej_life;

  RETURN QUERY
  SELECT
    coalesce(v_dec_life, 0),
    CASE WHEN v_dec_life > 0 THEN round((v_appr_life::numeric * 100.0) / v_dec_life, 2) ELSE 0::numeric END,
    CASE WHEN v_dec_life > 0 THEN round((v_rej_life::numeric  * 100.0) / v_dec_life, 2) ELSE 0::numeric END,
    coalesce(v_dec_30d, 0),
    CASE WHEN v_dec_30d > 0 THEN round((v_appr_30d::numeric * 100.0) / v_dec_30d, 2) ELSE 0::numeric END,
    coalesce((
      SELECT round((percentile_cont(0.5) WITHIN GROUP (
                ORDER BY EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 3600.0
              ))::numeric, 2)
      FROM public.buyer_kyc_verifications
      WHERE reviewed_at IS NOT NULL
    ), 0)::numeric,
    coalesce((
      SELECT round((percentile_cont(0.95) WITHIN GROUP (
                ORDER BY EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 3600.0
              ))::numeric, 2)
      FROM public.buyer_kyc_verifications
      WHERE reviewed_at IS NOT NULL
    ), 0)::numeric,
    CASE WHEN v_dec_30d > 0 THEN
      coalesce((
        SELECT round((count(*) FILTER (
                  WHERE (reviewed_at - submitted_at) < interval '24 hours'
                )::numeric * 100.0) / v_dec_30d, 2)
        FROM public.buyer_kyc_verifications
        WHERE reviewed_at IS NOT NULL
          AND reviewed_at >= now() - interval '30 days'
      ), 0)::numeric
    ELSE 0::numeric END,
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications WHERE status = 'pending'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE status = 'pending' AND submitted_at < now() - interval '48 hours'), 0),
    CASE WHEN v_dec_life > 0 THEN
      coalesce((SELECT round((count(*) FILTER (WHERE doc_type = 'gst' AND status IN ('verified','rejected'))::numeric * 100.0) / v_dec_life, 2)
                FROM public.buyer_kyc_verifications), 0)::numeric
    ELSE 0::numeric END,
    CASE WHEN v_dec_life > 0 THEN
      coalesce((SELECT round((count(*) FILTER (WHERE doc_type = 'shop_registration' AND status IN ('verified','rejected'))::numeric * 100.0) / v_dec_life, 2)
                FROM public.buyer_kyc_verifications), 0)::numeric
    ELSE 0::numeric END,
    CASE WHEN v_dec_life > 0 THEN
      coalesce((SELECT round((count(*) FILTER (WHERE doc_type = 'drug_license' AND status IN ('verified','rejected'))::numeric * 100.0) / v_dec_life, 2)
                FROM public.buyer_kyc_verifications), 0)::numeric
    ELSE 0::numeric END,
    CASE WHEN v_dec_life > 0 THEN
      coalesce((SELECT round((count(*) FILTER (WHERE doc_type = 'medical_id' AND status IN ('verified','rejected'))::numeric * 100.0) / v_dec_life, 2)
                FROM public.buyer_kyc_verifications), 0)::numeric
    ELSE 0::numeric END,
    coalesce((SELECT count(DISTINCT reviewed_by)::bigint
              FROM public.buyer_kyc_verifications
              WHERE reviewed_at >= now() - interval '30 days' AND reviewed_by IS NOT NULL), 0),
    CASE WHEN v_rej_total > 0 THEN
      coalesce((SELECT round((count(*) FILTER (WHERE status = 'rejected' AND rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)::numeric * 100.0) / v_rej_total, 2)
                FROM public.buyer_kyc_verifications), 0)::numeric
    ELSE 0::numeric END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_buyer_kyc_verifications_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_buyer_kyc_verifications_summary() TO authenticated;
COMMIT;