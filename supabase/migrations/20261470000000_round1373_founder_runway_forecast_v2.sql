BEGIN;
-- r1373 — /founder-runway-forecast-v2 — scenario planning (base/upside/downside/stress).

CREATE TABLE IF NOT EXISTS public.founder_runway_forecast_scenarios (
  id                                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_label                    text NOT NULL UNIQUE,
  scenario_kind                     text NOT NULL CHECK (scenario_kind IN ('base','upside','downside','stress')),
  assumed_monthly_burn_rupees       numeric NOT NULL CHECK (assumed_monthly_burn_rupees >= 0),
  assumed_monthly_inflow_rupees     numeric NOT NULL CHECK (assumed_monthly_inflow_rupees >= 0),
  assumed_starting_cash_rupees      numeric,
  assumed_growth_pct_monthly        numeric DEFAULT 0,
  assumed_churn_pct_monthly         numeric DEFAULT 0,
  valid_from                        date,
  valid_to                          date,
  notes                             text,
  is_active                         boolean DEFAULT true,
  created_by                        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at                        timestamptz NOT NULL DEFAULT now(),
  updated_at                        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_founder_runway_scenarios_kind ON public.founder_runway_forecast_scenarios(scenario_kind, is_active);
CREATE INDEX IF NOT EXISTS idx_founder_runway_scenarios_created ON public.founder_runway_forecast_scenarios(created_at DESC);

ALTER TABLE public.founder_runway_forecast_scenarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_runway_scenarios_no_direct ON public.founder_runway_forecast_scenarios;
CREATE POLICY founder_runway_scenarios_no_direct ON public.founder_runway_forecast_scenarios FOR ALL USING (false);
REVOKE ALL ON public.founder_runway_forecast_scenarios FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.founder_runway_forecast_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_runway_forecast_v2_summary()
RETURNS TABLE (
  current_cash_balance_rupees       numeric,
  days_since_snapshot               int,
  base_runway_months                numeric,
  base_zero_cash_date               date,
  upside_runway_months              numeric,
  downside_runway_months            numeric,
  stress_runway_months              numeric,
  actual_burn_last_30d_rupees       numeric,
  actual_inflow_last_30d_rupees     numeric,
  actual_net_last_30d_rupees        numeric,
  burn_vs_base_variance_pct         numeric,
  scenarios_active_count            bigint,
  longest_runway_scenario_label     text,
  shortest_runway_scenario_label    text,
  newest_scenario_at                timestamptz,
  generated_at                      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cash numeric := 0; v_snap_date date := NULL; v_days_since int := NULL;
  v_base_burn numeric := 0; v_upside_burn numeric := 0; v_downside_burn numeric := 0; v_stress_burn numeric := 0;
  v_base_inflow numeric := 0; v_upside_inflow numeric := 0; v_downside_inflow numeric := 0; v_stress_inflow numeric := 0;
  v_base_runway numeric := NULL; v_upside_runway numeric := NULL; v_downside_runway numeric := NULL; v_stress_runway numeric := NULL;
  v_zero_date date := NULL;
  v_actual_burn numeric := 0; v_actual_inflow numeric := 0;
  v_variance numeric := 0;
  v_longest text := NULL; v_shortest text := NULL;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT cash_balance_rupees, snapshot_date INTO v_cash, v_snap_date
  FROM public.founder_cash_position_snapshots ORDER BY snapshot_date DESC LIMIT 1;
  IF v_snap_date IS NOT NULL THEN
    v_days_since := greatest(0, (current_date - v_snap_date)::int);
  END IF;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_base_burn, v_base_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='base' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_upside_burn, v_upside_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='upside' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_downside_burn, v_downside_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='downside' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  SELECT assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees
  INTO v_stress_burn, v_stress_inflow
  FROM public.founder_runway_forecast_scenarios
  WHERE scenario_kind='stress' AND is_active=true
  ORDER BY created_at DESC LIMIT 1;

  IF v_cash > 0 AND coalesce(v_base_burn, 0) > coalesce(v_base_inflow, 0) THEN
    v_base_runway := round(v_cash / (v_base_burn - v_base_inflow), 2);
    v_zero_date := coalesce(v_snap_date, current_date) + (v_base_runway * 30)::int;
  END IF;
  IF v_cash > 0 AND coalesce(v_upside_burn, 0) > coalesce(v_upside_inflow, 0) THEN
    v_upside_runway := round(v_cash / (v_upside_burn - v_upside_inflow), 2);
  END IF;
  IF v_cash > 0 AND coalesce(v_downside_burn, 0) > coalesce(v_downside_inflow, 0) THEN
    v_downside_runway := round(v_cash / (v_downside_burn - v_downside_inflow), 2);
  END IF;
  IF v_cash > 0 AND coalesce(v_stress_burn, 0) > coalesce(v_stress_inflow, 0) THEN
    v_stress_runway := round(v_cash / (v_stress_burn - v_stress_inflow), 2);
  END IF;

  SELECT coalesce(sum(amount_rupees), 0) INTO v_actual_burn
  FROM public.engineer_payouts
  WHERE status = 'processed' AND created_at >= now() - interval '30 days';
  SELECT v_actual_burn + coalesce(sum(total_amount), 0) INTO v_actual_burn
  FROM public.spare_part_orders
  WHERE coalesce(payment_status, '') = 'paid' AND created_at >= now() - interval '30 days';

  SELECT coalesce(sum(amount_rupees), 0) INTO v_actual_inflow
  FROM public.payments
  WHERE status = 'captured' AND created_at >= now() - interval '30 days';

  IF coalesce(v_base_burn, 0) > 0 THEN
    v_variance := round(((v_actual_burn - v_base_burn) / v_base_burn) * 100, 2);
  END IF;

  SELECT scenario_label INTO v_longest
  FROM (
    SELECT scenario_label, assumed_starting_cash_rupees, assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees,
           CASE WHEN assumed_monthly_burn_rupees > assumed_monthly_inflow_rupees
                THEN coalesce(assumed_starting_cash_rupees, v_cash) / (assumed_monthly_burn_rupees - assumed_monthly_inflow_rupees)
                ELSE 999::numeric END AS rw
    FROM public.founder_runway_forecast_scenarios WHERE is_active=true
  ) t ORDER BY rw DESC LIMIT 1;

  SELECT scenario_label INTO v_shortest
  FROM (
    SELECT scenario_label, assumed_starting_cash_rupees, assumed_monthly_burn_rupees, assumed_monthly_inflow_rupees,
           CASE WHEN assumed_monthly_burn_rupees > assumed_monthly_inflow_rupees
                THEN coalesce(assumed_starting_cash_rupees, v_cash) / (assumed_monthly_burn_rupees - assumed_monthly_inflow_rupees)
                ELSE 999::numeric END AS rw
    FROM public.founder_runway_forecast_scenarios WHERE is_active=true
  ) t ORDER BY rw ASC LIMIT 1;

  RETURN QUERY SELECT
    v_cash, v_days_since,
    v_base_runway, v_zero_date,
    v_upside_runway, v_downside_runway, v_stress_runway,
    round(v_actual_burn, 2), round(v_actual_inflow, 2), round(v_actual_inflow - v_actual_burn, 2),
    v_variance,
    (SELECT count(*) FROM public.founder_runway_forecast_scenarios WHERE is_active=true)::bigint,
    coalesce(v_longest, '(none)'), coalesce(v_shortest, '(none)'),
    (SELECT max(created_at) FROM public.founder_runway_forecast_scenarios),
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_runway_forecast_v2_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_runway_forecast_v2_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_runway_forecast_v2_scenarios_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_runway_forecast_v2_scenarios_recent(p_kind text DEFAULT NULL, p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid, scenario_label text, scenario_kind text,
  assumed_monthly_burn_rupees numeric, assumed_monthly_inflow_rupees numeric,
  assumed_starting_cash_rupees numeric, assumed_growth_pct_monthly numeric,
  assumed_churn_pct_monthly numeric, is_active boolean, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_label, s.scenario_kind, s.assumed_monthly_burn_rupees,
         s.assumed_monthly_inflow_rupees, s.assumed_starting_cash_rupees,
         s.assumed_growth_pct_monthly, s.assumed_churn_pct_monthly,
         s.is_active, s.created_at
  FROM public.founder_runway_forecast_scenarios s
  WHERE (p_kind IS NULL OR s.scenario_kind = p_kind)
  ORDER BY s.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 20), 100));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_runway_forecast_v2_scenarios_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_runway_forecast_v2_scenarios_recent(text, int) TO authenticated;

COMMIT;
