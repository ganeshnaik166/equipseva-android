BEGIN;

-- =========================================================================
-- Round 1560 — Founder Investor Allocation Simulator
-- Simulate per-investor allocations across multiple rounds.
-- Founder slider: this-round allocation vs reserved follow-on capacity.
-- MOIC predictor across exit scenarios.
-- =========================================================================

CREATE TABLE IF NOT EXISTS founder_investor_alloc_scenarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_name text NOT NULL,
  investor_name text NOT NULL,
  investor_type text NOT NULL CHECK (investor_type IN ('angel','seed_vc','series_a_vc','strategic','family_office','syndicate')),
  current_round_label text NOT NULL,
  current_round_size_rupees bigint NOT NULL CHECK (current_round_size_rupees > 0),
  current_pre_money_rupees bigint NOT NULL CHECK (current_pre_money_rupees > 0),
  requested_check_rupees bigint NOT NULL CHECK (requested_check_rupees > 0),
  this_round_allocation_rupees bigint NOT NULL DEFAULT 0 CHECK (this_round_allocation_rupees >= 0),
  reserved_followon_rupees bigint NOT NULL DEFAULT 0 CHECK (reserved_followon_rupees >= 0),
  followon_rounds_count int NOT NULL DEFAULT 2 CHECK (followon_rounds_count BETWEEN 0 AND 5),
  assumed_round_step_multiple numeric(6,2) NOT NULL DEFAULT 2.50 CHECK (assumed_round_step_multiple > 0),
  assumed_dilution_per_round_pct numeric(5,2) NOT NULL DEFAULT 18.00 CHECK (assumed_dilution_per_round_pct >= 0 AND assumed_dilution_per_round_pct < 100),
  exit_valuation_low_rupees bigint NOT NULL CHECK (exit_valuation_low_rupees > 0),
  exit_valuation_mid_rupees bigint NOT NULL CHECK (exit_valuation_mid_rupees > 0),
  exit_valuation_high_rupees bigint NOT NULL CHECK (exit_valuation_high_rupees > 0),
  notes text,
  is_locked boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fias_scen_name ON founder_investor_alloc_scenarios(scenario_name);
CREATE INDEX IF NOT EXISTS idx_fias_created_at ON founder_investor_alloc_scenarios(created_at DESC);

CREATE TABLE IF NOT EXISTS founder_investor_alloc_followons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id uuid NOT NULL REFERENCES founder_investor_alloc_scenarios(id) ON DELETE CASCADE,
  followon_round_label text NOT NULL,
  followon_seq int NOT NULL CHECK (followon_seq BETWEEN 1 AND 5),
  pro_rata_pct numeric(5,2) NOT NULL DEFAULT 100.00 CHECK (pro_rata_pct >= 0 AND pro_rata_pct <= 200),
  participate boolean NOT NULL DEFAULT true,
  override_check_rupees bigint CHECK (override_check_rupees IS NULL OR override_check_rupees >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scenario_id, followon_seq)
);

CREATE INDEX IF NOT EXISTS idx_fia_followons_scen ON founder_investor_alloc_followons(scenario_id);

