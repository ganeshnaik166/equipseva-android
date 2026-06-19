-- =====================================================================
-- Round 1207 — /reconciliation-tax-snapshot-summary
-- =====================================================================
-- Founder finance-ops snapshot. Three-way reconciliation (r489) + TDS
-- 194-O ledger (r490) + r857 recon health + r858 TDS health + r889
-- payouts-net-of-TDS. One landing for statutory audit / 26Q filing.
--
-- 12 KPIs (today / MTD / FY / lifetime mix):
--   1. recon_runs_today
--   2. recon_anomalies_open
--   3. recon_drift_runs_30d
--   4. recon_last_run_status
--   5. recon_inflow_mtd_rupees
--   6. recon_outflow_mtd_rupees
--   7. tds_deducted_mtd_rupees
--   8. tds_deductions_mtd_count
--   9. tds_undeposited_rupees
--  10. tds_certificate_backlog
--  11. tds_fy_gross_rupees
--  12. tds_fy_rupees
BEGIN;

DROP FUNCTION IF EXISTS public.founder_reconciliation_tax_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_reconciliation_tax_snapshot_summary()
RETURNS TABLE (
  recon_runs_today              bigint,
  recon_anomalies_open          bigint,
  recon_drift_runs_30d          bigint,
  recon_last_run_status         text,
  recon_inflow_mtd_rupees       numeric,
  recon_outflow_mtd_rupees      numeric,
  tds_deducted_mtd_rupees       numeric,
  tds_deductions_mtd_count      bigint,
  tds_undeposited_rupees        numeric,
  tds_certificate_backlog       bigint,
  tds_fy_gross_rupees           numeric,
  tds_fy_rupees                 numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_ist date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_month_start date := date_trunc('month', v_today_ist)::date;
  v_30d_ago date := v_today_ist - 30;
  v_fy text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT fiscal_year INTO v_fy FROM public.indian_fiscal_year_for(now());

  RETURN QUERY
  SELECT
    -- 1. Reconciliation runs executed today (IST)
    (SELECT count(*)::bigint
       FROM public.reconciliation_runs
       WHERE run_date = v_today_ist),

    -- 2. Open / investigating anomalies
    (SELECT count(*)::bigint
       FROM public.reconciliation_anomalies
       WHERE status IN ('open','investigating')),

    -- 3. Drift-status runs in last 30d
    (SELECT count(*)::bigint
       FROM public.reconciliation_runs
       WHERE run_date >= v_30d_ago AND status = 'drift'),

    -- 4. Status of most recent reconciliation_run
    (SELECT coalesce(status, 'never_ran')
       FROM public.reconciliation_runs
       ORDER BY run_date DESC NULLS LAST
       LIMIT 1),

    -- 5. Total Razorpay inflow MTD (rupees)
    (SELECT coalesce(sum(rzp_total_inflow_rupees), 0)::numeric
       FROM public.reconciliation_runs
       WHERE run_date >= v_month_start),

    -- 6. Total Cashfree outflow MTD (rupees)
    (SELECT coalesce(sum(cf_total_outflow_rupees), 0)::numeric
       FROM public.reconciliation_runs
       WHERE run_date >= v_month_start),

    -- 7. TDS deducted MTD (rupees)
    (SELECT coalesce(sum(tds_rupees), 0)::numeric
       FROM public.tds_deductions
       WHERE created_at >= v_month_start::timestamptz
         AND deducted = true),

    -- 8. TDS deduction rows MTD (count of deducted=true)
    (SELECT count(*)::bigint
       FROM public.tds_deductions
       WHERE created_at >= v_month_start::timestamptz
         AND deducted = true),

    -- 9. TDS deducted but not yet deposited to govt (rupees)
    (SELECT coalesce(sum(tds_rupees), 0)::numeric
       FROM public.tds_deductions
       WHERE deducted = true
         AND deposited_to_govt_at IS NULL),

    -- 10. TDS cert backlog: deducted, deposited, but cert not issued
    (SELECT count(*)::bigint
       FROM public.tds_deductions
       WHERE deducted = true
         AND deposited_to_govt_at IS NOT NULL
         AND certificate_issued_at IS NULL),

    -- 11. FY-to-date gross to engineers (rupees)
    (SELECT coalesce(sum(gross_rupees), 0)::numeric
       FROM public.tds_deductions
       WHERE fiscal_year = v_fy),

    -- 12. FY-to-date TDS deducted (rupees)
    (SELECT coalesce(sum(tds_rupees), 0)::numeric
       FROM public.tds_deductions
       WHERE fiscal_year = v_fy
         AND deducted = true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_reconciliation_tax_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_reconciliation_tax_snapshot_summary() TO authenticated;

COMMIT;