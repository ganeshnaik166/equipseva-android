-- r1340 — Founder cash conversion cycle dashboard
-- Aggregator across gst_invoices (AR) + spare_part_orders (AP) + amc_contracts.
-- NO new tables. Pure read-only RPCs gated by is_founder().
-- DSO  = avg days from gst_invoices.issued_at to updated_at (paid invoices, 90d)
-- DPO  = avg days from spare_part_orders.created_at to updated_at (paid orders, 90d)
-- INVD = inventory days proxy = same as DPO until paid (spare parts hold time, 90d)
-- CCC  = DSO - DPO + inventory_days
-- NWC  = outstanding receivables - outstanding payables
BEGIN;

-- ============================================================================
-- 1) Summary RPC — 16 KPIs in single row
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cash_conversion_cycle_summary();
CREATE OR REPLACE FUNCTION public.founder_cash_conversion_cycle_summary()
RETURNS TABLE (
  dso_days_avg_90d                    numeric,
  dpo_days_avg_90d                    numeric,
  inventory_days_avg_90d              numeric,
  cash_conversion_cycle_days          numeric,
  total_outstanding_receivables_rupees numeric,
  total_outstanding_payables_rupees   numeric,
  net_working_capital_rupees          numeric,
  ar_aging_0_30_rupees                numeric,
  ar_aging_31_60_rupees               numeric,
  ar_aging_61_90_rupees               numeric,
  ar_aging_over_90_rupees             numeric,
  ap_aging_0_30_rupees                numeric,
  ap_aging_31_60_rupees               numeric,
  ap_aging_61_90_rupees               numeric,
  ap_aging_over_90_rupees             numeric,
  generated_at                        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_dso           numeric := 0;
  v_dpo           numeric := 0;
  v_inv           numeric := 0;
  v_ccc           numeric := 0;
  v_ar_total      numeric := 0;
  v_ap_total      numeric := 0;
  v_nwc           numeric := 0;
  v_ar_0_30       numeric := 0;
  v_ar_31_60      numeric := 0;
  v_ar_61_90      numeric := 0;
  v_ar_90p        numeric := 0;
  v_ap_0_30       numeric := 0;
  v_ap_31_60      numeric := 0;
  v_ap_61_90      numeric := 0;
  v_ap_90p        numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- DSO: avg days from issued_at to updated_at for invoices that flipped to 'paid' status in last 90d.
  -- Fallback: gst_invoices.status vocabulary may not include 'paid' — treat status='issued' as outstanding,
  -- and use updated_at proxy when status moved away from 'issued'.
  SELECT coalesce(avg(extract(epoch FROM (g.updated_at - g.issued_at)) / 86400.0), 0)::numeric
    INTO v_dso
  FROM public.gst_invoices g
  WHERE g.status <> 'issued'
    AND g.updated_at >= now() - interval '90 days'
    AND g.updated_at > g.issued_at;

  -- DPO: avg days from spare_part_orders.created_at to updated_at for paid orders in last 90d.
  SELECT coalesce(avg(extract(epoch FROM (o.updated_at - o.created_at)) / 86400.0), 0)::numeric
    INTO v_dpo
  FROM public.spare_part_orders o
  WHERE o.payment_status = 'paid'
    AND o.updated_at >= now() - interval '90 days'
    AND o.updated_at > o.created_at;

  -- Inventory days: same hold-time proxy on spare parts pending (not yet paid) in last 90d.
  SELECT coalesce(avg(extract(epoch FROM (now() - o.created_at)) / 86400.0), 0)::numeric
    INTO v_inv
  FROM public.spare_part_orders o
  WHERE coalesce(o.payment_status, '') <> 'paid'
    AND o.created_at >= now() - interval '90 days';

  v_ccc := v_dso - v_dpo + v_inv;

  -- Outstanding receivables: gst_invoices with status='issued' (open invoices).
  SELECT coalesce(sum(g.taxable_amount_rupees), 0)::numeric
    INTO v_ar_total
  FROM public.gst_invoices g
  WHERE g.status = 'issued';

  -- Outstanding payables: spare_part_orders not yet paid + not cancelled/refunded.
  SELECT coalesce(sum(o.total_amount), 0)::numeric
    INTO v_ap_total
  FROM public.spare_part_orders o
  WHERE coalesce(o.payment_status, '') NOT IN ('paid','cancelled','refunded');

  v_nwc := v_ar_total - v_ap_total;

  -- AR aging buckets — bucket by days-since-issued for status='issued'.
  SELECT
    coalesce(sum(CASE WHEN d <= 30                THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 30  AND d <= 60    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 60  AND d <= 90    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 90                 THEN amt END), 0)
  INTO v_ar_0_30, v_ar_31_60, v_ar_61_90, v_ar_90p
  FROM (
    SELECT
      extract(epoch FROM (now() - g.issued_at)) / 86400.0 AS d,
      g.taxable_amount_rupees::numeric AS amt
    FROM public.gst_invoices g
    WHERE g.status = 'issued'
  ) ar;

  -- AP aging buckets — bucket by days-since-created for unpaid orders.
  SELECT
    coalesce(sum(CASE WHEN d <= 30                THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 30  AND d <= 60    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 60  AND d <= 90    THEN amt END), 0),
    coalesce(sum(CASE WHEN d > 90                 THEN amt END), 0)
  INTO v_ap_0_30, v_ap_31_60, v_ap_61_90, v_ap_90p
  FROM (
    SELECT
      extract(epoch FROM (now() - o.created_at)) / 86400.0 AS d,
      o.total_amount::numeric AS amt
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status, '') NOT IN ('paid','cancelled','refunded')
  ) ap;

  RETURN QUERY SELECT
    round(v_dso, 2),
    round(v_dpo, 2),
    round(v_inv, 2),
    round(v_ccc, 2),
    round(v_ar_total, 2),
    round(v_ap_total, 2),
    round(v_nwc, 2),
    round(v_ar_0_30, 2),
    round(v_ar_31_60, 2),
    round(v_ar_61_90, 2),
    round(v_ar_90p, 2),
    round(v_ap_0_30, 2),
    round(v_ap_31_60, 2),
    round(v_ap_61_90, 2),
    round(v_ap_90p, 2),
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cash_conversion_cycle_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cash_conversion_cycle_summary() TO authenticated;

