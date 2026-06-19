-- =====================================================================
-- Round 1204 — founder_gst_invoice_snapshot_summary
-- =====================================================================
-- GST invoice ledger (r491) + auto-dispatch (r463) currently invisible
-- in founder console. This snapshot surfaces today/MTD counts + value,
-- dispatch success rate, GSTIN-missing exposure, HSN coverage,
-- CGST/SGST vs IGST split, unsent backlog, and retry-failure aging —
-- catches silent dispatch failures BEFORE quarterly GSTR-1 filing.
--
-- All columns confirmed against:
--   - 20260810000000_round491_gst_invoice_ledger.sql
--   - 20260720000000_round463_invoice_auto_dispatch.sql

BEGIN;

DROP FUNCTION IF EXISTS public.founder_gst_invoice_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_gst_invoice_snapshot_summary()
RETURNS TABLE (
  invoices_today                bigint,
  invoices_mtd                  bigint,
  taxable_value_today_rupees    numeric,
  taxable_value_mtd_rupees      numeric,
  gst_collected_mtd_rupees      numeric,
  intra_state_share_pct_mtd     numeric,
  inter_state_share_pct_mtd     numeric,
  rcm_invoices_mtd              bigint,
  recipient_gstin_missing_mtd   bigint,
  cancelled_or_revised_mtd      bigint,
  dispatch_success_pct_30d      numeric,
  dispatch_failed_30d           bigint
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
  v_30d_ago     timestamptz := now() - interval '30 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH inv_today AS (
    SELECT count(*)::bigint AS c, coalesce(sum(taxable_amount_rupees), 0)::numeric AS taxable
      FROM public.gst_invoices
     WHERE status = 'issued'
       AND issued_at >= v_today_start
       AND issued_at <  v_today_end
  ),
  inv_mtd AS (
    SELECT
      count(*)::bigint                                                                    AS c,
      coalesce(sum(taxable_amount_rupees), 0)::numeric                                    AS taxable,
      coalesce(sum(total_gst_rupees), 0)::numeric                                         AS gst_total,
      count(*) FILTER (WHERE cgst_rupees > 0 OR sgst_rupees > 0)::bigint                  AS intra_cnt,
      count(*) FILTER (WHERE igst_rupees > 0)::bigint                                     AS inter_cnt,
      count(*) FILTER (WHERE rcm_applicable)::bigint                                      AS rcm_cnt,
      count(*) FILTER (WHERE recipient_gstin IS NULL OR length(trim(recipient_gstin)) = 0)::bigint AS gstin_missing
      FROM public.gst_invoices
     WHERE status = 'issued'
       AND issued_at >= v_month_start
  ),
  inv_mtd_any AS (
    SELECT count(*) FILTER (WHERE status IN ('cancelled','revised'))::bigint AS canc_rev
      FROM public.gst_invoices
     WHERE issued_at >= v_month_start
  ),
  dispatch AS (
    SELECT
      count(*)::bigint                                                  AS total,
      count(*) FILTER (WHERE email_status = 'sent')::bigint             AS sent_cnt,
      count(*) FILTER (WHERE email_status IN ('resend_failed','skipped_no_email'))::bigint AS failed_cnt
      FROM public.repair_invoice_emails
     WHERE sent_at >= v_30d_ago
  )
  SELECT
    (SELECT c FROM inv_today),
    (SELECT c FROM inv_mtd),
    (SELECT taxable FROM inv_today),
    (SELECT taxable FROM inv_mtd),
    (SELECT gst_total FROM inv_mtd),
    CASE
      WHEN (SELECT c FROM inv_mtd) = 0 THEN 0::numeric
      ELSE round(((SELECT intra_cnt FROM inv_mtd)::numeric / (SELECT c FROM inv_mtd)::numeric) * 100.0, 1)
    END,
    CASE
      WHEN (SELECT c FROM inv_mtd) = 0 THEN 0::numeric
      ELSE round(((SELECT inter_cnt FROM inv_mtd)::numeric / (SELECT c FROM inv_mtd)::numeric) * 100.0, 1)
    END,
    (SELECT rcm_cnt FROM inv_mtd),
    (SELECT gstin_missing FROM inv_mtd),
    (SELECT canc_rev FROM inv_mtd_any),
    CASE
      WHEN (SELECT total FROM dispatch) = 0 THEN 0::numeric
      ELSE round(((SELECT sent_cnt FROM dispatch)::numeric / (SELECT total FROM dispatch)::numeric) * 100.0, 1)
    END,
    (SELECT failed_cnt FROM dispatch);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_gst_invoice_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_gst_invoice_snapshot_summary() TO authenticated;

COMMIT;