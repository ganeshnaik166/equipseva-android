BEGIN;

CREATE TABLE IF NOT EXISTS public.payment_mode_collections_r2376 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  collected_at timestamptz NOT NULL DEFAULT now(),
  customer_org_id uuid,
  customer_name text NOT NULL,
  invoice_ref text,
  payment_mode text NOT NULL CHECK (payment_mode IN ('upi','neft','rtgs','card_debit','card_credit','cash','cheque','wallet','net_banking','imps')),
  gross_amount_rupees numeric(14,2) NOT NULL,
  mdr_pct numeric(6,3) NOT NULL DEFAULT 0,
  mdr_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  flat_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  gst_on_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  reconciliation_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  chargeback_reserve_rupees numeric(12,2) NOT NULL DEFAULT 0,
  total_collection_cost_rupees numeric(14,2) GENERATED ALWAYS AS (mdr_fee_rupees + flat_fee_rupees + gst_on_fee_rupees + reconciliation_cost_rupees + chargeback_reserve_rupees) STORED,
  net_received_rupees numeric(14,2) GENERATED ALWAYS AS (gross_amount_rupees - (mdr_fee_rupees + flat_fee_rupees + gst_on_fee_rupees + reconciliation_cost_rupees + chargeback_reserve_rupees)) STORED,
  net_margin_pct numeric(6,3) GENERATED ALWAYS AS (
    CASE WHEN gross_amount_rupees > 0
      THEN ROUND(((gross_amount_rupees - (mdr_fee_rupees + flat_fee_rupees + gst_on_fee_rupees + reconciliation_cost_rupees + chargeback_reserve_rupees)) / gross_amount_rupees) * 100, 3)
      ELSE 0 END
  ) STORED,
  settlement_lag_hours numeric(8,2) NOT NULL DEFAULT 0,
  settled_at timestamptz,
  status text NOT NULL DEFAULT 'settled' CHECK (status IN ('pending','settled','disputed','refunded','chargeback','failed')),
  failure_reason text,
  recorded_by_profile_id uuid REFERENCES public.profiles(id),
  recorded_by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pmc_r2376_mode ON public.payment_mode_collections_r2376(payment_mode);
