BEGIN;
DROP FUNCTION IF EXISTS public.founder_webhook_failures_recent();
CREATE OR REPLACE FUNCTION public.founder_webhook_failures_recent()
RETURNS TABLE (
  source         text,
  event_kind     text,
  ref_id         text,
  failure_reason text,
  received_at    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    'payouts'::text                                          AS source,
    p.event_kind                                              AS event_kind,
    p.razorpay_payout_id                                      AS ref_id,
    coalesce(p.failure_reason, p.apply_outcome, '(unknown)')  AS failure_reason,
    p.received_at                                             AS received_at
  FROM public.payouts_webhook_events p
  WHERE p.received_at >= now() - interval '7 days'
    AND (p.applied = false OR p.failure_reason IS NOT NULL)
  UNION ALL
  SELECT
    'razorpay'::text,
    r.event_type,
    coalesce(r.razorpay_payment_id, r.razorpay_order_id, r.razorpay_refund_id),
    coalesce(r.apply_error, r.apply_outcome, '(unknown)'),
    r.received_at
  FROM public.razorpay_webhook_events r
  WHERE r.received_at >= now() - interval '7 days'
    AND (r.applied = false OR r.apply_error IS NOT NULL)
  ORDER BY received_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_webhook_failures_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_webhook_failures_recent() TO authenticated;
COMMIT;
