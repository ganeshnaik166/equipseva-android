BEGIN;

-- =========================================================
-- r1625 — Founder Investor 12-Month Forecast
-- Projected MRR + ARR + burn + runway under 3 scenarios
-- =========================================================

CREATE TABLE IF NOT EXISTS investor_forecast_scenarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_code text NOT NULL CHECK (scenario_code IN ('conservative','base','aggressive')),
  label text NOT NULL,
  growth_pct_monthly numeric(6,3) NOT NULL,
  churn_pct_monthly numeric(6,3) NOT NULL,
  burn_inflation_pct_monthly numeric(6,3) NOT NULL,
  arpu_rupees integer NOT NULL,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scenario_code)
);

ALTER TABLE investor_forecast_scenarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_forecast_scenarios ON investor_forecast_scenarios;
CREATE POLICY founder_only_investor_forecast_scenarios
  ON investor_forecast_scenarios
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS investor_forecast_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_code text NOT NULL CHECK (scenario_code IN ('conservative','base','aggressive')),
  picked_for_investor boolean NOT NULL DEFAULT false,
  picked_at timestamptz,
  picked_by uuid,
  starting_mrr_rupees integer NOT NULL,
  starting_cash_rupees integer NOT NULL,
  monthly_burn_rupees integer NOT NULL,
  projection jsonb NOT NULL DEFAULT '[]'::jsonb,
  runway_months integer NOT NULL DEFAULT 0,
  arr_12mo_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE investor_forecast_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_forecast_snapshots ON investor_forecast_snapshots;
