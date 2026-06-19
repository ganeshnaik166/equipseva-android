BEGIN;
-- Round 1328 — /founder-runway-burn — runway projection from cash position + monthly burn.
-- Founder-only. One manual snapshot table (cash_balance entered monthly by founder).
-- Burn = engineer_payouts (processed) + spare_part_orders (paid) + escrow refunds.
-- Inflow = payments (captured). Net + runway months + zero-cash-date projected from 3m avg burn.



-- ─── Manual snapshot table (founder enters cash balance monthly) ───────────────
CREATE TABLE IF NOT EXISTS public.founder_cash_position_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date UNIQUE NOT NULL,
  cash_balance_rupees numeric NOT NULL CHECK (cash_balance_rupees >= 0),
  snapshot_note text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_cash_position_snapshots_date_idx
  ON public.founder_cash_position_snapshots (snapshot_date DESC);

ALTER TABLE public.founder_cash_position_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcps_founder_select ON public.founder_cash_position_snapshots;
CREATE POLICY fcps_founder_select ON public.founder_cash_position_snapshots
  FOR SELECT TO authenticated USING (public.is_founder());

DROP POLICY IF EXISTS fcps_founder_insert ON public.founder_cash_position_snapshots;
CREATE POLICY fcps_founder_insert ON public.founder_cash_position_snapshots
  FOR INSERT TO authenticated WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_cash_position_snapshots FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.founder_cash_position_snapshots TO authenticated;

