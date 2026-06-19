BEGIN;
-- r1360 — Founder revenue recognition.
--
-- Three different numbers all called "revenue" — and a founder who can't
-- explain the gap between them on the spot will lose the room. This module
-- surfaces all three side-by-side so the answer is one click away:
--
--   1. ACCRUED revenue   = the revenue the business EARNED in a period
--      (active AMC contracts × monthly_fee_rupees). GAAP / Ind-AS view.
--   2. INVOICED revenue  = the revenue we BILLED in a period
--      (sum of gst_invoices issued this period). Tax-authority view.
--   3. CASH collected    = the rupees that actually HIT the bank
--      (sum of payments.amount_rupees status='captured'). Treasury view.
--
-- The deltas tell the story: accrued > invoiced means we're behind on
-- billing; invoiced > cash means receivables are stretching; accrued > cash
-- means we're funding customers' float with our own working capital.
--
-- Pure aggregator. No new tables. Reads:
--   public.amc_contracts   (recurring revenue accrual base)
--   public.gst_invoices    (billed/issued ledger; status='issued' counted)
--   public.payments        (cash captured at gateway, status='captured')

-- ============================================================================
-- RPC 1: founder_revenue_recognition_summary — 14 KPI snapshot
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_revenue_recognition_summary();

CREATE OR REPLACE FUNCTION public.founder_revenue_recognition_summary()
RETURNS TABLE (
  this_month_accrued_revenue_rupees numeric,
  this_month_invoiced_rupees        numeric,
  this_month_cash_collected_rupees  numeric,
  last_month_accrued_rupees         numeric,
  last_month_invoiced_rupees        numeric,
  last_month_cash_collected_rupees  numeric,
  ytd_accrued_rupees                numeric,
  ytd_invoiced_rupees               numeric,
  ytd_cash_collected_rupees         numeric,
  mom_accrued_delta_pct             numeric,
  mom_cash_delta_pct                numeric,
  deferred_revenue_estimate_rupees  numeric,
  bad_debt_estimate_rupees          numeric,
  generated_at                      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now            timestamptz := now();
  v_tm_start       date := date_trunc('month', v_now AT TIME ZONE 'Asia/Kolkata')::date;
  v_tm_end         date := (v_tm_start + interval '1 month')::date;
  v_lm_start       date := (v_tm_start - interval '1 month')::date;
  v_lm_end         date := v_tm_start;
  v_ytd_start      date := date_trunc('year', v_now AT TIME ZONE 'Asia/Kolkata')::date;
  v_bad_debt_cut   timestamptz := v_now - interval '90 days';

  v_tm_accrued     numeric := 0;
  v_tm_invoiced    numeric := 0;
  v_tm_cash        numeric := 0;
  v_lm_accrued     numeric := 0;
  v_lm_invoiced    numeric := 0;
  v_lm_cash        numeric := 0;
  v_ytd_accrued    numeric := 0;
  v_ytd_invoiced   numeric := 0;
  v_ytd_cash       numeric := 0;
  v_mom_accr_pct   numeric := 0;
  v_mom_cash_pct   numeric := 0;
  v_total_invoiced numeric := 0;
  v_total_cash     numeric := 0;
  v_deferred       numeric := 0;
  v_bad_debt       numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- This-month ACCRUED: monthly_fee for any contract whose active span
  -- overlaps the current calendar month (start_date <= month_end AND
  -- (end_date IS NULL OR end_date >= month_start) AND status='active').
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_tm_accrued
    FROM public.amc_contracts
   WHERE status = 'active'
     AND start_date < v_tm_end
     AND (end_date IS NULL OR end_date >= v_tm_start);

  -- Last-month ACCRUED: same logic, prior month window.
  SELECT COALESCE(SUM(monthly_fee_rupees), 0)
    INTO v_lm_accrued
    FROM public.amc_contracts
   WHERE start_date < v_lm_end
     AND (end_date IS NULL OR end_date >= v_lm_start)
     AND (deactivated_at IS NULL OR deactivated_at >= v_lm_start);

  -- YTD ACCRUED: approximate as monthly_fee × months_elapsed_in_year for
  -- every contract whose span intersected the YTD window.
  SELECT COALESCE(
           SUM(
             monthly_fee_rupees *
             GREATEST(
               1,
               EXTRACT(MONTH FROM age(
                 LEAST(COALESCE(end_date, v_now::date), v_now::date),
                 GREATEST(start_date, v_ytd_start)
               ))::int + 1
             )
           ),
           0
         )
    INTO v_ytd_accrued
    FROM public.amc_contracts
   WHERE start_date < v_now::date
     AND (end_date IS NULL OR end_date >= v_ytd_start);

  -- INVOICED: sum taxable + cgst + sgst + igst issued in window, status<>'cancelled'.
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_tm_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_tm_start
     AND issued_at <  v_tm_end;

  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_lm_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_lm_start
     AND issued_at <  v_lm_end;

  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_ytd_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled'
     AND issued_at >= v_ytd_start;

  -- CASH collected: payments status='captured' in window.
  SELECT COALESCE(SUM(amount_rupees), 0)
    INTO v_tm_cash
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= v_tm_start
     AND created_at <  v_tm_end;

  SELECT COALESCE(SUM(amount_rupees), 0)
    INTO v_lm_cash
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= v_lm_start
     AND created_at <  v_lm_end;

  SELECT COALESCE(SUM(amount_rupees), 0)
    INTO v_ytd_cash
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= v_ytd_start;

  -- MoM deltas (percent).
  IF v_lm_accrued > 0 THEN
    v_mom_accr_pct := ROUND(((v_tm_accrued - v_lm_accrued) / v_lm_accrued) * 100.0, 2);
  END IF;
  IF v_lm_cash > 0 THEN
    v_mom_cash_pct := ROUND(((v_tm_cash - v_lm_cash) / v_lm_cash) * 100.0, 2);
  END IF;

  -- Deferred revenue estimate: total invoiced - total cash (all-time).
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_total_invoiced
    FROM public.gst_invoices
   WHERE status <> 'cancelled';

  SELECT COALESCE(SUM(amount_rupees), 0)
    INTO v_total_cash
    FROM public.payments
   WHERE status = 'captured';

  v_deferred := GREATEST(0, v_total_invoiced - v_total_cash);

  -- Bad-debt estimate: invoices issued > 90 days ago that have no matching
  -- captured payment (very rough — no FK between gst_invoices and payments
  -- on every path, so we proxy via the deferred bucket aged > 90d).
  SELECT COALESCE(SUM(taxable_amount_rupees + cgst_rupees + sgst_rupees + igst_rupees), 0)
    INTO v_bad_debt
    FROM public.gst_invoices
   WHERE status = 'issued'
     AND issued_at < v_bad_debt_cut;

  -- Bad debt can't exceed the deferred pool.
  v_bad_debt := LEAST(v_bad_debt, v_deferred);

  RETURN QUERY SELECT
    v_tm_accrued,
    v_tm_invoiced,
    v_tm_cash,
    v_lm_accrued,
    v_lm_invoiced,
    v_lm_cash,
    v_ytd_accrued,
    v_ytd_invoiced,
    v_ytd_cash,
    v_mom_accr_pct,
    v_mom_cash_pct,
    v_deferred,
    v_bad_debt,
    v_now;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revenue_recognition_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_revenue_recognition_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_revenue_recognition_history — monthly trend
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_revenue_recognition_history(int);

CREATE OR REPLACE FUNCTION public.founder_revenue_recognition_history(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start          date,
  accrued_rupees       numeric,
  invoiced_rupees      numeric,
  cash_collected_rupees numeric,
  gst_remitted_rupees  numeric,
  net_recognized_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := GREATEST(1, LEAST(36, COALESCE(p_months, 12)));
  v_anchor date := date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT (v_anchor - (gs || ' months')::interval)::date AS m_start
      FROM generate_series(0, v_months - 1) AS gs
  ),
  accrued AS (
    SELECT m.m_start,
           COALESCE(SUM(c.monthly_fee_rupees), 0)::numeric AS accr
      FROM months m
      LEFT JOIN public.amc_contracts c
        ON c.start_date < (m.m_start + interval '1 month')::date
       AND (c.end_date IS NULL OR c.end_date >= m.m_start)
     GROUP BY m.m_start
  ),
  invoiced AS (
    SELECT date_trunc('month', g.issued_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(g.taxable_amount_rupees + g.cgst_rupees + g.sgst_rupees + g.igst_rupees)::numeric AS inv,
           SUM(g.cgst_rupees + g.sgst_rupees + g.igst_rupees)::numeric AS tax
      FROM public.gst_invoices g
     WHERE g.status <> 'cancelled'
       AND g.issued_at >= (v_anchor - ((v_months) || ' months')::interval)
     GROUP BY 1
  ),
  cash AS (
    SELECT date_trunc('month', p.created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(p.amount_rupees)::numeric AS csh
      FROM public.payments p
     WHERE p.status = 'captured'
       AND p.created_at >= (v_anchor - ((v_months) || ' months')::interval)
     GROUP BY 1
  )
  SELECT m.m_start,
         COALESCE(a.accr, 0)::numeric,
         COALESCE(i.inv,  0)::numeric,
         COALESCE(c.csh,  0)::numeric,
         COALESCE(i.tax,  0)::numeric,
         (COALESCE(i.inv, 0) - COALESCE(i.tax, 0))::numeric
    FROM months m
    LEFT JOIN accrued  a ON a.m_start = m.m_start
    LEFT JOIN invoiced i ON i.m_start = m.m_start
    LEFT JOIN cash     c ON c.m_start = m.m_start
   ORDER BY m.m_start DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revenue_recognition_history(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_revenue_recognition_history(int) TO authenticated;

COMMENT ON FUNCTION public.founder_revenue_recognition_summary() IS
  'Round 1360: 14-KPI snapshot reconciling ACCRUED (amc_contracts) vs INVOICED (gst_invoices) vs CASH (payments). Three definitions of revenue side-by-side. MoM deltas + deferred + bad-debt estimate.';

COMMENT ON FUNCTION public.founder_revenue_recognition_history(int) IS
  'Round 1360: Monthly trend (default 12 months) of accrued, invoiced, cash, GST remitted, and net recognized revenue. Anchors on IST month boundaries.';

COMMIT;