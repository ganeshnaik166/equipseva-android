BEGIN;
DROP FUNCTION IF EXISTS public.founder_webhook_success_rate();
CREATE OR REPLACE FUNCTION public.founder_webhook_success_rate()
RETURNS TABLE (
  source        text,
  window_label  text,
  events        bigint,
  applied       bigint,
  success_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('7d'::text, 1, now() - interval '7 days'),
      ('30d'::text, 2, now() - interval '30 days')
  )
  SELECT 'razorpay'::text, w.label,
    coalesce((SELECT count(*)::bigint FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied)
           / (SELECT count(*)::numeric FROM public.razorpay_webhook_events r WHERE r.received_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  UNION ALL
  SELECT 'payouts'::text, w.label,
    coalesce((SELECT count(*)::bigint FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(*)::numeric FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff AND r.applied)
           / (SELECT count(*)::numeric FROM public.payouts_webhook_events r WHERE r.received_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY source, ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_webhook_success_rate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_webhook_success_rate() TO authenticated;
COMMIT;
