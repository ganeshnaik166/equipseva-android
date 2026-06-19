BEGIN;

DROP FUNCTION IF EXISTS public.founder_refund_authorization_queue_summary();

CREATE OR REPLACE FUNCTION public.founder_refund_authorization_queue_summary()
RETURNS TABLE (
  pending_count                bigint,
  pending_value_inr            numeric,
  oldest_pending_age_hours     numeric,
  expiring_24h_count           bigint,
  approved_30d                 bigint,
  rejected_30d                 bigint,
  expired_30d                  bigint,
  executed_30d                 bigint,
  auto_approved_30d            bigint,
  manual_approved_30d          bigint,
  auto_share_pct_30d           numeric,
  median_approval_hours_30d    numeric
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
  WITH pending AS (
    SELECT
      count(*)::bigint                                                   AS pcount,
      coalesce(sum(amount_rupees), 0)::numeric                           AS pvalue,
      coalesce(
        extract(epoch FROM (now() - min(created_at))) / 3600.0,
        0
      )::numeric                                                         AS oldest_h,
      count(*) FILTER (WHERE expires_at <= now() + interval '24 hours')::bigint AS exp24
    FROM public.refund_authorization_requests
    WHERE status = 'pending'
      AND expires_at > now()
  ),
  recent AS (
    SELECT
      count(*) FILTER (WHERE status = 'approved')::bigint  AS appr,
      count(*) FILTER (WHERE status = 'rejected')::bigint  AS rej,
      count(*) FILTER (WHERE status = 'expired')::bigint   AS exp,
      count(*) FILTER (WHERE status = 'executed')::bigint  AS exec_c,
      count(*) FILTER (
        WHERE approver_reason = 'auto-approved (below threshold)'
      )::bigint                                            AS auto_c,
      count(*) FILTER (
        WHERE status IN ('approved','executed')
          AND approver_reason IS DISTINCT FROM 'auto-approved (below threshold)'
      )::bigint                                            AS manual_c
    FROM public.refund_authorization_requests
    WHERE created_at >= now() - interval '30 days'
  ),
  decided AS (
    SELECT count(*)::bigint AS total_decided
    FROM public.refund_authorization_requests
    WHERE created_at >= now() - interval '30 days'
      AND status IN ('approved','rejected','executed')
  ),
  approval_latency AS (
    SELECT
      percentile_cont(0.5) WITHIN GROUP (
        ORDER BY extract(epoch FROM (approved_at - created_at)) / 3600.0
      ) AS median_h
    FROM public.refund_authorization_requests
    WHERE created_at >= now() - interval '30 days'
      AND status IN ('approved','executed')
      AND approved_at IS NOT NULL
      AND approver_reason IS DISTINCT FROM 'auto-approved (below threshold)'
  )
  SELECT
    pending.pcount,
    pending.pvalue,
    round(pending.oldest_h, 2),
    pending.exp24,
    recent.appr,
    recent.rej,
    recent.exp,
    recent.exec_c,
    recent.auto_c,
    recent.manual_c,
    CASE
      WHEN decided.total_decided = 0 THEN 0::numeric
      ELSE round((recent.auto_c::numeric / decided.total_decided::numeric) * 100.0, 1)
    END,
    coalesce(round(approval_latency.median_h::numeric, 2), 0::numeric)
  FROM pending, recent, decided, approval_latency;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_refund_authorization_queue_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_refund_authorization_queue_summary() TO authenticated;

COMMIT;