-- ============================================================================
-- 2) History RPC — weekly trend for last p_weeks weeks (default 12)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cash_conversion_history(integer);
CREATE OR REPLACE FUNCTION public.founder_cash_conversion_history(p_weeks integer DEFAULT 12)
RETURNS TABLE (
  week_start                          date,
  dso_days_avg                        numeric,
  dpo_days_avg                        numeric,
  cash_conversion_cycle_days          numeric,
  net_working_capital_rupees          numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_weeks integer;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_weeks := greatest(1, least(coalesce(p_weeks, 12), 52));

  RETURN QUERY
  WITH weeks AS (
    SELECT (date_trunc('week', now())::date - (n || ' weeks')::interval)::date AS wk_start
    FROM generate_series(0, v_weeks - 1) AS n
  ),
  ar_paid AS (
    SELECT
      date_trunc('week', g.updated_at)::date AS wk,
      avg(extract(epoch FROM (g.updated_at - g.issued_at)) / 86400.0)::numeric AS dso
    FROM public.gst_invoices g
    WHERE g.status <> 'issued'
      AND g.updated_at >= (date_trunc('week', now())::date - ((v_weeks - 1) || ' weeks')::interval)
      AND g.updated_at > g.issued_at
    GROUP BY 1
  ),
  ap_paid AS (
    SELECT
      date_trunc('week', o.updated_at)::date AS wk,
      avg(extract(epoch FROM (o.updated_at - o.created_at)) / 86400.0)::numeric AS dpo
    FROM public.spare_part_orders o
    WHERE o.payment_status = 'paid'
      AND o.updated_at >= (date_trunc('week', now())::date - ((v_weeks - 1) || ' weeks')::interval)
      AND o.updated_at > o.created_at
    GROUP BY 1
  ),
  ar_open AS (
    SELECT
      w.wk_start AS wk,
      coalesce(sum(g.taxable_amount_rupees), 0)::numeric AS ar_amt
    FROM weeks w
    LEFT JOIN public.gst_invoices g
      ON g.status = 'issued'
     AND g.issued_at < (w.wk_start + interval '7 days')
    GROUP BY 1
  ),
  ap_open AS (
    SELECT
      w.wk_start AS wk,
      coalesce(sum(o.total_amount), 0)::numeric AS ap_amt
    FROM weeks w
    LEFT JOIN public.spare_part_orders o
      ON coalesce(o.payment_status, '') NOT IN ('paid','cancelled','refunded')
     AND o.created_at < (w.wk_start + interval '7 days')
    GROUP BY 1
  )
  SELECT
    w.wk_start,
    round(coalesce(ar.dso, 0), 2)                                       AS dso_days_avg,
    round(coalesce(ap.dpo, 0), 2)                                       AS dpo_days_avg,
    round(coalesce(ar.dso, 0) - coalesce(ap.dpo, 0), 2)                 AS ccc_days,
    round(coalesce(arx.ar_amt, 0) - coalesce(apx.ap_amt, 0), 2)         AS nwc_rupees
  FROM weeks w
  LEFT JOIN ar_paid ar  ON ar.wk  = w.wk_start
  LEFT JOIN ap_paid ap  ON ap.wk  = w.wk_start
  LEFT JOIN ar_open arx ON arx.wk = w.wk_start
  LEFT JOIN ap_open apx ON apx.wk = w.wk_start
  ORDER BY w.wk_start DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cash_conversion_history(integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cash_conversion_history(integer) TO authenticated;

COMMIT;
