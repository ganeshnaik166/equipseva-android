BEGIN;

-- Round 1572: Investor cap table v3 — post-money rounds, ESOP refreshes, secondary sales, conversions, per-shareholder dilution waterfall.

CREATE TABLE IF NOT EXISTS cap_table_v3_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_code text NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('priced_round','safe_conversion','esop_refresh','secondary_sale','buyback','option_grant','option_exercise','option_cancel')),
  closed_at timestamptz NOT NULL DEFAULT now(),
  pre_money_valuation_rupees bigint,
  post_money_valuation_rupees bigint,
  new_money_rupees bigint NOT NULL DEFAULT 0,
  price_per_share_rupees numeric(18,6),
  shares_issued bigint NOT NULL DEFAULT 0,
  esop_pool_target_pct numeric(6,4),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cap_table_v3_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cap_table_v3_events_founder_only ON cap_table_v3_events;
CREATE POLICY cap_table_v3_events_founder_only ON cap_table_v3_events
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS cap_table_v3_holdings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES cap_table_v3_events(id) ON DELETE CASCADE,
  shareholder_name text NOT NULL,
  shareholder_kind text NOT NULL CHECK (shareholder_kind IN ('founder','employee','angel','vc','strategic','esop_pool','advisor')),
  share_class text NOT NULL CHECK (share_class IN ('common','seed_pref','series_a_pref','series_b_pref','safe','option')),
  shares_before bigint NOT NULL DEFAULT 0,
  shares_delta bigint NOT NULL DEFAULT 0,
  shares_after bigint NOT NULL DEFAULT 0,
  pct_before numeric(8,5),
  pct_after numeric(8,5),
  dilution_pct numeric(8,5),
  cash_in_rupees bigint NOT NULL DEFAULT 0,
  cash_out_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cap_table_v3_holdings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cap_table_v3_holdings_founder_only ON cap_table_v3_holdings;
CREATE POLICY cap_table_v3_holdings_founder_only ON cap_table_v3_holdings
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS cap_table_v3_holdings_event_idx ON cap_table_v3_holdings(event_id);
CREATE INDEX IF NOT EXISTS cap_table_v3_holdings_name_idx ON cap_table_v3_holdings(shareholder_name);
CREATE INDEX IF NOT EXISTS cap_table_v3_events_closed_idx ON cap_table_v3_events(closed_at DESC);

-- ============ log helpers (VOLATILE SECDEF) ============

