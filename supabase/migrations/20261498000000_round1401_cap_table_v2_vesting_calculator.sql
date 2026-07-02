BEGIN;
-- Round 1401 — Cap Table v2 + Vesting Calculator + Dilution Model
-- Extends r1335 founder_cap_table_shareholders + founder_cap_table_rounds.
-- 2 tables · 8 RPCs · founder-only via is_founder() gate.



-- ============================================================================
-- TABLE 1: founder_cap_table_vesting_schedules
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_cap_table_vesting_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shareholder_id uuid NOT NULL REFERENCES public.founder_cap_table_shareholders(id) ON DELETE CASCADE,
  vesting_kind text NOT NULL CHECK (vesting_kind IN ('time_based','milestone_based','cliff_only','accelerated','double_trigger')),
  total_shares_to_vest bigint NOT NULL CHECK (total_shares_to_vest > 0),
  cliff_months int NOT NULL DEFAULT 0 CHECK (cliff_months >= 0),
  vesting_period_months int NOT NULL DEFAULT 48 CHECK (vesting_period_months > 0),
  vesting_start_date date NOT NULL,
  vesting_end_date date, -- computed at insert via trigger/RPC (Postgres GENERATED can't cast interval w/ mutable expr)
  acceleration_trigger text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_capv2_vesting_shareholder ON public.founder_cap_table_vesting_schedules(shareholder_id);
CREATE INDEX IF NOT EXISTS idx_capv2_vesting_start ON public.founder_cap_table_vesting_schedules(vesting_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_capv2_vesting_kind ON public.founder_cap_table_vesting_schedules(vesting_kind);

ALTER TABLE public.founder_cap_table_vesting_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS capv2_vesting_founder_all ON public.founder_cap_table_vesting_schedules;
CREATE POLICY capv2_vesting_founder_all ON public.founder_cap_table_vesting_schedules
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: founder_cap_table_dilution_scenarios
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_cap_table_dilution_scenarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_label text NOT NULL UNIQUE,
  scenario_kind text NOT NULL CHECK (scenario_kind IN ('next_round_seed','next_round_seriesA','next_round_seriesB','esop_top_up','convertible_note_conversion','secondary_buyout')),
  raise_amount_rupees numeric NOT NULL CHECK (raise_amount_rupees >= 0),
  pre_money_valuation_rupees numeric NOT NULL CHECK (pre_money_valuation_rupees > 0),
  new_esop_pct_added numeric NOT NULL DEFAULT 0 CHECK (new_esop_pct_added >= 0 AND new_esop_pct_added <= 100),
  projected_dilution_pct numeric GENERATED ALWAYS AS (
    raise_amount_rupees / (pre_money_valuation_rupees + raise_amount_rupees) * 100
  ) STORED,
  founder_dilution_pct numeric,
  employee_dilution_pct numeric,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_capv2_scenarios_kind ON public.founder_cap_table_dilution_scenarios(scenario_kind);
CREATE INDEX IF NOT EXISTS idx_capv2_scenarios_created ON public.founder_cap_table_dilution_scenarios(created_at DESC);

ALTER TABLE public.founder_cap_table_dilution_scenarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS capv2_scenarios_founder_all ON public.founder_cap_table_dilution_scenarios;
CREATE POLICY capv2_scenarios_founder_all ON public.founder_cap_table_dilution_scenarios
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_cap_table_v2_summary — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_cap_table_v2_summary()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_today date := v_now::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN jsonb_build_object(
    'total_vesting_schedules', (SELECT COUNT(*) FROM founder_cap_table_vesting_schedules),
    'time_based_schedules', (SELECT COUNT(*) FROM founder_cap_table_vesting_schedules WHERE vesting_kind='time_based'),
    'milestone_based_schedules', (SELECT COUNT(*) FROM founder_cap_table_vesting_schedules WHERE vesting_kind='milestone_based'),
    'cliff_only_schedules', (SELECT COUNT(*) FROM founder_cap_table_vesting_schedules WHERE vesting_kind='cliff_only'),
    'total_shares_under_vesting', COALESCE((SELECT SUM(total_shares_to_vest) FROM founder_cap_table_vesting_schedules), 0),
    'total_shares_vested_to_date', COALESCE((
      SELECT SUM(
        CASE
          WHEN v_today < vesting_start_date + (cliff_months || ' months')::interval THEN 0
          WHEN v_today >= vesting_end_date THEN total_shares_to_vest
          ELSE (total_shares_to_vest::numeric *
            EXTRACT(EPOCH FROM (v_today::timestamptz - vesting_start_date::timestamptz)) /
            EXTRACT(EPOCH FROM (vesting_end_date::timestamptz - vesting_start_date::timestamptz))
          )::bigint
        END
      )
      FROM founder_cap_table_vesting_schedules
    ), 0),
    'total_shares_unvested', COALESCE((
      SELECT SUM(total_shares_to_vest) - SUM(
        CASE
          WHEN v_today < vesting_start_date + (cliff_months || ' months')::interval THEN 0
          WHEN v_today >= vesting_end_date THEN total_shares_to_vest
          ELSE (total_shares_to_vest::numeric *
            EXTRACT(EPOCH FROM (v_today::timestamptz - vesting_start_date::timestamptz)) /
            EXTRACT(EPOCH FROM (vesting_end_date::timestamptz - vesting_start_date::timestamptz))
          )::bigint
        END
      )
      FROM founder_cap_table_vesting_schedules
    ), 0),
    'cliffs_in_next_90d', (
      SELECT COUNT(*) FROM founder_cap_table_vesting_schedules
      WHERE (vesting_start_date + (cliff_months || ' months')::interval)::date BETWEEN v_today AND v_today + 90
    ),
    'cliffs_in_next_30d', (
      SELECT COUNT(*) FROM founder_cap_table_vesting_schedules
      WHERE (vesting_start_date + (cliff_months || ' months')::interval)::date BETWEEN v_today AND v_today + 30
    ),
    'fully_vested_count', (
      SELECT COUNT(*) FROM founder_cap_table_vesting_schedules WHERE v_today >= vesting_end_date
    ),
    'total_dilution_scenarios', (SELECT COUNT(*) FROM founder_cap_table_dilution_scenarios),
    'seed_scenarios', (SELECT COUNT(*) FROM founder_cap_table_dilution_scenarios WHERE scenario_kind='next_round_seed'),
    'seriesA_scenarios', (SELECT COUNT(*) FROM founder_cap_table_dilution_scenarios WHERE scenario_kind='next_round_seriesA'),
    'avg_projected_dilution_pct', COALESCE((SELECT ROUND(AVG(projected_dilution_pct)::numeric, 2) FROM founder_cap_table_dilution_scenarios), 0),
    'max_projected_dilution_pct', COALESCE((SELECT ROUND(MAX(projected_dilution_pct)::numeric, 2) FROM founder_cap_table_dilution_scenarios), 0),
    'total_raise_modeled_rupees', COALESCE((SELECT SUM(raise_amount_rupees) FROM founder_cap_table_dilution_scenarios), 0),
    'avg_pre_money_rupees', COALESCE((SELECT ROUND(AVG(pre_money_valuation_rupees)::numeric, 0) FROM founder_cap_table_dilution_scenarios), 0)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_v2_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_v2_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_cap_table_v2_vesting_status — per-shareholder rollup
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_v2_vesting_status();
CREATE OR REPLACE FUNCTION public.founder_cap_table_v2_vesting_status()
RETURNS TABLE (
  schedule_id uuid,
  shareholder_id uuid,
  shareholder_name text,
  shareholder_kind text,
  vesting_kind text,
  total_shares bigint,
  vested_shares bigint,
  unvested_shares bigint,
  vested_pct numeric,
  cliff_passed boolean,
  vesting_start_date date,
  vesting_end_date date,
  months_remaining int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := now()::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  SELECT
    vs.id,
    sh.id,
    sh.shareholder_name,
    sh.shareholder_kind,
    vs.vesting_kind,
    vs.total_shares_to_vest,
    CASE
      WHEN v_today < vs.vesting_start_date + (vs.cliff_months || ' months')::interval THEN 0::bigint
      WHEN v_today >= vs.vesting_end_date THEN vs.total_shares_to_vest
      ELSE (vs.total_shares_to_vest::numeric *
        EXTRACT(EPOCH FROM (v_today::timestamptz - vs.vesting_start_date::timestamptz)) /
        EXTRACT(EPOCH FROM (vs.vesting_end_date::timestamptz - vs.vesting_start_date::timestamptz))
      )::bigint
    END AS vested_shares,
    vs.total_shares_to_vest - CASE
      WHEN v_today < vs.vesting_start_date + (vs.cliff_months || ' months')::interval THEN 0::bigint
      WHEN v_today >= vs.vesting_end_date THEN vs.total_shares_to_vest
      ELSE (vs.total_shares_to_vest::numeric *
        EXTRACT(EPOCH FROM (v_today::timestamptz - vs.vesting_start_date::timestamptz)) /
        EXTRACT(EPOCH FROM (vs.vesting_end_date::timestamptz - vs.vesting_start_date::timestamptz))
      )::bigint
    END AS unvested_shares,
    CASE
      WHEN v_today < vs.vesting_start_date + (vs.cliff_months || ' months')::interval THEN 0::numeric
      WHEN v_today >= vs.vesting_end_date THEN 100::numeric
      ELSE ROUND((EXTRACT(EPOCH FROM (v_today::timestamptz - vs.vesting_start_date::timestamptz)) /
        EXTRACT(EPOCH FROM (vs.vesting_end_date::timestamptz - vs.vesting_start_date::timestamptz)) * 100)::numeric, 2)
    END AS vested_pct,
    v_today >= (vs.vesting_start_date + (vs.cliff_months || ' months')::interval)::date AS cliff_passed,
    vs.vesting_start_date,
    vs.vesting_end_date,
    GREATEST(0, ((vs.vesting_end_date - v_today)::int / 30))::int AS months_remaining
  FROM founder_cap_table_vesting_schedules vs
  JOIN founder_cap_table_shareholders sh ON sh.id = vs.shareholder_id
  ORDER BY vs.vesting_start_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_v2_vesting_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_v2_vesting_status() TO authenticated;

-- ============================================================================
-- RPC 3: founder_cap_table_v2_scenarios_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_v2_scenarios_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_cap_table_v2_scenarios_recent(p_kind text DEFAULT NULL, p_limit int DEFAULT 25)
RETURNS SETOF public.founder_cap_table_dilution_scenarios
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM founder_cap_table_dilution_scenarios
    WHERE p_kind IS NULL OR scenario_kind = p_kind
    ORDER BY created_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_v2_scenarios_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_v2_scenarios_recent(text, int) TO authenticated;

-- ============================================================================
-- RPC 4: founder_cap_table_v2_upcoming_cliffs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_v2_upcoming_cliffs(int);
CREATE OR REPLACE FUNCTION public.founder_cap_table_v2_upcoming_cliffs(p_days int DEFAULT 90)
RETURNS TABLE (
  schedule_id uuid,
  shareholder_name text,
  shareholder_kind text,
  cliff_date date,
  days_until_cliff int,
  shares_at_cliff bigint,
  vesting_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := now()::date;
  v_window int := GREATEST(1, LEAST(p_days, 365));
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  SELECT
    vs.id,
    sh.shareholder_name,
    sh.shareholder_kind,
    (vs.vesting_start_date + (vs.cliff_months || ' months')::interval)::date AS cliff_date,
    ((vs.vesting_start_date + (vs.cliff_months || ' months')::interval)::date - v_today)::int AS days_until_cliff,
    -- Shares released at cliff = pro-rata through cliff
    CASE
      WHEN vs.cliff_months = 0 THEN 0::bigint
      ELSE (vs.total_shares_to_vest::numeric * vs.cliff_months / vs.vesting_period_months)::bigint
    END AS shares_at_cliff,
    vs.vesting_kind
  FROM founder_cap_table_vesting_schedules vs
  JOIN founder_cap_table_shareholders sh ON sh.id = vs.shareholder_id
  WHERE (vs.vesting_start_date + (vs.cliff_months || ' months')::interval)::date BETWEEN v_today AND v_today + v_window
  ORDER BY cliff_date ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_v2_upcoming_cliffs(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_v2_upcoming_cliffs(int) TO authenticated;

-- ============================================================================
-- RPC 5: log_founder_capv2_register_vesting
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_capv2_register_vesting(uuid, text, bigint, int, int, date, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_capv2_register_vesting(
  p_shareholder_id uuid,
  p_vesting_kind text,
  p_total_shares bigint,
  p_cliff_months int,
  p_vesting_period_months int,
  p_vesting_start_date date,
  p_acceleration_trigger text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO founder_cap_table_vesting_schedules(
    shareholder_id, vesting_kind, total_shares_to_vest, cliff_months,
    vesting_period_months, vesting_start_date, acceleration_trigger, notes
  )
  VALUES (
    p_shareholder_id, p_vesting_kind, p_total_shares, COALESCE(p_cliff_months, 0),
    COALESCE(p_vesting_period_months, 48), p_vesting_start_date, p_acceleration_trigger, p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_capv2_register_vesting(uuid, text, bigint, int, int, date, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_capv2_register_vesting(uuid, text, bigint, int, int, date, text, text) TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_capv2_register_scenario
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_capv2_register_scenario(text, text, numeric, numeric, numeric, numeric, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_capv2_register_scenario(
  p_scenario_label text,
  p_scenario_kind text,
  p_raise_amount_rupees numeric,
  p_pre_money_valuation_rupees numeric,
  p_new_esop_pct_added numeric DEFAULT 0,
  p_founder_dilution_pct numeric DEFAULT NULL,
  p_employee_dilution_pct numeric DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO founder_cap_table_dilution_scenarios(
    scenario_label, scenario_kind, raise_amount_rupees, pre_money_valuation_rupees,
    new_esop_pct_added, founder_dilution_pct, employee_dilution_pct, notes
  )
  VALUES (
    p_scenario_label, p_scenario_kind, p_raise_amount_rupees, p_pre_money_valuation_rupees,
    COALESCE(p_new_esop_pct_added, 0), p_founder_dilution_pct, p_employee_dilution_pct, p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_capv2_register_scenario(text, text, numeric, numeric, numeric, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_capv2_register_scenario(text, text, numeric, numeric, numeric, numeric, numeric, text) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_capv2_simulate_round
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_capv2_simulate_round(text, text, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_capv2_simulate_round(
  p_scenario_label text,
  p_scenario_kind text,
  p_raise_amount_rupees numeric,
  p_pre_money_valuation_rupees numeric,
  p_new_esop_pct_added numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_dilution_pct numeric;
  v_post_money numeric;
  v_founder_dilution numeric;
  v_employee_dilution numeric;
  v_founder_pre_pct numeric;
  v_employee_pre_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  v_post_money := p_pre_money_valuation_rupees + p_raise_amount_rupees;
  v_dilution_pct := p_raise_amount_rupees / v_post_money * 100;

  -- Compute founder + employee pre-round %
  SELECT COALESCE(SUM(share_pct), 0) INTO v_founder_pre_pct
  FROM founder_cap_table_shareholders WHERE shareholder_kind='founder';
  SELECT COALESCE(SUM(share_pct), 0) INTO v_employee_pre_pct
  FROM founder_cap_table_shareholders WHERE shareholder_kind IN ('employee','esop_pool');

  v_founder_dilution := v_founder_pre_pct * v_dilution_pct / 100;
  v_employee_dilution := v_employee_pre_pct * v_dilution_pct / 100 + COALESCE(p_new_esop_pct_added, 0);

  INSERT INTO founder_cap_table_dilution_scenarios(
    scenario_label, scenario_kind, raise_amount_rupees, pre_money_valuation_rupees,
    new_esop_pct_added, founder_dilution_pct, employee_dilution_pct, notes
  )
  VALUES (
    p_scenario_label, p_scenario_kind, p_raise_amount_rupees, p_pre_money_valuation_rupees,
    COALESCE(p_new_esop_pct_added, 0), v_founder_dilution, v_employee_dilution,
    'auto-simulated by log_founder_capv2_simulate_round'
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'scenario_id', v_id,
    'projected_dilution_pct', ROUND(v_dilution_pct, 2),
    'post_money_rupees', v_post_money,
    'founder_dilution_pct', ROUND(v_founder_dilution, 2),
    'employee_dilution_pct', ROUND(v_employee_dilution, 2),
    'founder_pre_pct', v_founder_pre_pct,
    'employee_pre_pct', v_employee_pre_pct
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_capv2_simulate_round(text, text, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_capv2_simulate_round(text, text, numeric, numeric, numeric) TO authenticated;

-- ============================================================================
-- RPC 8: founder_cap_table_v2_calculate_vested_shares
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_v2_calculate_vested_shares(uuid);
CREATE OR REPLACE FUNCTION public.founder_cap_table_v2_calculate_vested_shares(p_shareholder_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := now()::date;
  v_total bigint := 0;
  v_vested bigint := 0;
  v_unvested bigint := 0;
  v_schedule_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT
    COALESCE(SUM(total_shares_to_vest), 0),
    COALESCE(SUM(
      CASE
        WHEN v_today < vesting_start_date + (cliff_months || ' months')::interval THEN 0::bigint
        WHEN v_today >= vesting_end_date THEN total_shares_to_vest
        ELSE (total_shares_to_vest::numeric *
          EXTRACT(EPOCH FROM (v_today::timestamptz - vesting_start_date::timestamptz)) /
          EXTRACT(EPOCH FROM (vesting_end_date::timestamptz - vesting_start_date::timestamptz))
        )::bigint
      END
    ), 0),
    COUNT(*)
  INTO v_total, v_vested, v_schedule_count
  FROM founder_cap_table_vesting_schedules
  WHERE shareholder_id = p_shareholder_id;

  v_unvested := v_total - v_vested;

  RETURN jsonb_build_object(
    'shareholder_id', p_shareholder_id,
    'schedule_count', v_schedule_count,
    'total_shares', v_total,
    'vested_shares', v_vested,
    'unvested_shares', v_unvested,
    'vested_pct', CASE WHEN v_total > 0 THEN ROUND((v_vested::numeric / v_total * 100), 2) ELSE 0 END,
    'as_of_date', v_today
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_v2_calculate_vested_shares(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_v2_calculate_vested_shares(uuid) TO authenticated;

COMMIT;