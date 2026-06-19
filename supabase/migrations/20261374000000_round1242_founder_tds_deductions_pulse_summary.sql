BEGIN;
-- =====================================================================
-- Round 1242 — /tds-deductions-pulse-summary (§194-O withholding ledger)
-- =====================================================================
-- Founder-critical pulse on tds_deductions table (round 490 ledger).
-- §194-O = 1% TDS on engineer payouts once cumulative FY gross > 5L.
-- Distinct from /reconciliation-tax (settlement-tax recon) — this is
-- the WITHHOLDING accrual side: what we owe govt, by when, on which
-- deductees. Maps to quarterly Form 26Q filing (due last day of
-- month following quarter-end: Jul 31, Oct 31, Jan 31, May 31).
--
-- Schema verified against migration 20260809000000_round490:
--   tds_deductions (engineer_user_id, fiscal_year, fy_quarter,
--     gross_rupees, tds_rupees, net_payable_rupees, deducted,
--     cumulative_fy_gross_rupees, threshold_rupees,
--     deposited_to_govt_at, deposit_challan_no,
--     certificate_issued_at, certificate_url, created_at)
--   indian_fiscal_year_for(timestamptz) helper exists.
--
-- 12 KPIs:
--   1. current_fy                       — "2026-27"
--   2. current_fy_quarter               — "Q1".."Q4"
--   3. tds_accrued_mtd_inr              — sum(tds_rupees) MTD
--   4. tds_accrued_current_fy_inr       — sum(tds_rupees) FY-to-date
--   5. tds_accrued_current_quarter_inr  — sum(tds_rupees) this quarter
--   6. undeposited_tds_inr              — deducted=true AND deposited_to_govt_at IS NULL
--   7. undeposited_deduction_count      — row count of (6)
--   8. oldest_undeposited_age_days      — max age in days of an undeposited row
--   9. deductee_count_current_fy        — distinct engineer_user_id this FY with tds>0
--  10. below_threshold_engineers_fy     — distinct engineers with rows but tds_rupees=0 (sub-5L)
--  11. certificates_pending_count       — deducted=true AND certificate_issued_at IS NULL
--  12. previous_quarter_undeposited_inr — prior-quarter undeposited (filing-deadline trigger)
--
-- is_founder() gate inside body. No service_role grant.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_tds_deductions_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_tds_deductions_pulse_summary()
RETURNS TABLE(
  current_fy                       text,
  current_fy_quarter               text,
  tds_accrued_mtd_inr              numeric,
  tds_accrued_current_fy_inr       numeric,
  tds_accrued_current_quarter_inr  numeric,
  undeposited_tds_inr              numeric,
  undeposited_deduction_count      bigint,
  oldest_undeposited_age_days      integer,
  deductee_count_current_fy        bigint,
  below_threshold_engineers_fy     bigint,
  certificates_pending_count       bigint,
  previous_quarter_undeposited_inr numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fy       text;
  v_q        text;
  v_prev_fy  text;
  v_prev_q   text;
  v_ist_now  timestamptz := now();
  v_month_start_ist timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Resolve current FY + quarter (India)
  SELECT fiscal_year, fy_quarter
    INTO v_fy, v_q
    FROM public.indian_fiscal_year_for(v_ist_now);

  -- Previous quarter for filing-deadline KPI
  IF v_q = 'Q1' THEN
    v_prev_q := 'Q4';
    -- prev FY = (v_fy split before '-' ) − 1, suffix two digits of current start
    v_prev_fy := (split_part(v_fy, '-', 1)::int - 1)::text
                 || '-'
                 || lpad((split_part(v_fy, '-', 1)::int % 100)::text, 2, '0');
  ELSE
    v_prev_fy := v_fy;
    v_prev_q  := CASE v_q WHEN 'Q2' THEN 'Q1' WHEN 'Q3' THEN 'Q2' WHEN 'Q4' THEN 'Q3' END;
  END IF;

  -- IST month start
  v_month_start_ist := date_trunc('month', v_ist_now AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.tds_deductions
  ),
  mtd AS (
    SELECT coalesce(sum(tds_rupees), 0)::numeric AS v
      FROM base
     WHERE created_at >= v_month_start_ist
  ),
  fy_total AS (
    SELECT coalesce(sum(tds_rupees), 0)::numeric AS v,
           count(DISTINCT engineer_user_id) FILTER (WHERE tds_rupees > 0)::bigint AS deductees,
           count(DISTINCT engineer_user_id) FILTER (
             WHERE deducted = false AND tds_rupees = 0
           )::bigint AS below_thresh
      FROM base
     WHERE fiscal_year = v_fy
  ),
  q_total AS (
    SELECT coalesce(sum(tds_rupees), 0)::numeric AS v
      FROM base
     WHERE fiscal_year = v_fy AND fy_quarter = v_q
  ),
  undep AS (
    SELECT coalesce(sum(tds_rupees), 0)::numeric AS v,
           count(*)::bigint AS n,
           coalesce(
             EXTRACT(DAY FROM (v_ist_now - min(created_at)))::int,
             0
           ) AS oldest_days
      FROM base
     WHERE deducted = true
       AND deposited_to_govt_at IS NULL
       AND tds_rupees > 0
  ),
  certs AS (
    SELECT count(*)::bigint AS n
      FROM base
     WHERE deducted = true
       AND certificate_issued_at IS NULL
  ),
  prev_q AS (
    SELECT coalesce(sum(tds_rupees), 0)::numeric AS v
      FROM base
     WHERE fiscal_year = v_prev_fy
       AND fy_quarter   = v_prev_q
       AND deducted     = true
       AND deposited_to_govt_at IS NULL
  )
  SELECT
    v_fy,
    v_q,
    mtd.v,
    fy_total.v,
    q_total.v,
    undep.v,
    undep.n,
    undep.oldest_days,
    fy_total.deductees,
    fy_total.below_thresh,
    certs.n,
    prev_q.v
  FROM mtd, fy_total, q_total, undep, certs, prev_q;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tds_deductions_pulse_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tds_deductions_pulse_summary()
  TO authenticated;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.founder_tds_deductions_pulse_summary()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 1242: founder_tds_deductions_pulse_summary callable by anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.founder_tds_deductions_pulse_summary()', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 1242: founder_tds_deductions_pulse_summary not callable by authenticated';
  END IF;
  RAISE NOTICE 'round 1242 /tds-deductions-pulse-summary verified — 12 KPI §194-O withholding pulse';
END;
$$;