-- ─── Summary RPC: 13 fields covering current cash, burn, inflow, runway ──────
DROP FUNCTION IF EXISTS public.founder_runway_burn_summary();
CREATE OR REPLACE FUNCTION public.founder_runway_burn_summary()
RETURNS TABLE (
  latest_cash_balance_rupees numeric,
  latest_snapshot_date date,
  days_since_last_snapshot int,
  monthly_burn_avg_3m_rupees numeric,
  monthly_burn_last_30d_rupees numeric,
  estimated_runway_months numeric,
  estimated_zero_cash_date date,
  monthly_inflow_avg_3m_rupees numeric,
  monthly_payouts_avg_3m_rupees numeric,
  monthly_refunds_avg_3m_rupees numeric,
  monthly_net_position_rupees numeric,
  cash_cumulative_change_30d_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cash numeric := 0;
  v_snap_date date := NULL;
  v_days_since int := NULL;
  v_burn_3m numeric := 0;
  v_burn_30d numeric := 0;
  v_payouts_3m numeric := 0;
  v_spares_3m numeric := 0;
  v_refunds_3m numeric := 0;
  v_inflow_3m numeric := 0;
  v_inflow_30d numeric := 0;
  v_net numeric := 0;
  v_runway numeric := NULL;
  v_zero_date date := NULL;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Latest manual cash snapshot
  SELECT cash_balance_rupees, snapshot_date
    INTO v_cash, v_snap_date
    FROM public.founder_cash_position_snapshots
   ORDER BY snapshot_date DESC
   LIMIT 1;

  IF v_snap_date IS NOT NULL THEN
    v_days_since := GREATEST(0, (CURRENT_DATE - v_snap_date)::int);
  END IF;

  -- Engineer payouts (processed) last 90 days → /3 for monthly avg
  SELECT COALESCE(SUM(amount_rupees), 0) / 3.0
    INTO v_payouts_3m
    FROM public.engineer_payouts
   WHERE status = 'processed'
     AND created_at >= now() - interval '90 days';

  -- Spare-part orders (paid) last 90 days → /3
  SELECT COALESCE(SUM(total_amount), 0) / 3.0
    INTO v_spares_3m
    FROM public.spare_part_orders
   WHERE COALESCE(payment_status, '') = 'paid'
     AND created_at >= now() - interval '90 days';

  -- Escrow refunds last 90 days → /3
  SELECT COALESCE(SUM(amount_rupees), 0) / 3.0
    INTO v_refunds_3m
    FROM public.repair_job_escrow
   WHERE status = 'refunded'
     AND refunded_at >= now() - interval '90 days';

  v_burn_3m := v_payouts_3m + v_spares_3m + v_refunds_3m;

  -- Last-30d burn (all three) for short-term trend
  SELECT
    COALESCE((SELECT SUM(amount_rupees) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at >= now() - interval '30 days'), 0)
  + COALESCE((SELECT SUM(total_amount) FROM public.spare_part_orders
              WHERE COALESCE(payment_status,'') = 'paid' AND created_at >= now() - interval '30 days'), 0)
  + COALESCE((SELECT SUM(amount_rupees) FROM public.repair_job_escrow
              WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days'), 0)
    INTO v_burn_30d;

  -- Inflow (captured payments) 90d → /3
  SELECT COALESCE(SUM(amount_rupees), 0) / 3.0
    INTO v_inflow_3m
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= now() - interval '90 days';

  -- Last-30d inflow
  SELECT COALESCE(SUM(amount_rupees), 0)
    INTO v_inflow_30d
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= now() - interval '30 days';

  v_net := v_inflow_3m - v_burn_3m;

  -- Runway projection: if net is positive (revenue covers burn), runway = NULL (infinite)
  -- Otherwise: cash / abs(monthly_net) months from latest snapshot
  IF v_cash > 0 AND v_burn_3m > 0 THEN
    IF v_net < 0 THEN
      v_runway := ROUND(v_cash / ABS(v_net), 2);
      v_zero_date := COALESCE(v_snap_date, CURRENT_DATE) + (v_runway * 30)::int;
    ELSE
      v_runway := NULL;
      v_zero_date := NULL;
    END IF;
  END IF;

  RETURN QUERY SELECT
    v_cash,
    v_snap_date,
    v_days_since,
    ROUND(v_burn_3m::numeric, 2),
    ROUND(v_burn_30d::numeric, 2),
    v_runway,
    v_zero_date,
    ROUND(v_inflow_3m::numeric, 2),
    ROUND(v_payouts_3m::numeric, 2),
    ROUND(v_refunds_3m::numeric, 2),
    ROUND(v_net::numeric, 2),
    ROUND((v_inflow_30d - v_burn_30d)::numeric, 2);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_runway_burn_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_runway_burn_summary() TO authenticated;

-- ─── History RPC: last N monthly snapshots + same-month burn/inflow ────────────
DROP FUNCTION IF EXISTS public.founder_runway_history(int);
CREATE OR REPLACE FUNCTION public.founder_runway_history(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start date,
  snapshot_date date,
  cash_balance_rupees numeric,
  month_inflow_rupees numeric,
  month_burn_rupees numeric,
  month_net_rupees numeric,
  snapshot_note text
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
  WITH months AS (
    SELECT (date_trunc('month', generate_series(
              date_trunc('month', now()) - ((p_months - 1) || ' months')::interval,
              date_trunc('month', now()),
              interval '1 month'))::date) AS m_start
  ),
  inflow AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount_rupees)::numeric AS infl
      FROM public.payments
     WHERE status = 'captured'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  payouts AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount_rupees)::numeric AS amt
      FROM public.engineer_payouts
     WHERE status = 'processed'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  spares AS (
    SELECT date_trunc('month', created_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(total_amount)::numeric AS amt
      FROM public.spare_part_orders
     WHERE COALESCE(payment_status,'') = 'paid'
       AND created_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  refunds AS (
    SELECT date_trunc('month', refunded_at AT TIME ZONE 'Asia/Kolkata')::date AS m_start,
           SUM(amount_rupees)::numeric AS amt
      FROM public.repair_job_escrow
     WHERE status = 'refunded'
       AND refunded_at >= now() - ((p_months + 1) || ' months')::interval
     GROUP BY 1
  ),
  snaps AS (
    SELECT DISTINCT ON (date_trunc('month', snapshot_date))
           date_trunc('month', snapshot_date)::date AS m_start,
           snapshot_date,
           cash_balance_rupees,
           snapshot_note
      FROM public.founder_cash_position_snapshots
     ORDER BY date_trunc('month', snapshot_date), snapshot_date DESC
  )
  SELECT
    m.m_start                                                    AS month_start,
    s.snapshot_date                                              AS snapshot_date,
    s.cash_balance_rupees                                        AS cash_balance_rupees,
    COALESCE(i.infl, 0)                                          AS month_inflow_rupees,
    COALESCE(p.amt, 0) + COALESCE(sp.amt, 0) + COALESCE(r.amt,0) AS month_burn_rupees,
    COALESCE(i.infl, 0)
      - (COALESCE(p.amt, 0) + COALESCE(sp.amt, 0) + COALESCE(r.amt, 0)) AS month_net_rupees,
    s.snapshot_note                                              AS snapshot_note
  FROM months m
  LEFT JOIN inflow  i  ON i.m_start  = m.m_start
  LEFT JOIN payouts p  ON p.m_start  = m.m_start
  LEFT JOIN spares  sp ON sp.m_start = m.m_start
  LEFT JOIN refunds r  ON r.m_start  = m.m_start
  LEFT JOIN snaps   s  ON s.m_start  = m.m_start
  ORDER BY m.m_start DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_runway_history(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_runway_history(int) TO authenticated;

COMMIT;