CREATE POLICY founder_only_investor_forecast_snapshots
  ON investor_forecast_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_invfx_snapshots_scenario ON investor_forecast_snapshots(scenario_code, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invfx_snapshots_picked ON investor_forecast_snapshots(picked_for_investor) WHERE picked_for_investor;

-- Seed defaults (idempotent)
INSERT INTO investor_forecast_scenarios (scenario_code, label, growth_pct_monthly, churn_pct_monthly, burn_inflation_pct_monthly, arpu_rupees, notes)
VALUES
  ('conservative','Conservative', 4.0, 3.0, 1.5, 3500, 'Slow rollout, higher churn'),
  ('base',        'Base Case',    9.0, 2.0, 1.0, 4200, 'Current trajectory'),
  ('aggressive',  'Aggressive',  16.0, 1.5, 0.5, 4800, 'Two new chains land Q3')
ON CONFLICT (scenario_code) DO NOTHING;

-- =========================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =========================================================

CREATE OR REPLACE FUNCTION log_founder_forecast_scenario_update(p_scenario_code text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'forecast_scenario_update',
          jsonb_build_object('scenario_code', p_scenario_code, 'after', p_after), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_forecast_scenario_update(text, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_forecast_scenario_update(text, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_forecast_snapshot_created(p_snapshot_id uuid, p_scenario_code text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'forecast_snapshot_created',
          jsonb_build_object('snapshot_id', p_snapshot_id, 'scenario_code', p_scenario_code), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_forecast_snapshot_created(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_forecast_snapshot_created(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_forecast_pick(p_snapshot_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'forecast_picked_for_investor',
          jsonb_build_object('snapshot_id', p_snapshot_id), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_forecast_pick(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_forecast_pick(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_forecast_viewed(p_scenario_code text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'forecast_viewed',
          jsonb_build_object('scenario_code', p_scenario_code), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_forecast_viewed(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_forecast_viewed(text) TO authenticated;

-- =========================================================
-- READ RPCs (STABLE SECDEF)
-- =========================================================

CREATE OR REPLACE FUNCTION founder_forecast_scenarios_list()
RETURNS TABLE (
  id uuid,
  scenario_code text,
  label text,
  growth_pct_monthly numeric,
  churn_pct_monthly numeric,
  burn_inflation_pct_monthly numeric,
  arpu_rupees integer,
  notes text,
  is_active boolean,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scenario_code, s.label, s.growth_pct_monthly, s.churn_pct_monthly,
           s.burn_inflation_pct_monthly, s.arpu_rupees, s.notes, s.is_active, s.updated_at
    FROM investor_forecast_scenarios s
    ORDER BY CASE s.scenario_code WHEN 'conservative' THEN 1 WHEN 'base' THEN 2 ELSE 3 END;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_scenarios_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_scenarios_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_forecast_current_state()
RETURNS TABLE (
  active_amc_count integer,
  starting_mrr_rupees integer,
  starting_arr_rupees bigint,
  trailing_90d_payout_rupees bigint,
  monthly_burn_rupees integer,
  estimated_cash_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_amc_count integer := 0;
  v_mrr integer := 0;
  v_payouts bigint := 0;
  v_burn integer := 0;
  v_cash integer := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int, COALESCE(SUM(monthly_fee_rupees),0)::int
    INTO v_amc_count, v_mrr
  FROM amc_contracts
  WHERE activated_at IS NOT NULL AND deactivated_at IS NULL;

  SELECT COALESCE(SUM(amount_rupees),0)::bigint
    INTO v_payouts
  FROM engineer_payouts
  WHERE paid_at IS NOT NULL AND paid_at >= now() - interval '90 days';

  v_burn := GREATEST(50000, (v_payouts / 3)::int + 30000);
  v_cash := 2500000;

  RETURN QUERY SELECT v_amc_count, v_mrr, (v_mrr * 12)::bigint, v_payouts, v_burn, v_cash;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_current_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_current_state() TO authenticated;

CREATE OR REPLACE FUNCTION founder_forecast_project(p_scenario_code text)
RETURNS TABLE (
  month_index integer,
  mrr_rupees integer,
  arr_rupees bigint,
  burn_rupees integer,
  cash_remaining_rupees bigint,
  is_runway_break boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_growth numeric;
  v_churn numeric;
  v_burn_inf numeric;
  v_mrr numeric;
  v_burn numeric;
  v_cash numeric;
  v_i integer;
  v_break boolean := false;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT growth_pct_monthly, churn_pct_monthly, burn_inflation_pct_monthly
    INTO v_growth, v_churn, v_burn_inf
  FROM investor_forecast_scenarios WHERE scenario_code = p_scenario_code;

  IF v_growth IS NULL THEN RAISE EXCEPTION 'scenario not found'; END IF;

  SELECT starting_mrr_rupees, monthly_burn_rupees, estimated_cash_rupees
    INTO v_mrr, v_burn, v_cash
  FROM founder_forecast_current_state();

  FOR v_i IN 1..12 LOOP
    v_mrr  := v_mrr * (1 + (v_growth - v_churn) / 100.0);
    v_burn := v_burn * (1 + v_burn_inf / 100.0);
    v_cash := v_cash + v_mrr - v_burn;
    IF v_cash < 0 AND NOT v_break THEN v_break := true; END IF;
    month_index := v_i;
    mrr_rupees := v_mrr::int;
    arr_rupees := (v_mrr * 12)::bigint;
    burn_rupees := v_burn::int;
    cash_remaining_rupees := v_cash::bigint;
    is_runway_break := v_break;
    RETURN NEXT;
  END LOOP;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_project(text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_project(text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_forecast_summary()
RETURNS TABLE (
  scenario_code text,
  label text,
  mrr_m12_rupees integer,
  arr_m12_rupees bigint,
  burn_m12_rupees integer,
  runway_months integer,
  net_cash_m12_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH scs AS (
      SELECT scenario_code, label FROM investor_forecast_scenarios ORDER BY 1
    ),
    proj AS (
      SELECT s.scenario_code, s.label, p.month_index, p.mrr_rupees, p.arr_rupees, p.burn_rupees, p.cash_remaining_rupees, p.is_runway_break
      FROM scs s
      CROSS JOIN LATERAL founder_forecast_project(s.scenario_code) p
    ),
    last_month AS (
      SELECT scenario_code, label, mrr_rupees AS mrr_m12, arr_rupees AS arr_m12,
             burn_rupees AS burn_m12, cash_remaining_rupees AS net_cash_m12
      FROM proj WHERE month_index = 12
    ),
    runway AS (
      SELECT scenario_code, MIN(month_index) AS break_month
      FROM proj WHERE is_runway_break
      GROUP BY scenario_code
    )
    SELECT lm.scenario_code, lm.label, lm.mrr_m12::int, lm.arr_m12, lm.burn_m12::int,
           COALESCE(r.break_month, 13)::int AS runway_months,
           lm.net_cash_m12
    FROM last_month lm
    LEFT JOIN runway r USING (scenario_code)
    ORDER BY CASE lm.scenario_code WHEN 'conservative' THEN 1 WHEN 'base' THEN 2 ELSE 3 END;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_forecast_snapshots_recent(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id uuid,
  scenario_code text,
  picked_for_investor boolean,
  starting_mrr_rupees integer,
  monthly_burn_rupees integer,
  runway_months integer,
  arr_12mo_rupees bigint,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scenario_code, s.picked_for_investor, s.starting_mrr_rupees,
           s.monthly_burn_rupees, s.runway_months, s.arr_12mo_rupees, s.created_at
    FROM investor_forecast_snapshots s
    ORDER BY s.created_at DESC
    LIMIT COALESCE(p_limit, 25);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_snapshots_recent(integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_snapshots_recent(integer) TO authenticated;

-- =========================================================
-- WRITE RPCs (VOLATILE SECDEF)
-- =========================================================

CREATE OR REPLACE FUNCTION founder_forecast_save_snapshot(p_scenario_code text, p_notes text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_mrr integer;
  v_burn integer;
  v_cash integer;
  v_proj jsonb;
  v_runway integer;
  v_arr bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT starting_mrr_rupees, monthly_burn_rupees, estimated_cash_rupees
    INTO v_mrr, v_burn, v_cash
  FROM founder_forecast_current_state();

  SELECT jsonb_agg(jsonb_build_object('m', month_index, 'mrr', mrr_rupees, 'arr', arr_rupees,
                                      'burn', burn_rupees, 'cash', cash_remaining_rupees,
                                      'break', is_runway_break) ORDER BY month_index)
    INTO v_proj
  FROM founder_forecast_project(p_scenario_code);

  SELECT COALESCE(MIN(month_index), 13), MAX(arr_rupees)
    INTO v_runway, v_arr
  FROM founder_forecast_project(p_scenario_code);

  INSERT INTO investor_forecast_snapshots (
    scenario_code, starting_mrr_rupees, starting_cash_rupees, monthly_burn_rupees,
    projection, runway_months, arr_12mo_rupees, notes, created_by
  ) VALUES (
    p_scenario_code, v_mrr, v_cash, v_burn, COALESCE(v_proj,'[]'::jsonb),
    COALESCE(v_runway,13), COALESCE(v_arr,0), p_notes, auth.uid()
  ) RETURNING id INTO v_id;

  PERFORM log_founder_forecast_snapshot_created(v_id, p_scenario_code);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_save_snapshot(text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_save_snapshot(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_forecast_pick_for_investor(p_snapshot_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_forecast_snapshots SET picked_for_investor = false WHERE picked_for_investor;
  UPDATE investor_forecast_snapshots
    SET picked_for_investor = true, picked_at = now(), picked_by = auth.uid()
    WHERE id = p_snapshot_id;
  PERFORM log_founder_forecast_pick(p_snapshot_id);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_forecast_pick_for_investor(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_forecast_pick_for_investor(uuid) TO authenticated;

COMMIT;