CREATE INDEX IF NOT EXISTS idx_pmc_r2376_collected_at ON public.payment_mode_collections_r2376(collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_pmc_r2376_status ON public.payment_mode_collections_r2376(status);
CREATE INDEX IF NOT EXISTS idx_pmc_r2376_customer ON public.payment_mode_collections_r2376(customer_name);

CREATE TABLE IF NOT EXISTS public.payment_mode_cost_overrides_r2376 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_mode text NOT NULL CHECK (payment_mode IN ('upi','neft','rtgs','card_debit','card_credit','cash','cheque','wallet','net_banking','imps')),
  effective_from date NOT NULL DEFAULT current_date,
  effective_to date,
  baseline_mdr_pct numeric(6,3) NOT NULL DEFAULT 0,
  baseline_flat_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  baseline_reconciliation_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  baseline_chargeback_reserve_pct numeric(6,3) NOT NULL DEFAULT 0,
  notes text,
  set_by_profile_id uuid REFERENCES public.profiles(id),
  set_by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pmco_r2376_mode ON public.payment_mode_cost_overrides_r2376(payment_mode, effective_from DESC);

ALTER TABLE public.payment_mode_collections_r2376 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_mode_cost_overrides_r2376 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pmc_r2376 ON public.payment_mode_collections_r2376;
CREATE POLICY founder_all_pmc_r2376 ON public.payment_mode_collections_r2376
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pmco_r2376 ON public.payment_mode_cost_overrides_r2376;
CREATE POLICY founder_all_pmco_r2376 ON public.payment_mode_cost_overrides_r2376
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2376_list_collections()
RETURNS TABLE (
  id uuid,
  collected_at timestamptz,
  customer_name text,
  invoice_ref text,
  payment_mode text,
  gross_amount_rupees numeric,
  total_collection_cost_rupees numeric,
  net_received_rupees numeric,
  net_margin_pct numeric,
  settlement_lag_hours numeric,
  status text,
  recorded_by_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.collected_at, c.customer_name, c.invoice_ref, c.payment_mode,
           c.gross_amount_rupees, c.total_collection_cost_rupees, c.net_received_rupees,
           c.net_margin_pct, c.settlement_lag_hours, c.status, c.recorded_by_email
    FROM public.payment_mode_collections_r2376 c
    ORDER BY c.collected_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_summary()
RETURNS TABLE (
  total_txn_count bigint,
  total_gross_rupees numeric,
  total_collection_cost_rupees numeric,
  total_net_received_rupees numeric,
  overall_net_margin_pct numeric,
  settled_count bigint,
  disputed_count bigint,
  refunded_count bigint,
  chargeback_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::bigint,
      COALESCE(SUM(gross_amount_rupees), 0)::numeric,
      COALESCE(SUM(total_collection_cost_rupees), 0)::numeric,
      COALESCE(SUM(net_received_rupees), 0)::numeric,
      CASE WHEN COALESCE(SUM(gross_amount_rupees), 0) > 0
        THEN ROUND((SUM(net_received_rupees) / SUM(gross_amount_rupees)) * 100, 3)
        ELSE 0 END::numeric,
      COUNT(*) FILTER (WHERE status = 'settled')::bigint,
      COUNT(*) FILTER (WHERE status = 'disputed')::bigint,
      COUNT(*) FILTER (WHERE status = 'refunded')::bigint,
      COUNT(*) FILTER (WHERE status = 'chargeback')::bigint
    FROM public.payment_mode_collections_r2376;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_by_mode()
RETURNS TABLE (
  payment_mode text,
  txn_count bigint,
  total_gross_rupees numeric,
  total_collection_cost_rupees numeric,
  total_net_received_rupees numeric,
  avg_net_margin_pct numeric,
  avg_settlement_lag_hours numeric,
  failure_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.payment_mode,
           COUNT(*)::bigint,
           COALESCE(SUM(c.gross_amount_rupees), 0)::numeric,
           COALESCE(SUM(c.total_collection_cost_rupees), 0)::numeric,
           COALESCE(SUM(c.net_received_rupees), 0)::numeric,
           CASE WHEN COALESCE(SUM(c.gross_amount_rupees), 0) > 0
             THEN ROUND((SUM(c.net_received_rupees) / SUM(c.gross_amount_rupees)) * 100, 3)
             ELSE 0 END::numeric,
           COALESCE(ROUND(AVG(c.settlement_lag_hours), 2), 0)::numeric,
           CASE WHEN COUNT(*) > 0
             THEN ROUND((COUNT(*) FILTER (WHERE c.status IN ('failed','chargeback','refunded'))::numeric / COUNT(*)::numeric) * 100, 3)
             ELSE 0 END::numeric
    FROM public.payment_mode_collections_r2376 c
    GROUP BY c.payment_mode
    ORDER BY SUM(c.gross_amount_rupees) DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_top_customers_by_mode_cost()
RETURNS TABLE (
  customer_name text,
  txn_count bigint,
  total_gross_rupees numeric,
  total_collection_cost_rupees numeric,
  effective_margin_pct numeric,
  dominant_mode text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH per_customer AS (
      SELECT c.customer_name,
             COUNT(*) AS cnt,
             SUM(c.gross_amount_rupees) AS gross,
             SUM(c.total_collection_cost_rupees) AS cost,
             SUM(c.net_received_rupees) AS net
      FROM public.payment_mode_collections_r2376 c
      GROUP BY c.customer_name
    ),
    dominant AS (
      SELECT DISTINCT ON (c.customer_name)
             c.customer_name, c.payment_mode,
             COUNT(*) OVER (PARTITION BY c.customer_name, c.payment_mode) AS mode_cnt
      FROM public.payment_mode_collections_r2376 c
      ORDER BY c.customer_name, mode_cnt DESC
    )
    SELECT p.customer_name,
           p.cnt::bigint,
           p.gross::numeric,
           p.cost::numeric,
           CASE WHEN p.gross > 0 THEN ROUND((p.net / p.gross) * 100, 3) ELSE 0 END::numeric,
           d.payment_mode
    FROM per_customer p
    LEFT JOIN dominant d ON d.customer_name = p.customer_name
    ORDER BY p.cost DESC NULLS LAST
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_monthly_trend()
RETURNS TABLE (
  month_start date,
  payment_mode text,
  txn_count bigint,
  total_gross_rupees numeric,
  total_collection_cost_rupees numeric,
  net_margin_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', c.collected_at)::date,
           c.payment_mode,
           COUNT(*)::bigint,
           COALESCE(SUM(c.gross_amount_rupees), 0)::numeric,
           COALESCE(SUM(c.total_collection_cost_rupees), 0)::numeric,
           CASE WHEN COALESCE(SUM(c.gross_amount_rupees), 0) > 0
             THEN ROUND((SUM(c.net_received_rupees) / SUM(c.gross_amount_rupees)) * 100, 3)
             ELSE 0 END::numeric
    FROM public.payment_mode_collections_r2376 c
    WHERE c.collected_at >= now() - interval '12 months'
    GROUP BY 1, 2
    ORDER BY 1 DESC, SUM(c.gross_amount_rupees) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_cost_overrides_active()
RETURNS TABLE (
  id uuid,
  payment_mode text,
  effective_from date,
  effective_to date,
  baseline_mdr_pct numeric,
  baseline_flat_fee_rupees numeric,
  baseline_reconciliation_cost_rupees numeric,
  baseline_chargeback_reserve_pct numeric,
  set_by_email text,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.payment_mode, o.effective_from, o.effective_to,
           o.baseline_mdr_pct, o.baseline_flat_fee_rupees,
           o.baseline_reconciliation_cost_rupees, o.baseline_chargeback_reserve_pct,
           o.set_by_email, o.notes
    FROM public.payment_mode_cost_overrides_r2376 o
    WHERE o.effective_to IS NULL OR o.effective_to >= current_date
    ORDER BY o.payment_mode, o.effective_from DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2376_mode_recommendations()
RETURNS TABLE (
  payment_mode text,
  total_gross_rupees numeric,
  effective_margin_pct numeric,
  avg_settlement_lag_hours numeric,
  failure_rate_pct numeric,
  recommendation text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH agg AS (
      SELECT c.payment_mode,
             COALESCE(SUM(c.gross_amount_rupees), 0) AS gross,
             COALESCE(SUM(c.net_received_rupees), 0) AS net,
             COALESCE(AVG(c.settlement_lag_hours), 0) AS lag,
             CASE WHEN COUNT(*) > 0
               THEN (COUNT(*) FILTER (WHERE c.status IN ('failed','chargeback','refunded'))::numeric / COUNT(*)::numeric) * 100
               ELSE 0 END AS fail_rate
      FROM public.payment_mode_collections_r2376 c
      GROUP BY c.payment_mode
    )
    SELECT a.payment_mode,
           a.gross::numeric,
           CASE WHEN a.gross > 0 THEN ROUND((a.net / a.gross) * 100, 3) ELSE 0 END::numeric,
           ROUND(a.lag, 2)::numeric,
           ROUND(a.fail_rate, 3)::numeric,
           CASE
             WHEN a.gross > 0 AND (a.net / a.gross) >= 0.985 AND a.lag <= 24 AND a.fail_rate <= 1 THEN 'promote'
             WHEN a.gross > 0 AND (a.net / a.gross) <= 0.95 THEN 'discourage'
             WHEN a.fail_rate >= 5 THEN 'investigate'
             WHEN a.lag > 72 THEN 'review_settlement'
             ELSE 'steady'
           END::text
    FROM agg a
    ORDER BY a.gross DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2376_list_collections() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_by_mode() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_top_customers_by_mode_cost() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_monthly_trend() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_cost_overrides_active() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2376_mode_recommendations() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2376_list_collections() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_by_mode() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_top_customers_by_mode_cost() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_cost_overrides_active() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2376_mode_recommendations() TO authenticated;

COMMIT;