CREATE OR REPLACE FUNCTION log_founder_cap_v3_event_recorded(p_event_id uuid, p_kind text, p_post_money bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cap_v3_event_recorded',
    jsonb_build_object('event_id', p_event_id, 'kind', p_kind, 'post_money_rupees', p_post_money));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_cap_v3_event_recorded(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cap_v3_event_recorded(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cap_v3_holding_upserted(p_holding_id uuid, p_shareholder text, p_shares_after bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cap_v3_holding_upserted',
    jsonb_build_object('holding_id', p_holding_id, 'shareholder', p_shareholder, 'shares_after', p_shares_after));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_cap_v3_holding_upserted(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cap_v3_holding_upserted(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cap_v3_secondary_recorded(p_event_id uuid, p_seller text, p_cash_out bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cap_v3_secondary_recorded',
    jsonb_build_object('event_id', p_event_id, 'seller', p_seller, 'cash_out_rupees', p_cash_out));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_cap_v3_secondary_recorded(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cap_v3_secondary_recorded(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cap_v3_esop_refreshed(p_event_id uuid, p_target_pct numeric, p_shares_added bigint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cap_v3_esop_refreshed',
    jsonb_build_object('event_id', p_event_id, 'target_pct', p_target_pct, 'shares_added', p_shares_added));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_cap_v3_esop_refreshed(uuid, numeric, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cap_v3_esop_refreshed(uuid, numeric, bigint) TO authenticated;

-- ============ READ RPCs (STABLE) ============

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_kpis()
RETURNS TABLE(
  total_events int, priced_rounds int, safe_conversions int, esop_refreshes int,
  secondary_sales int, buybacks int, option_grants int, option_exercises int,
  total_new_money_rupees bigint, total_secondary_rupees bigint, latest_post_money_rupees bigint,
  total_shares_outstanding bigint, total_shareholders int, founders_pct numeric,
  esop_pool_pct numeric, last_event_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT e.id, e.post_money_valuation_rupees, e.closed_at
    FROM cap_table_v3_events e
    ORDER BY e.closed_at DESC LIMIT 1
  ),
  latest_holdings AS (
    SELECT h.* FROM cap_table_v3_holdings h
    JOIN latest l ON l.id = h.event_id
  )
  SELECT
    (SELECT COUNT(*)::int FROM cap_table_v3_events),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'priced_round'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'safe_conversion'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'esop_refresh'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'secondary_sale'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'buyback'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'option_grant'),
    (SELECT COUNT(*)::int FROM cap_table_v3_events WHERE event_kind = 'option_exercise'),
    COALESCE((SELECT SUM(new_money_rupees) FROM cap_table_v3_events WHERE event_kind IN ('priced_round','safe_conversion')), 0)::bigint,
    COALESCE((SELECT SUM(cash_out_rupees) FROM cap_table_v3_holdings h JOIN cap_table_v3_events e ON e.id=h.event_id WHERE e.event_kind = 'secondary_sale'), 0)::bigint,
    COALESCE((SELECT post_money_valuation_rupees FROM latest), 0)::bigint,
    COALESCE((SELECT SUM(shares_after) FROM latest_holdings), 0)::bigint,
    (SELECT COUNT(DISTINCT shareholder_name)::int FROM latest_holdings WHERE shareholder_kind <> 'esop_pool'),
    COALESCE((SELECT SUM(pct_after) FROM latest_holdings WHERE shareholder_kind = 'founder'), 0)::numeric,
    COALESCE((SELECT SUM(pct_after) FROM latest_holdings WHERE shareholder_kind = 'esop_pool'), 0)::numeric,
    (SELECT closed_at FROM latest);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_events_list()
RETURNS TABLE(
  id uuid, event_code text, event_kind text, closed_at timestamptz,
  pre_money_valuation_rupees bigint, post_money_valuation_rupees bigint,
  new_money_rupees bigint, price_per_share_rupees numeric, shares_issued bigint,
  esop_pool_target_pct numeric, holdings_count int, note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_code, e.event_kind, e.closed_at,
    e.pre_money_valuation_rupees, e.post_money_valuation_rupees,
    e.new_money_rupees, e.price_per_share_rupees, e.shares_issued,
    e.esop_pool_target_pct,
    (SELECT COUNT(*)::int FROM cap_table_v3_holdings h WHERE h.event_id = e.id),
    e.note
  FROM cap_table_v3_events e
  ORDER BY e.closed_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_events_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_events_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_current_table()
RETURNS TABLE(
  shareholder_name text, shareholder_kind text, share_class text,
  shares_after bigint, pct_after numeric, cash_in_rupees bigint, cash_out_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_latest uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_latest FROM cap_table_v3_events ORDER BY closed_at DESC LIMIT 1;
  RETURN QUERY
  SELECT h.shareholder_name, h.shareholder_kind, h.share_class,
    SUM(h.shares_after)::bigint, SUM(h.pct_after)::numeric,
    COALESCE(SUM(c.cash_in_rupees),0)::bigint, COALESCE(SUM(c.cash_out_rupees),0)::bigint
  FROM cap_table_v3_holdings h
  LEFT JOIN cap_table_v3_holdings c ON c.shareholder_name = h.shareholder_name
  WHERE h.event_id = v_latest
  GROUP BY h.shareholder_name, h.shareholder_kind, h.share_class
  ORDER BY SUM(h.pct_after) DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_current_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_current_table() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_dilution_waterfall()
RETURNS TABLE(
  shareholder_name text, shareholder_kind text,
  pct_at_first numeric, pct_now numeric, total_dilution_pct numeric,
  cumulative_cash_in_rupees bigint, cumulative_cash_out_rupees bigint, events_touched int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT h.shareholder_name, h.shareholder_kind, h.pct_after, h.pct_before,
      h.cash_in_rupees, h.cash_out_rupees, e.closed_at,
      ROW_NUMBER() OVER (PARTITION BY h.shareholder_name ORDER BY e.closed_at ASC) AS rn_first,
      ROW_NUMBER() OVER (PARTITION BY h.shareholder_name ORDER BY e.closed_at DESC) AS rn_last
    FROM cap_table_v3_holdings h
    JOIN cap_table_v3_events e ON e.id = h.event_id
  )
  SELECT
    r.shareholder_name,
    MAX(r.shareholder_kind),
    MAX(CASE WHEN r.rn_first = 1 THEN r.pct_after END)::numeric,
    MAX(CASE WHEN r.rn_last = 1 THEN r.pct_after END)::numeric,
    (MAX(CASE WHEN r.rn_first = 1 THEN r.pct_after END) - MAX(CASE WHEN r.rn_last = 1 THEN r.pct_after END))::numeric,
    COALESCE(SUM(r.cash_in_rupees),0)::bigint,
    COALESCE(SUM(r.cash_out_rupees),0)::bigint,
    COUNT(*)::int
  FROM ranked r
  GROUP BY r.shareholder_name
  ORDER BY MAX(CASE WHEN r.rn_last = 1 THEN r.pct_after END) DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_dilution_waterfall() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_dilution_waterfall() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_esop_history()
RETURNS TABLE(
  event_id uuid, event_code text, closed_at timestamptz,
  target_pct numeric, pool_shares_after bigint, pool_pct_after numeric, note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_code, e.closed_at, e.esop_pool_target_pct,
    COALESCE((SELECT SUM(h.shares_after) FROM cap_table_v3_holdings h WHERE h.event_id = e.id AND h.shareholder_kind = 'esop_pool'),0)::bigint,
    COALESCE((SELECT SUM(h.pct_after) FROM cap_table_v3_holdings h WHERE h.event_id = e.id AND h.shareholder_kind = 'esop_pool'),0)::numeric,
    e.note
  FROM cap_table_v3_events e
  WHERE e.event_kind IN ('esop_refresh','option_grant','option_exercise','option_cancel')
  ORDER BY e.closed_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_esop_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_esop_history() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_secondary_log()
RETURNS TABLE(
  event_id uuid, event_code text, closed_at timestamptz,
  seller_name text, shares_sold bigint, price_per_share_rupees numeric, cash_out_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_code, e.closed_at, h.shareholder_name,
    ABS(h.shares_delta)::bigint, e.price_per_share_rupees, h.cash_out_rupees
  FROM cap_table_v3_events e
  JOIN cap_table_v3_holdings h ON h.event_id = e.id
  WHERE e.event_kind = 'secondary_sale' AND h.cash_out_rupees > 0
  ORDER BY e.closed_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_secondary_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_secondary_log() TO authenticated;

-- ============ WRITE RPC (VOLATILE) ============

CREATE OR REPLACE FUNCTION rpc_founder_cap_v3_record_event(
  p_event_code text, p_event_kind text, p_pre_money bigint, p_post_money bigint,
  p_new_money bigint, p_price numeric, p_shares_issued bigint, p_esop_target numeric, p_note text
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO cap_table_v3_events(event_code, event_kind, pre_money_valuation_rupees, post_money_valuation_rupees,
    new_money_rupees, price_per_share_rupees, shares_issued, esop_pool_target_pct, note)
  VALUES (p_event_code, p_event_kind, p_pre_money, p_post_money, COALESCE(p_new_money,0), p_price,
    COALESCE(p_shares_issued,0), p_esop_target, p_note)
  RETURNING id INTO v_id;
  PERFORM log_founder_cap_v3_event_recorded(v_id, p_event_kind, p_post_money);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_cap_v3_record_event(text, text, bigint, bigint, bigint, numeric, bigint, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_cap_v3_record_event(text, text, bigint, bigint, bigint, numeric, bigint, numeric, text) TO authenticated;

COMMIT;