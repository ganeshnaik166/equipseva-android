BEGIN;

-- ============================================================
-- r1577 — Founder Cap-Table Simulator v4
-- Sensitivity scenarios: 3 Series A valuations × ESOP refresh
-- options × secondary sales. Founder picks + locks one for
-- board approval.
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_cap_table_scenarios_v4 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_label text NOT NULL,
  series_a_valuation_rupees bigint NOT NULL,
  series_a_raise_rupees bigint NOT NULL,
  esop_refresh_pct numeric(6,3) NOT NULL DEFAULT 0.0,
  secondary_sale_rupees bigint NOT NULL DEFAULT 0,
  founder_dilution_pct numeric(6,3),
  founder_post_money_pct numeric(6,3),
  founder_secondary_proceeds_rupees bigint,
  notes text,
  is_locked_for_board boolean NOT NULL DEFAULT false,
  locked_at timestamptz,
  locked_by_user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by_user_id uuid
);

ALTER TABLE founder_cap_table_scenarios_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cts_v4 ON founder_cap_table_scenarios_v4;
CREATE POLICY founder_only_cts_v4 ON founder_cap_table_scenarios_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_cap_table_lock_audit_v4 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id uuid NOT NULL REFERENCES founder_cap_table_scenarios_v4(id) ON DELETE CASCADE,
  action text NOT NULL,
  acted_by_user_id uuid,
  acted_by_email text,
  acted_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb
);

