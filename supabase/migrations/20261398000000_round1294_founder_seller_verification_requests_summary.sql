BEGIN;
-- r1294 founder_seller_verification_requests_summary
-- Marketplace seller KYC submission pipeline (organizations.verification_status path).
-- Source: public.seller_verification_requests (created 20260425090000).

BEGIN;

DROP FUNCTION IF EXISTS public.founder_seller_verification_requests_summary();

CREATE OR REPLACE FUNCTION public.founder_seller_verification_requests_summary()
RETURNS TABLE (
  pending_count integer,
  approved_count integer,
  rejected_count integer,
  total_count integer,
  oldest_pending_age_hours numeric,
  pending_with_gst_cert integer,
  pending_with_expiry_date integer,
  approved_30d integer,
  rejected_30d integer,
  submitted_30d integer,
  median_review_hours_30d numeric,
  expired_licence_pending integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.seller_verification_requests
  ),
  pend AS (
    SELECT
      COUNT(*)::int AS pending_count,
      EXTRACT(EPOCH FROM (now() - MIN(submitted_at))) / 3600.0 AS oldest_age_hours,
      COUNT(*) FILTER (WHERE gst_certificate_url IS NOT NULL AND gst_certificate_url <> '')::int AS pending_with_gst_cert,
      COUNT(*) FILTER (WHERE licence_expires_at IS NOT NULL)::int AS pending_with_expiry_date,
      COUNT(*) FILTER (WHERE licence_expires_at IS NOT NULL AND licence_expires_at < CURRENT_DATE)::int AS expired_licence_pending
    FROM base
    WHERE status = 'pending'
  ),
  totals AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'approved')::int AS approved_count,
      COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected_count,
      COUNT(*)::int AS total_count
    FROM base
  ),
  windowed AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'approved' AND reviewed_at >= now() - interval '30 days')::int AS approved_30d,
      COUNT(*) FILTER (WHERE status = 'rejected' AND reviewed_at >= now() - interval '30 days')::int AS rejected_30d,
      COUNT(*) FILTER (WHERE submitted_at >= now() - interval '30 days')::int AS submitted_30d
    FROM base
  ),
  latency AS (
    SELECT
      percentile_cont(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (reviewed_at - submitted_at)) / 3600.0
      )::numeric AS median_review_hours_30d
    FROM base
    WHERE reviewed_at IS NOT NULL
      AND reviewed_at >= now() - interval '30 days'
      AND status IN ('approved','rejected')
  )
  SELECT
    COALESCE(pend.pending_count, 0),
    COALESCE(totals.approved_count, 0),
    COALESCE(totals.rejected_count, 0),
    COALESCE(totals.total_count, 0),
    ROUND(COALESCE(pend.oldest_age_hours, 0)::numeric, 2),
    COALESCE(pend.pending_with_gst_cert, 0),
    COALESCE(pend.pending_with_expiry_date, 0),
    COALESCE(windowed.approved_30d, 0),
    COALESCE(windowed.rejected_30d, 0),
    COALESCE(windowed.submitted_30d, 0),
    ROUND(COALESCE(latency.median_review_hours_30d, 0)::numeric, 2),
    COALESCE(pend.expired_licence_pending, 0)
  FROM pend, totals, windowed, latency;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_seller_verification_requests_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_seller_verification_requests_summary() TO authenticated;

COMMIT;
