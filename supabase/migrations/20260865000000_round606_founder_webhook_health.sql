-- =====================================================================
-- Round 606 — Founder webhook health roll-up
-- =====================================================================
--
-- Two webhook sources (razorpay_webhook_events + payouts_webhook_
-- events) record every inbound delivery + the post-apply outcome.
-- Today we have to query each table separately to know "did anything
-- fail in the last hour?" r606 unifies the two into a single roll-up
-- the dashboard can read.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_webhook_health();

CREATE OR REPLACE FUNCTION public.founder_webhook_health()
RETURNS TABLE (
  source             text,
  events_last_hour   bigint,
  events_last_24h    bigint,
  failed_last_hour   bigint,
  failed_last_24h    bigint,
  last_event_at      timestamptz,
  success_rate_24h   numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hour timestamptz := now() - interval '1 hour';
  v_day  timestamptz := now() - interval '24 hours';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  -- razorpay inbound
  SELECT
    'razorpay'::text                                           AS source,
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_hour)                              AS events_last_hour,
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day)                               AS events_last_24h,
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_hour
        AND apply_outcome IN ('no_matching_order','signature_failed','duplicate_skipped','unknown_event'))
                                                                AS failed_last_hour,
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day
        AND apply_outcome IN ('no_matching_order','signature_failed','duplicate_skipped','unknown_event'))
                                                                AS failed_last_24h,
    (SELECT max(received_at)
       FROM public.razorpay_webhook_events)                     AS last_event_at,
    CASE
      WHEN (SELECT count(*) FROM public.razorpay_webhook_events WHERE received_at >= v_day) = 0
        THEN NULL
      ELSE round(
        100.0 - (
          (SELECT count(*) FROM public.razorpay_webhook_events
            WHERE received_at >= v_day
              AND apply_outcome IN ('no_matching_order','signature_failed','duplicate_skipped','unknown_event'))::numeric
          / (SELECT count(*) FROM public.razorpay_webhook_events WHERE received_at >= v_day)::numeric
          * 100.0
        ),
        2
      )
    END                                                         AS success_rate_24h

  UNION ALL

  -- payouts inbound
  SELECT
    'payouts'::text,
    (SELECT count(*)::bigint FROM public.payouts_webhook_events WHERE received_at >= v_hour),
    (SELECT count(*)::bigint FROM public.payouts_webhook_events WHERE received_at >= v_day),
    (SELECT count(*)::bigint
       FROM public.payouts_webhook_events
      WHERE received_at >= v_hour
        AND apply_outcome IN ('no_matching_payout','unknown_event_kind','signature_failed','duplicate_skipped')),
    (SELECT count(*)::bigint
       FROM public.payouts_webhook_events
      WHERE received_at >= v_day
        AND apply_outcome IN ('no_matching_payout','unknown_event_kind','signature_failed','duplicate_skipped')),
    (SELECT max(received_at) FROM public.payouts_webhook_events),
    CASE
      WHEN (SELECT count(*) FROM public.payouts_webhook_events WHERE received_at >= v_day) = 0
        THEN NULL
      ELSE round(
        100.0 - (
          (SELECT count(*) FROM public.payouts_webhook_events
            WHERE received_at >= v_day
              AND apply_outcome IN ('no_matching_payout','unknown_event_kind','signature_failed','duplicate_skipped'))::numeric
          / (SELECT count(*) FROM public.payouts_webhook_events WHERE received_at >= v_day)::numeric
          * 100.0
        ),
        2
      )
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_webhook_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_webhook_health() TO authenticated;

COMMIT;