ALTER TABLE founder_cap_table_lock_audit_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cts_audit_v4 ON founder_cap_table_lock_audit_v4;
CREATE POLICY founder_only_cts_audit_v4 ON founder_cap_table_lock_audit_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- Log helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_cts_v4_create(p_scenario_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cts_v4_create', jsonb_build_object('scenario_id', p_scenario_id, 'payload', p_payload));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cts_v4_create(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cts_v4_create(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cts_v4_lock(p_scenario_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cts_v4_lock', jsonb_build_object('scenario_id', p_scenario_id, 'payload', p_payload));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cts_v4_lock(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cts_v4_lock(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cts_v4_unlock(p_scenario_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cts_v4_unlock', jsonb_build_object('scenario_id', p_scenario_id, 'payload', p_payload));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cts_v4_unlock(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cts_v4_unlock(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cts_v4_delete(p_scenario_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cts_v4_delete', jsonb_build_object('scenario_id', p_scenario_id, 'payload', p_payload));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cts_v4_delete(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cts_v4_delete(uuid, jsonb) TO authenticated;

-- ============================================================
-- Read RPCs (STABLE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_cts_v4_list_scenarios()
RETURNS TABLE (
  id uuid,
  scenario_label text,
  series_a_valuation_rupees bigint,
  series_a_raise_rupees bigint,
  esop_refresh_pct numeric,
  secondary_sale_rupees bigint,
  founder_dilution_pct numeric,
  founder_post_money_pct numeric,
  founder_secondary_proceeds_rupees bigint,
  is_locked_for_board boolean,
  locked_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_label, s.series_a_valuation_rupees, s.series_a_raise_rupees,
         s.esop_refresh_pct, s.secondary_sale_rupees, s.founder_dilution_pct,
         s.founder_post_money_pct, s.founder_secondary_proceeds_rupees,
         s.is_locked_for_board, s.locked_at, s.created_at
  FROM founder_cap_table_scenarios_v4 s
  ORDER BY s.is_locked_for_board DESC, s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_list_scenarios() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_list_scenarios() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cts_v4_summary_kpis()
RETURNS TABLE (
  total_scenarios bigint,
  locked_scenarios bigint,
  unlocked_scenarios bigint,
  min_valuation_rupees bigint,
  max_valuation_rupees bigint,
  avg_valuation_rupees bigint,
  min_dilution_pct numeric,
  max_dilution_pct numeric,
  avg_dilution_pct numeric,
  max_secondary_rupees bigint,
  total_secondary_rupees bigint,
  max_esop_refresh_pct numeric,
  min_post_money_pct numeric,
  max_post_money_pct numeric,
  last_locked_at timestamptz,
  last_created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE is_locked_for_board)::bigint,
    COUNT(*) FILTER (WHERE NOT is_locked_for_board)::bigint,
    COALESCE(MIN(series_a_valuation_rupees), 0)::bigint,
    COALESCE(MAX(series_a_valuation_rupees), 0)::bigint,
    COALESCE(AVG(series_a_valuation_rupees), 0)::bigint,
    COALESCE(MIN(founder_dilution_pct), 0)::numeric,
    COALESCE(MAX(founder_dilution_pct), 0)::numeric,
    COALESCE(AVG(founder_dilution_pct), 0)::numeric,
    COALESCE(MAX(secondary_sale_rupees), 0)::bigint,
    COALESCE(SUM(secondary_sale_rupees), 0)::bigint,
    COALESCE(MAX(esop_refresh_pct), 0)::numeric,
    COALESCE(MIN(founder_post_money_pct), 0)::numeric,
    COALESCE(MAX(founder_post_money_pct), 0)::numeric,
    MAX(locked_at),
    MAX(created_at)
  FROM founder_cap_table_scenarios_v4;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_summary_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_summary_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cts_v4_top_dilution()
RETURNS TABLE (
  id uuid,
  scenario_label text,
  series_a_valuation_rupees bigint,
  founder_dilution_pct numeric,
  founder_post_money_pct numeric,
  is_locked_for_board boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_label, s.series_a_valuation_rupees,
         s.founder_dilution_pct, s.founder_post_money_pct, s.is_locked_for_board
  FROM founder_cap_table_scenarios_v4 s
  ORDER BY s.founder_dilution_pct DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_top_dilution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_top_dilution() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cts_v4_top_secondary()
RETURNS TABLE (
  id uuid,
  scenario_label text,
  secondary_sale_rupees bigint,
  founder_secondary_proceeds_rupees bigint,
  series_a_valuation_rupees bigint,
  is_locked_for_board boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_label, s.secondary_sale_rupees,
         s.founder_secondary_proceeds_rupees, s.series_a_valuation_rupees,
         s.is_locked_for_board
  FROM founder_cap_table_scenarios_v4 s
  ORDER BY s.secondary_sale_rupees DESC NULLS LAST
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_top_secondary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_top_secondary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cts_v4_locked_scenario()
RETURNS TABLE (
  id uuid,
  scenario_label text,
  series_a_valuation_rupees bigint,
  series_a_raise_rupees bigint,
  esop_refresh_pct numeric,
  secondary_sale_rupees bigint,
  founder_dilution_pct numeric,
  founder_post_money_pct numeric,
  locked_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_label, s.series_a_valuation_rupees, s.series_a_raise_rupees,
         s.esop_refresh_pct, s.secondary_sale_rupees, s.founder_dilution_pct,
         s.founder_post_money_pct, s.locked_at,
         (EXTRACT(EPOCH FROM (now() - s.locked_at)) / 86400.0)::numeric AS age_days
  FROM founder_cap_table_scenarios_v4 s
  WHERE s.is_locked_for_board IS TRUE
  ORDER BY s.locked_at DESC
  LIMIT 5;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_locked_scenario() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_locked_scenario() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cts_v4_recent_audit()
RETURNS TABLE (
  id uuid,
  scenario_id uuid,
  action text,
  acted_by_email text,
  acted_at timestamptz,
  age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.scenario_id, a.action, a.acted_by_email, a.acted_at,
         (EXTRACT(EPOCH FROM (now() - a.acted_at)) / 86400.0)::numeric AS age_days
  FROM founder_cap_table_lock_audit_v4 a
  ORDER BY a.acted_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_recent_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_recent_audit() TO authenticated;

-- ============================================================
-- Write RPC (VOLATILE SECDEF, founder-gated): lock scenario
-- ============================================================

CREATE OR REPLACE FUNCTION founder_cts_v4_lock_scenario(p_scenario_id uuid)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  -- Atomically unlock all and lock the chosen one
  UPDATE founder_cap_table_scenarios_v4
  SET is_locked_for_board = false, locked_at = NULL, locked_by_user_id = NULL
  WHERE is_locked_for_board IS TRUE;

  UPDATE founder_cap_table_scenarios_v4
  SET is_locked_for_board = true,
      locked_at = now(),
      locked_by_user_id = auth.uid()
  WHERE id = p_scenario_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'scenario not found';
  END IF;

  INSERT INTO founder_cap_table_lock_audit_v4(scenario_id, action, acted_by_user_id, acted_by_email, payload)
  VALUES (v_id, 'lock', auth.uid(), (auth.jwt()->>'email'), jsonb_build_object('locked_at', now()));

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cts_v4_lock_scenario', jsonb_build_object('scenario_id', v_id));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_cts_v4_lock_scenario(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cts_v4_lock_scenario(uuid) TO authenticated;

COMMIT;