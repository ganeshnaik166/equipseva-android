-- =====================================================================
-- Round 1222 — founder_email_delivery_health_summary
-- =====================================================================
-- Email channel was a blind spot: notifications-* routes cover in-app/FCM
-- push, but GST invoice auto-dispatch (round 463) and the founder daily
-- digest BOTH ride email (Resend). A silent bounce wave = silent revenue
-- and compliance leak — hospitals never get their tax invoice, founder
-- never sees the digest, GSTR-1 filing window closes.
--
-- This snapshot reads repair_invoice_emails (the only outbound email log
-- in the system) and surfaces 12 KPIs: send volume across 4 windows,
-- failure-mode breakdown (resend_failed vs skipped_no_email vs disabled),
-- delivery success rate, revenue-at-risk on failed sends, recipient
-- domain breadth, signed-URL expiry rot, and staleness since last send.
--
-- All columns confirmed against:
--   20260720000000_round463_invoice_auto_dispatch.sql
--     repair_invoice_emails (job_id, invoice_number, invoice_date,
--       hospital_email, hospital_name, gross_rupees, gst_total,
--       signed_url, url_expires_at, email_status, email_error,
--       sent_at, created_at)
--     email_status CHECK IN ('sent','skipped_no_email','resend_failed','disabled')
--
-- IST day boundaries match the rest of the founder console.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_email_delivery_health_summary();

CREATE OR REPLACE FUNCTION public.founder_email_delivery_health_summary()
RETURNS TABLE (
  emails_sent_today              bigint,
  emails_sent_mtd                bigint,
  emails_sent_7d                 bigint,
  emails_sent_30d                bigint,
  resend_failed_30d              bigint,
  skipped_no_email_30d           bigint,
  disabled_30d                   bigint,
  delivery_success_pct_30d       numeric,
  revenue_in_failed_30d_rupees   numeric,
  unique_recipient_domains_30d   bigint,
  expired_signed_urls_30d        bigint,
  hours_since_last_sent          numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_month_start timestamptz := date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata'))::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_7d_ago      timestamptz := now() - interval '7 days';
  v_30d_ago     timestamptz := now() - interval '30 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH today_bucket AS (
    SELECT count(*) FILTER (WHERE email_status = 'sent')::bigint AS c
      FROM public.repair_invoice_emails
     WHERE sent_at >= v_today_start
       AND sent_at <  v_today_end
  ),
  mtd_bucket AS (
    SELECT count(*) FILTER (WHERE email_status = 'sent')::bigint AS c
      FROM public.repair_invoice_emails
     WHERE sent_at >= v_month_start
  ),
  d7_bucket AS (
    SELECT count(*) FILTER (WHERE email_status = 'sent')::bigint AS c
      FROM public.repair_invoice_emails
     WHERE sent_at >= v_7d_ago
  ),
  d30_bucket AS (
    SELECT
      count(*)::bigint                                                              AS total,
      count(*) FILTER (WHERE email_status = 'sent')::bigint                         AS sent_cnt,
      count(*) FILTER (WHERE email_status = 'resend_failed')::bigint                AS failed_cnt,
      count(*) FILTER (WHERE email_status = 'skipped_no_email')::bigint             AS skipped_cnt,
      count(*) FILTER (WHERE email_status = 'disabled')::bigint                     AS disabled_cnt,
      coalesce(
        sum(gross_rupees) FILTER (
          WHERE email_status IN ('resend_failed','skipped_no_email')
        ),
        0
      )::numeric                                                                    AS rev_at_risk,
      count(DISTINCT lower(split_part(hospital_email, '@', 2)))
        FILTER (
          WHERE hospital_email IS NOT NULL
            AND length(trim(hospital_email)) > 0
            AND position('@' IN hospital_email) > 0
        )::bigint                                                                   AS domain_cnt,
      count(*) FILTER (
        WHERE email_status = 'sent'
          AND url_expires_at IS NOT NULL
          AND url_expires_at < now()
      )::bigint                                                                     AS expired_cnt
      FROM public.repair_invoice_emails
     WHERE sent_at >= v_30d_ago
  ),
  last_sent AS (
    SELECT max(sent_at) AS m
      FROM public.repair_invoice_emails
     WHERE email_status = 'sent'
  )
  SELECT
    (SELECT c FROM today_bucket),
    (SELECT c FROM mtd_bucket),
    (SELECT c FROM d7_bucket),
    (SELECT sent_cnt FROM d30_bucket),
    (SELECT failed_cnt FROM d30_bucket),
    (SELECT skipped_cnt FROM d30_bucket),
    (SELECT disabled_cnt FROM d30_bucket),
    CASE
      WHEN (SELECT total FROM d30_bucket) = 0 THEN 0::numeric
      ELSE round(
        ((SELECT sent_cnt FROM d30_bucket)::numeric
          / (SELECT total FROM d30_bucket)::numeric) * 100.0,
        1
      )
    END,
    (SELECT rev_at_risk FROM d30_bucket),
    (SELECT domain_cnt FROM d30_bucket),
    (SELECT expired_cnt FROM d30_bucket),
    CASE
      WHEN (SELECT m FROM last_sent) IS NULL THEN 0::numeric
      ELSE round(EXTRACT(EPOCH FROM (now() - (SELECT m FROM last_sent))) / 3600.0, 1)
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_email_delivery_health_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_email_delivery_health_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_email_delivery_health_summary() IS
  'Round 1222 — email channel health snapshot. Reads repair_invoice_emails (round 463 log) to surface send volume, failure-mode breakdown, revenue-at-risk on bounces, recipient-domain breadth, signed-URL expiry rot, and staleness since last send. Closes the email blind spot left by notifications-* (push/FCM) routes.';

COMMIT;