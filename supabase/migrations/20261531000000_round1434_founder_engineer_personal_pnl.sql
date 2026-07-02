BEGIN;
-- Round 1434 — Founder engineer personal P&L
-- 1 table + 6 RPCs + RLS

-- =========================================================================
-- Table: founder_engineer_personal_pnl_snapshots
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_engineer_personal_pnl_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  period_start date,
  period_end date,
  gross_revenue_attributed_rupees numeric NOT NULL DEFAULT 0,
  payouts_received_rupees numeric NOT NULL DEFAULT 0,
  parts_consumed_rupees numeric NOT NULL DEFAULT 0,
  travel_expense_rupees numeric NOT NULL DEFAULT 0,
  equipment_kit_amortization_rupees numeric NOT NULL DEFAULT 0,
  training_cost_rupees numeric NOT NULL DEFAULT 0,
  net_engineer_profit_rupees numeric NOT NULL DEFAULT 0,
  gross_margin_pct numeric,
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, period_label)
);

CREATE INDEX IF NOT EXISTS idx_fepps_engineer ON public.founder_engineer_personal_pnl_snapshots(engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fepps_period ON public.founder_engineer_personal_pnl_snapshots(period_label);
CREATE INDEX IF NOT EXISTS idx_fepps_created ON public.founder_engineer_personal_pnl_snapshots(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fepps_net_profit ON public.founder_engineer_personal_pnl_snapshots(net_engineer_profit_rupees DESC);

ALTER TABLE public.founder_engineer_personal_pnl_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fepps_founder_all ON public.founder_engineer_personal_pnl_snapshots;
CREATE POLICY fepps_founder_all ON public.founder_engineer_personal_pnl_snapshots
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fepps_engineer_own_read ON public.founder_engineer_personal_pnl_snapshots;
CREATE POLICY fepps_engineer_own_read ON public.founder_engineer_personal_pnl_snapshots
  FOR SELECT TO authenticated USING (engineer_user_id = auth.uid());

-- =========================================================================
-- RPC 1: founder_engineer_personal_pnl_summary (14 KPIs)
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_personal_pnl_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_personal_pnl_summary()
RETURNS TABLE (
  snapshots_total int,
  engineers_covered int,
  snapshots_30d int,
  snapshots_90d int,
  top_engineer_net_profit_rupees numeric,
  avg_net_profit_rupees numeric,
  avg_net_margin_pct numeric,
  total_lifetime_revenue_rupees numeric,
  total_lifetime_payouts_rupees numeric,
  total_lifetime_parts_rupees numeric,
  total_lifetime_travel_rupees numeric,
  total_lifetime_kit_amort_rupees numeric,
  total_lifetime_training_rupees numeric,
  total_lifetime_net_profit_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.founder_engineer_personal_pnl_snapshots),
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM public.founder_engineer_personal_pnl_snapshots),
    (SELECT COUNT(*)::int FROM public.founder_engineer_personal_pnl_snapshots WHERE created_at >= now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM public.founder_engineer_personal_pnl_snapshots WHERE created_at >= now() - interval '90 days'),
    COALESCE((SELECT MAX(net_engineer_profit_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT ROUND(AVG(net_engineer_profit_rupees)::numeric, 2) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT ROUND(AVG(gross_margin_pct)::numeric, 2) FROM public.founder_engineer_personal_pnl_snapshots WHERE gross_margin_pct IS NOT NULL), 0),
    COALESCE((SELECT SUM(gross_revenue_attributed_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(payouts_received_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(parts_consumed_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(travel_expense_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(equipment_kit_amortization_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(training_cost_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0),
    COALESCE((SELECT SUM(net_engineer_profit_rupees) FROM public.founder_engineer_personal_pnl_snapshots), 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_summary() TO authenticated;

-- =========================================================================
-- RPC 2: founder_engineer_personal_pnl_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_personal_pnl_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_personal_pnl_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  snapshot_id uuid,
  engineer_user_id uuid,
  period_label text,
  period_start date,
  period_end date,
  gross_revenue_attributed_rupees numeric,
  payouts_received_rupees numeric,
  parts_consumed_rupees numeric,
  travel_expense_rupees numeric,
  equipment_kit_amortization_rupees numeric,
  training_cost_rupees numeric,
  net_engineer_profit_rupees numeric,
  gross_margin_pct numeric,
  generated_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, s.period_label, s.period_start, s.period_end,
         s.gross_revenue_attributed_rupees, s.payouts_received_rupees,
         s.parts_consumed_rupees, s.travel_expense_rupees,
         s.equipment_kit_amortization_rupees, s.training_cost_rupees,
         s.net_engineer_profit_rupees, s.gross_margin_pct,
         s.generated_at, s.created_at
  FROM public.founder_engineer_personal_pnl_snapshots s
  ORDER BY s.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_recent(int) TO authenticated;

-- =========================================================================
-- RPC 3: founder_engineer_personal_pnl_top_performers
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_personal_pnl_top_performers(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_personal_pnl_top_performers(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  snapshots_count int,
  total_revenue_rupees numeric,
  total_payouts_rupees numeric,
  total_net_profit_rupees numeric,
  avg_margin_pct numeric,
  last_snapshot_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.engineer_user_id,
         COUNT(*)::int,
         COALESCE(SUM(s.gross_revenue_attributed_rupees), 0),
         COALESCE(SUM(s.payouts_received_rupees), 0),
         COALESCE(SUM(s.net_engineer_profit_rupees), 0),
         COALESCE(ROUND(AVG(s.gross_margin_pct)::numeric, 2), 0),
         MAX(s.created_at)
  FROM public.founder_engineer_personal_pnl_snapshots s
  GROUP BY s.engineer_user_id
  ORDER BY COALESCE(SUM(s.net_engineer_profit_rupees), 0) DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_top_performers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_personal_pnl_top_performers(int) TO authenticated;

-- =========================================================================
-- RPC 4: engineer_personal_pnl_my_snapshots (engineer self-view)
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_personal_pnl_my_snapshots(int);
CREATE OR REPLACE FUNCTION public.engineer_personal_pnl_my_snapshots(p_limit int DEFAULT 20)
RETURNS TABLE (
  snapshot_id uuid,
  period_label text,
  period_start date,
  period_end date,
  gross_revenue_attributed_rupees numeric,
  payouts_received_rupees numeric,
  parts_consumed_rupees numeric,
  travel_expense_rupees numeric,
  equipment_kit_amortization_rupees numeric,
  training_cost_rupees numeric,
  net_engineer_profit_rupees numeric,
  gross_margin_pct numeric,
  generated_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.period_label, s.period_start, s.period_end,
         s.gross_revenue_attributed_rupees, s.payouts_received_rupees,
         s.parts_consumed_rupees, s.travel_expense_rupees,
         s.equipment_kit_amortization_rupees, s.training_cost_rupees,
         s.net_engineer_profit_rupees, s.gross_margin_pct,
         s.generated_at, s.created_at
  FROM public.founder_engineer_personal_pnl_snapshots s
  WHERE s.engineer_user_id = auth.uid()
  ORDER BY s.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_personal_pnl_my_snapshots(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_personal_pnl_my_snapshots(int) TO authenticated;

-- =========================================================================
-- RPC 5: log_founder_engineer_pnl_record_snapshot
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_pnl_record_snapshot(uuid, text, date, date, numeric, numeric, numeric, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_pnl_record_snapshot(
  p_engineer_user_id uuid,
  p_period_label text,
  p_period_start date DEFAULT NULL,
  p_period_end date DEFAULT NULL,
  p_gross_revenue_attributed_rupees numeric DEFAULT 0,
  p_payouts_received_rupees numeric DEFAULT 0,
  p_parts_consumed_rupees numeric DEFAULT 0,
  p_travel_expense_rupees numeric DEFAULT 0,
  p_equipment_kit_amortization_rupees numeric DEFAULT 0,
  p_training_cost_rupees numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_net numeric;
  v_margin numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_period_label IS NULL OR length(trim(p_period_label)) = 0 THEN
    RAISE EXCEPTION 'period_label required' USING ERRCODE = '22023';
  END IF;

  v_net := COALESCE(p_payouts_received_rupees, 0)
         - COALESCE(p_parts_consumed_rupees, 0)
         - COALESCE(p_travel_expense_rupees, 0)
         - COALESCE(p_equipment_kit_amortization_rupees, 0)
         - COALESCE(p_training_cost_rupees, 0);

  IF COALESCE(p_gross_revenue_attributed_rupees, 0) > 0 THEN
    v_margin := ROUND((v_net * 100.0 / p_gross_revenue_attributed_rupees)::numeric, 2);
  ELSE
    v_margin := NULL;
  END IF;

  INSERT INTO public.founder_engineer_personal_pnl_snapshots (
    engineer_user_id, period_label, period_start, period_end,
    gross_revenue_attributed_rupees, payouts_received_rupees,
    parts_consumed_rupees, travel_expense_rupees,
    equipment_kit_amortization_rupees, training_cost_rupees,
    net_engineer_profit_rupees, gross_margin_pct
  )
  VALUES (
    p_engineer_user_id, p_period_label, p_period_start, p_period_end,
    COALESCE(p_gross_revenue_attributed_rupees, 0),
    COALESCE(p_payouts_received_rupees, 0),
    COALESCE(p_parts_consumed_rupees, 0),
    COALESCE(p_travel_expense_rupees, 0),
    COALESCE(p_equipment_kit_amortization_rupees, 0),
    COALESCE(p_training_cost_rupees, 0),
    v_net, v_margin
  )
  ON CONFLICT (engineer_user_id, period_label) DO UPDATE SET
    period_start = EXCLUDED.period_start,
    period_end = EXCLUDED.period_end,
    gross_revenue_attributed_rupees = EXCLUDED.gross_revenue_attributed_rupees,
    payouts_received_rupees = EXCLUDED.payouts_received_rupees,
    parts_consumed_rupees = EXCLUDED.parts_consumed_rupees,
    travel_expense_rupees = EXCLUDED.travel_expense_rupees,
    equipment_kit_amortization_rupees = EXCLUDED.equipment_kit_amortization_rupees,
    training_cost_rupees = EXCLUDED.training_cost_rupees,
    net_engineer_profit_rupees = EXCLUDED.net_engineer_profit_rupees,
    gross_margin_pct = EXCLUDED.gross_margin_pct,
    generated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_pnl_record_snapshot(uuid, text, date, date, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_pnl_record_snapshot(uuid, text, date, date, numeric, numeric, numeric, numeric, numeric, numeric) TO authenticated;

-- =========================================================================
-- RPC 6: log_founder_engineer_pnl_bulk_compute_period
-- Computes period snapshots for ALL engineers from engineer_payouts table
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_pnl_bulk_compute_period(text, date, date);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_pnl_bulk_compute_period(
  p_period_label text,
  p_period_start date,
  p_period_end date
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec record;
  v_count int := 0;
  v_payouts numeric;
  v_net numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_period_label IS NULL OR length(trim(p_period_label)) = 0 THEN
    RAISE EXCEPTION 'period_label required' USING ERRCODE = '22023';
  END IF;
  IF p_period_start IS NULL OR p_period_end IS NULL THEN
    RAISE EXCEPTION 'period_start and period_end required' USING ERRCODE = '22023';
  END IF;

  FOR v_rec IN
    SELECT DISTINCT engineer_user_id
    FROM public.engineer_payouts
    WHERE engineer_user_id IS NOT NULL
      AND created_at::date BETWEEN p_period_start AND p_period_end
  LOOP
    SELECT COALESCE(SUM(amount_rupees), 0) INTO v_payouts
    FROM public.engineer_payouts
    WHERE engineer_user_id = v_rec.engineer_user_id
      AND created_at::date BETWEEN p_period_start AND p_period_end;

    v_net := v_payouts;

    INSERT INTO public.founder_engineer_personal_pnl_snapshots (
      engineer_user_id, period_label, period_start, period_end,
      gross_revenue_attributed_rupees, payouts_received_rupees,
      net_engineer_profit_rupees, gross_margin_pct
    )
    VALUES (
      v_rec.engineer_user_id, p_period_label, p_period_start, p_period_end,
      v_payouts, v_payouts, v_net, NULL
    )
    ON CONFLICT (engineer_user_id, period_label) DO UPDATE SET
      period_start = EXCLUDED.period_start,
      period_end = EXCLUDED.period_end,
      gross_revenue_attributed_rupees = EXCLUDED.gross_revenue_attributed_rupees,
      payouts_received_rupees = EXCLUDED.payouts_received_rupees,
      net_engineer_profit_rupees = EXCLUDED.net_engineer_profit_rupees,
      generated_at = now();

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_pnl_bulk_compute_period(text, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_pnl_bulk_compute_period(text, date, date) TO authenticated;

COMMIT;