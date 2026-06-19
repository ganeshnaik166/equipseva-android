BEGIN;
DROP FUNCTION IF EXISTS public.founder_buyer_kyc_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_buyer_kyc_pipeline_summary()
RETURNS TABLE (
  requests_total            bigint,
  status_pending            bigint,
  status_verified           bigint,
  status_rejected           bigint,
  pending_0_7d              bigint,
  pending_7_30d             bigint,
  pending_over_30d          bigint,
  oldest_pending_days       integer,
  avg_pending_age_days      numeric,
  avg_review_days_30d       numeric,
  submitted_today           bigint,
  reviewed_today            bigint,
  doc_type_gst_pending      bigint,
  checkout_gated_profiles   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications WHERE status = 'pending'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications WHERE status = 'verified'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications WHERE status = 'rejected'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE status = 'pending' AND submitted_at >= now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE status = 'pending'
                AND submitted_at <  now() - interval '7 days'
                AND submitted_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE status = 'pending' AND submitted_at < now() - interval '30 days'), 0),
    coalesce((SELECT EXTRACT(DAY FROM (now() - min(submitted_at)))::integer
              FROM public.buyer_kyc_verifications WHERE status = 'pending'), 0),
    coalesce((SELECT round(avg(EXTRACT(EPOCH FROM (now() - submitted_at)) / 86400)::numeric, 2)
              FROM public.buyer_kyc_verifications WHERE status = 'pending'), 0)::numeric,
    coalesce((SELECT round(avg(EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 86400)::numeric, 2)
              FROM public.buyer_kyc_verifications
              WHERE reviewed_at IS NOT NULL
                AND reviewed_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE submitted_at >= v_today_start AND submitted_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE reviewed_at IS NOT NULL
                AND reviewed_at >= v_today_start AND reviewed_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.buyer_kyc_verifications
              WHERE status = 'pending' AND doc_type = 'gst'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles
              WHERE buyer_kyc_status IN ('unsubmitted','pending','rejected')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_buyer_kyc_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_buyer_kyc_pipeline_summary() TO authenticated;
COMMIT;