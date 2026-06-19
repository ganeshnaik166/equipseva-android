BEGIN;

-- ============================================================================
-- Round 1379 — /founder-monthly-cash-ledger
-- Monthly cash transaction log + reconciliation diff.
-- Aggregator only: founder_cash_position_snapshots + payments + engineer_payouts + spare_part_orders.
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_monthly_cash_ledger_summary();

CREATE OR REPLACE FUNCTION public.founder_monthly_cash_ledger_summary()
RETURNS TABLE (
  total_snapshots_recorded bigint,
  snapshots_last_12m bigint,
  last_snapshot_at date,
  last_snapshot_balance_rupees numeric,
  first_snapshot_at date,
  first_snapshot_balance_rupees numeric,
  net_cash_change_lifetime_rupees numeric,
  avg_monthly_change_rupees numeric,
  biggest_inflow_month text,
  biggest_inflow_amount_rupees numeric,
  biggest_outflow_month text,
  biggest_outflow_amount_rupees numeric,
  months_with_negative_cash_change int,
  generated_at timestamptz
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
  WITH snap AS (
    SELECT
      snapshot_date,
      cash_balance_rupees
    FROM public.founder_cash_position_snapshots
  ),
  ranked AS (
    SELECT
      snapshot_date,
      cash_balance_rupees,
      ROW_NUMBER() OVER (ORDER BY snapshot_date ASC) AS rn_asc,
      ROW_NUMBER() OVER (ORDER BY snapshot_date DESC) AS rn_desc
    FROM snap
  ),
  first_snap AS (
    SELECT snapshot_date, cash_balance_rupees
    FROM ranked WHERE rn_asc = 1
  ),
  last_snap AS (
    SELECT snapshot_date, cash_balance_rupees
    FROM ranked WHERE rn_desc = 1
  ),
  monthly_inflow AS (
    SELECT
      to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS inflow
    FROM public.payments
    WHERE status = 'captured'
    GROUP BY 1
  ),
  monthly_outflow AS (
    SELECT
      to_char(date_trunc('month', COALESCE(processed_at, created_at)), 'YYYY-MM') AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS outflow
    FROM public.engineer_payouts
    WHERE status = 'processed'
    GROUP BY 1
  ),
  monthly_spares AS (
    SELECT
      to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
      COALESCE(SUM(total_amount), 0)::numeric AS spares
    FROM public.spare_part_orders
    WHERE payment_status = 'paid'
    GROUP BY 1
  ),
  combined AS (
    SELECT m FROM monthly_inflow
    UNION
    SELECT m FROM monthly_outflow
    UNION
    SELECT m FROM monthly_spares
  ),
  monthly_net AS (
    SELECT
      c.m,
      COALESCE(i.inflow, 0) AS inflow,
      COALESCE(o.outflow, 0) + COALESCE(s.spares, 0) AS outflow,
      COALESCE(i.inflow, 0) - (COALESCE(o.outflow, 0) + COALESCE(s.spares, 0)) AS net
    FROM combined c
    LEFT JOIN monthly_inflow i ON i.m = c.m
    LEFT JOIN monthly_outflow o ON o.m = c.m
    LEFT JOIN monthly_spares s ON s.m = c.m
  ),
  biggest_in AS (
    SELECT m, inflow FROM monthly_net ORDER BY inflow DESC NULLS LAST LIMIT 1
  ),
  biggest_out AS (
    SELECT m, outflow FROM monthly_net ORDER BY outflow DESC NULLS LAST LIMIT 1
  ),
  neg_months AS (
    SELECT COUNT(*)::int AS c FROM monthly_net WHERE net < 0
  )
  SELECT
    (SELECT COUNT(*) FROM snap)::bigint,
    (SELECT COUNT(*) FROM snap WHERE snapshot_date >= (CURRENT_DATE - INTERVAL '12 months'))::bigint,
    (SELECT snapshot_date FROM last_snap),
    (SELECT cash_balance_rupees FROM last_snap),
    (SELECT snapshot_date FROM first_snap),
    (SELECT cash_balance_rupees FROM first_snap),
    COALESCE(
      (SELECT cash_balance_rupees FROM last_snap) - (SELECT cash_balance_rupees FROM first_snap),
      0
    )::numeric,
    CASE
      WHEN (SELECT COUNT(*) FROM monthly_net) > 0
        THEN (SELECT AVG(net) FROM monthly_net)::numeric
      ELSE 0::numeric
    END,
    COALESCE((SELECT m FROM biggest_in), '—'),
    COALESCE((SELECT inflow FROM biggest_in), 0)::numeric,
    COALESCE((SELECT m FROM biggest_out), '—'),
    COALESCE((SELECT outflow FROM biggest_out), 0)::numeric,
    COALESCE((SELECT c FROM neg_months), 0),
    NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_monthly_cash_ledger_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_monthly_cash_ledger_summary() TO authenticated;

-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.founder_monthly_cash_ledger_history(int);

CREATE OR REPLACE FUNCTION public.founder_monthly_cash_ledger_history(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start date,
  snapshot_balance_rupees numeric,
  inflow_captured_rupees numeric,
  outflow_payouts_rupees numeric,
  outflow_spares_rupees numeric,
  net_change_rupees numeric,
  reconciliation_diff_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := GREATEST(1, LEAST(COALESCE(p_months, 12), 36));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', CURRENT_DATE) - ((v_months - 1) || ' months')::interval,
      date_trunc('month', CURRENT_DATE),
      INTERVAL '1 month'
    )::date AS m
  ),
  snap_per_month AS (
    SELECT DISTINCT ON (date_trunc('month', snapshot_date))
      date_trunc('month', snapshot_date)::date AS m,
      cash_balance_rupees
    FROM public.founder_cash_position_snapshots
    ORDER BY date_trunc('month', snapshot_date), snapshot_date DESC
  ),
  inflow AS (
    SELECT
      date_trunc('month', created_at)::date AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS amt
    FROM public.payments
    WHERE status = 'captured'
    GROUP BY 1
  ),
  payouts AS (
    SELECT
      date_trunc('month', COALESCE(processed_at, created_at))::date AS m,
      COALESCE(SUM(amount_rupees), 0)::numeric AS amt
    FROM public.engineer_payouts
    WHERE status = 'processed'
    GROUP BY 1
  ),
  spares AS (
    SELECT
      date_trunc('month', created_at)::date AS m,
      COALESCE(SUM(total_amount), 0)::numeric AS amt
    FROM public.spare_part_orders
    WHERE payment_status = 'paid'
    GROUP BY 1
  ),
  computed AS (
    SELECT
      mo.m AS month_start,
      sp.cash_balance_rupees AS snap_bal,
      COALESCE(i.amt, 0) AS inflow_amt,
      COALESCE(p.amt, 0) AS payout_amt,
      COALESCE(s.amt, 0) AS spare_amt,
      (COALESCE(i.amt, 0) - COALESCE(p.amt, 0) - COALESCE(s.amt, 0)) AS net_amt,
      LAG(sp.cash_balance_rupees) OVER (ORDER BY mo.m) AS prev_snap_bal
    FROM months mo
    LEFT JOIN snap_per_month sp ON sp.m = mo.m
    LEFT JOIN inflow i ON i.m = mo.m
    LEFT JOIN payouts p ON p.m = mo.m
    LEFT JOIN spares s ON s.m = mo.m
  )
  SELECT
    c.month_start,
    c.snap_bal,
    c.inflow_amt,
    c.payout_amt,
    c.spare_amt,
    c.net_amt,
    CASE
      WHEN c.snap_bal IS NULL OR c.prev_snap_bal IS NULL THEN NULL
      ELSE (c.snap_bal - c.prev_snap_bal) - c.net_amt
    END AS reconciliation_diff_rupees
  FROM computed c
  ORDER BY c.month_start DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_monthly_cash_ledger_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_monthly_cash_ledger_history(int) TO authenticated;

COMMIT;