ALTER TABLE founder_investor_alloc_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_alloc_followons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fias_founder_all ON founder_investor_alloc_scenarios;
CREATE POLICY fias_founder_all ON founder_investor_alloc_scenarios
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS fia_followons_founder_all ON founder_investor_alloc_followons;
CREATE POLICY fia_followons_founder_all ON founder_investor_alloc_followons
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- Helpers (VOLATILE SECDEF) — write to founder_action_log
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_investor_alloc_scenario_create(p_scenario_id uuid, p_scenario_name text, p_investor text, p_check_rupees bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_alloc_scenario_create',
    jsonb_build_object('scenario_id', p_scenario_id, 'scenario_name', p_scenario_name, 'investor', p_investor, 'check_rupees', p_check_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_alloc_scenario_create(uuid, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_alloc_scenario_create(uuid, text, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_alloc_slider_change(p_scenario_id uuid, p_this_round bigint, p_reserved bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_alloc_slider_change',
    jsonb_build_object('scenario_id', p_scenario_id, 'this_round_rupees', p_this_round, 'reserved_rupees', p_reserved));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_alloc_slider_change(uuid, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_alloc_slider_change(uuid, bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_alloc_lock(p_scenario_id uuid, p_locked boolean)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_alloc_lock',
    jsonb_build_object('scenario_id', p_scenario_id, 'locked', p_locked));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_alloc_lock(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_alloc_lock(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_investor_alloc_moic_view(p_scenario_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_alloc_moic_view',
    jsonb_build_object('scenario_id', p_scenario_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_alloc_moic_view(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_alloc_moic_view(uuid) TO authenticated;

-- =========================================================================
-- READ RPCs (STABLE SECDEF)
-- =========================================================================

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_kpis()
RETURNS TABLE(
  scenarios_total bigint,
  scenarios_locked bigint,
  investors_distinct bigint,
  rounds_distinct bigint,
  total_committed_rupees bigint,
  total_this_round_rupees bigint,
  total_reserved_rupees bigint,
  reserved_share_pct numeric,
  avg_check_rupees bigint,
  median_check_rupees bigint,
  largest_check_rupees bigint,
  smallest_check_rupees bigint,
  avg_moic_mid numeric,
  best_moic_mid numeric,
  worst_moic_mid numeric,
  scenarios_created_7d bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT s.*,
      (s.this_round_allocation_rupees + s.reserved_followon_rupees) AS committed,
      CASE WHEN s.this_round_allocation_rupees > 0 AND s.current_pre_money_rupees > 0
           THEN (s.this_round_allocation_rupees::numeric / (s.current_pre_money_rupees + s.current_round_size_rupees)::numeric)
           ELSE 0 END AS entry_ownership,
      power(1 - s.assumed_dilution_per_round_pct/100.0, s.followon_rounds_count) AS dilution_factor
    FROM founder_investor_alloc_scenarios s
  ),
  moic AS (
    SELECT b.id,
      CASE WHEN (b.this_round_allocation_rupees + b.reserved_followon_rupees) > 0
           THEN (b.entry_ownership * b.dilution_factor * b.exit_valuation_mid_rupees)::numeric
                / NULLIF((b.this_round_allocation_rupees + b.reserved_followon_rupees), 0)
           ELSE 0 END AS moic_mid
    FROM base b
  )
  SELECT
    (SELECT count(*) FROM founder_investor_alloc_scenarios),
    (SELECT count(*) FROM founder_investor_alloc_scenarios WHERE is_locked),
    (SELECT count(DISTINCT investor_name) FROM founder_investor_alloc_scenarios),
    (SELECT count(DISTINCT current_round_label) FROM founder_investor_alloc_scenarios),
    COALESCE((SELECT sum(committed)::bigint FROM base), 0),
    COALESCE((SELECT sum(this_round_allocation_rupees)::bigint FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT sum(reserved_followon_rupees)::bigint FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT round(100.0 * sum(reserved_followon_rupees)::numeric / NULLIF(sum(this_round_allocation_rupees + reserved_followon_rupees), 0), 1) FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT avg(requested_check_rupees)::bigint FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY requested_check_rupees)::bigint FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT max(requested_check_rupees) FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT min(requested_check_rupees) FROM founder_investor_alloc_scenarios), 0),
    COALESCE((SELECT round(avg(moic_mid), 2) FROM moic), 0),
    COALESCE((SELECT round(max(moic_mid), 2) FROM moic), 0),
    COALESCE((SELECT round(min(moic_mid), 2) FROM moic), 0),
    (SELECT count(*) FROM founder_investor_alloc_scenarios WHERE created_at >= now() - interval '7 days');
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_scenarios_list()
RETURNS TABLE(
  id uuid,
  scenario_name text,
  investor_name text,
  investor_type text,
  current_round_label text,
  requested_check_rupees bigint,
  this_round_allocation_rupees bigint,
  reserved_followon_rupees bigint,
  followon_rounds_count int,
  is_locked boolean,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.investor_name, s.investor_type, s.current_round_label,
         s.requested_check_rupees, s.this_round_allocation_rupees, s.reserved_followon_rupees,
         s.followon_rounds_count, s.is_locked, s.created_at
  FROM founder_investor_alloc_scenarios s
  ORDER BY s.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_scenarios_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_scenarios_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_moic_predictor()
RETURNS TABLE(
  scenario_id uuid,
  scenario_name text,
  investor_name text,
  entry_ownership_pct numeric,
  final_ownership_pct numeric,
  total_invested_rupees bigint,
  moic_low numeric,
  moic_mid numeric,
  moic_high numeric,
  proceeds_mid_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT s.id, s.scenario_name, s.investor_name,
      (s.this_round_allocation_rupees + s.reserved_followon_rupees) AS committed,
      CASE WHEN s.this_round_allocation_rupees > 0
           THEN (s.this_round_allocation_rupees::numeric / NULLIF((s.current_pre_money_rupees + s.current_round_size_rupees), 0)::numeric)
           ELSE 0 END AS entry_own,
      power(1 - s.assumed_dilution_per_round_pct/100.0, s.followon_rounds_count) AS dilution_factor,
      s.exit_valuation_low_rupees, s.exit_valuation_mid_rupees, s.exit_valuation_high_rupees
    FROM founder_investor_alloc_scenarios s
  )
  SELECT b.id, b.scenario_name, b.investor_name,
    round(b.entry_own * 100, 3),
    round(b.entry_own * b.dilution_factor * 100, 3),
    b.committed::bigint,
    CASE WHEN b.committed > 0 THEN round((b.entry_own * b.dilution_factor * b.exit_valuation_low_rupees)::numeric / b.committed, 2) ELSE 0 END,
    CASE WHEN b.committed > 0 THEN round((b.entry_own * b.dilution_factor * b.exit_valuation_mid_rupees)::numeric / b.committed, 2) ELSE 0 END,
    CASE WHEN b.committed > 0 THEN round((b.entry_own * b.dilution_factor * b.exit_valuation_high_rupees)::numeric / b.committed, 2) ELSE 0 END,
    (b.entry_own * b.dilution_factor * b.exit_valuation_mid_rupees)::bigint
  FROM base b
  ORDER BY b.committed DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_moic_predictor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_moic_predictor() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_followon_schedule()
RETURNS TABLE(
  scenario_id uuid,
  scenario_name text,
  investor_name text,
  followon_round_label text,
  followon_seq int,
  projected_round_valuation_rupees bigint,
  projected_check_rupees bigint,
  participate boolean,
  pro_rata_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.investor_name,
    f.followon_round_label, f.followon_seq,
    (s.current_pre_money_rupees * power(s.assumed_round_step_multiple, f.followon_seq))::bigint,
    COALESCE(f.override_check_rupees,
      CASE WHEN s.followon_rounds_count > 0
           THEN (s.reserved_followon_rupees / s.followon_rounds_count * (f.pro_rata_pct/100.0))::bigint
           ELSE 0 END),
    f.participate, f.pro_rata_pct
  FROM founder_investor_alloc_followons f
  JOIN founder_investor_alloc_scenarios s ON s.id = f.scenario_id
  ORDER BY s.scenario_name, f.followon_seq
  LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_followon_schedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_followon_schedule() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_by_type()
RETURNS TABLE(
  investor_type text,
  scenarios_count bigint,
  total_committed_rupees bigint,
  avg_check_rupees bigint,
  avg_moic_mid numeric,
  reserved_share_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT s.investor_type,
      (s.this_round_allocation_rupees + s.reserved_followon_rupees) AS committed,
      s.this_round_allocation_rupees, s.reserved_followon_rupees, s.requested_check_rupees,
      CASE WHEN (s.this_round_allocation_rupees + s.reserved_followon_rupees) > 0
             AND s.this_round_allocation_rupees > 0
           THEN ((s.this_round_allocation_rupees::numeric / NULLIF((s.current_pre_money_rupees + s.current_round_size_rupees), 0)::numeric)
                 * power(1 - s.assumed_dilution_per_round_pct/100.0, s.followon_rounds_count)
                 * s.exit_valuation_mid_rupees)::numeric
                / NULLIF((s.this_round_allocation_rupees + s.reserved_followon_rupees), 0)
           ELSE 0 END AS moic_mid
    FROM founder_investor_alloc_scenarios s
  )
  SELECT b.investor_type,
    count(*)::bigint,
    COALESCE(sum(b.committed), 0)::bigint,
    COALESCE(avg(b.requested_check_rupees), 0)::bigint,
    COALESCE(round(avg(b.moic_mid), 2), 0),
    COALESCE(round(100.0 * sum(b.reserved_followon_rupees)::numeric / NULLIF(sum(b.this_round_allocation_rupees + b.reserved_followon_rupees), 0), 1), 0)
  FROM base b
  GROUP BY b.investor_type
  ORDER BY sum(b.committed) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_by_type() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_round_rollup()
RETURNS TABLE(
  current_round_label text,
  investors_count bigint,
  total_this_round_rupees bigint,
  total_reserved_rupees bigint,
  total_round_size_rupees bigint,
  pct_round_filled numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.current_round_label,
    count(DISTINCT s.investor_name)::bigint,
    COALESCE(sum(s.this_round_allocation_rupees), 0)::bigint,
    COALESCE(sum(s.reserved_followon_rupees), 0)::bigint,
    max(s.current_round_size_rupees)::bigint,
    COALESCE(round(100.0 * sum(s.this_round_allocation_rupees)::numeric / NULLIF(max(s.current_round_size_rupees), 0), 1), 0)
  FROM founder_investor_alloc_scenarios s
  GROUP BY s.current_round_label
  ORDER BY sum(s.this_round_allocation_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_round_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_round_rollup() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_recent_activity()
RETURNS TABLE(
  op_name text,
  actor_email text,
  scenario_id uuid,
  scenario_name text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.op_name, l.actor_email,
    (l.after_value->>'scenario_id')::uuid,
    COALESCE(l.after_value->>'scenario_name', s.scenario_name),
    l.created_at
  FROM founder_action_log l
  LEFT JOIN founder_investor_alloc_scenarios s ON s.id = (l.after_value->>'scenario_id')::uuid
  WHERE l.op_name LIKE 'investor_alloc_%'
  ORDER BY l.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_recent_activity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_recent_activity() TO authenticated;

-- =========================================================================
-- WRITE RPC (VOLATILE SECDEF) — slider update
-- =========================================================================

CREATE OR REPLACE FUNCTION rpc_founder_investor_alloc_set_slider(
  p_scenario_id uuid,
  p_this_round_rupees bigint,
  p_reserved_rupees bigint
)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_this_round_rupees < 0 OR p_reserved_rupees < 0 THEN
    RAISE EXCEPTION 'allocation must be non-negative';
  END IF;
  UPDATE founder_investor_alloc_scenarios
    SET this_round_allocation_rupees = p_this_round_rupees,
        reserved_followon_rupees = p_reserved_rupees,
        updated_at = now()
  WHERE id = p_scenario_id AND NOT is_locked;
  PERFORM log_founder_investor_alloc_slider_change(p_scenario_id, p_this_round_rupees, p_reserved_rupees);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_alloc_set_slider(uuid, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_alloc_set_slider(uuid, bigint, bigint) TO authenticated;

COMMIT;