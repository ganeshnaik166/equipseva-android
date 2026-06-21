BEGIN;

-- ============================================================
-- r1633 — Founder Investor Reserve Fund Tracker
-- per-investor reserve fund (follow-on rounds); commitment vs
-- available; founder-only timing trigger surface.
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_investor_reserve_fund (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  fund_vintage_year int,
  total_commitment_rupees bigint NOT NULL DEFAULT 0,
  initial_check_rupees bigint NOT NULL DEFAULT 0,
  reserve_set_aside_rupees bigint NOT NULL DEFAULT 0,
  reserve_deployed_rupees bigint NOT NULL DEFAULT 0,
  follow_on_appetite text CHECK (follow_on_appetite IN ('eager','warm','cool','done')) DEFAULT 'warm',
  last_check_in_at timestamptz,
  next_trigger_at timestamptz,
  trigger_thesis text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_firf_appetite ON founder_investor_reserve_fund(follow_on_appetite);
CREATE INDEX IF NOT EXISTS idx_firf_next_trigger ON founder_investor_reserve_fund(next_trigger_at);

CREATE TABLE IF NOT EXISTS founder_investor_reserve_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES founder_investor_reserve_fund(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('check_in','signal','soft_circle','draw','release')),
  amount_rupees bigint NOT NULL DEFAULT 0,
  signal_strength int CHECK (signal_strength BETWEEN 1 AND 5),
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fire_investor ON founder_investor_reserve_events(investor_id, occurred_at DESC);

ALTER TABLE founder_investor_reserve_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_reserve_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS firf_founder_only ON founder_investor_reserve_fund;
CREATE POLICY firf_founder_only ON founder_investor_reserve_fund
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS fire_founder_only ON founder_investor_reserve_events;
CREATE POLICY fire_founder_only ON founder_investor_reserve_events
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_reserve_portfolio_summary()
RETURNS TABLE(
  investor_count int,
  total_commitment_rupees bigint,
  total_reserve_rupees bigint,
  total_deployed_rupees bigint,
  total_available_rupees bigint,
  eager_count int,
  warm_count int,
  cool_count int,
  done_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(total_commitment_rupees),0)::bigint,
    COALESCE(SUM(reserve_set_aside_rupees),0)::bigint,
    COALESCE(SUM(reserve_deployed_rupees),0)::bigint,
    COALESCE(SUM(reserve_set_aside_rupees - reserve_deployed_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE follow_on_appetite='eager')::int,
    COUNT(*) FILTER (WHERE follow_on_appetite='warm')::int,
    COUNT(*) FILTER (WHERE follow_on_appetite='cool')::int,
    COUNT(*) FILTER (WHERE follow_on_appetite='done')::int
  FROM founder_investor_reserve_fund;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_portfolio_summary() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_investor_list()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  fund_vintage_year int,
  total_commitment_rupees bigint,
  initial_check_rupees bigint,
  reserve_set_aside_rupees bigint,
  reserve_deployed_rupees bigint,
  reserve_available_rupees bigint,
  follow_on_appetite text,
  next_trigger_at timestamptz,
  last_check_in_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.investor_name, f.investor_firm, f.fund_vintage_year,
    f.total_commitment_rupees, f.initial_check_rupees,
    f.reserve_set_aside_rupees, f.reserve_deployed_rupees,
    (f.reserve_set_aside_rupees - f.reserve_deployed_rupees)::bigint,
    f.follow_on_appetite, f.next_trigger_at, f.last_check_in_at
  FROM founder_investor_reserve_fund f
  ORDER BY (f.reserve_set_aside_rupees - f.reserve_deployed_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_investor_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_investor_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_appetite_breakdown()
RETURNS TABLE(
  appetite text,
  investor_count int,
  reserve_available_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.follow_on_appetite,
    COUNT(*)::int,
    COALESCE(SUM(f.reserve_set_aside_rupees - f.reserve_deployed_rupees),0)::bigint
  FROM founder_investor_reserve_fund f
  GROUP BY f.follow_on_appetite
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_appetite_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_appetite_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_upcoming_triggers()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  next_trigger_at timestamptz,
  days_until int,
  reserve_available_rupees bigint,
  trigger_thesis text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.investor_name, f.investor_firm, f.next_trigger_at,
    GREATEST(0, (date_part('day', f.next_trigger_at - now()))::int),
    (f.reserve_set_aside_rupees - f.reserve_deployed_rupees)::bigint,
    f.trigger_thesis
  FROM founder_investor_reserve_fund f
  WHERE f.next_trigger_at IS NOT NULL
    AND f.next_trigger_at >= now()
    AND f.follow_on_appetite IN ('eager','warm')
  ORDER BY f.next_trigger_at ASC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_upcoming_triggers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_upcoming_triggers() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_recent_events(p_limit int DEFAULT 30)
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  investor_name text,
  event_type text,
  amount_rupees bigint,
  signal_strength int,
  note text,
  occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id, e.investor_id, f.investor_name,
    e.event_type, e.amount_rupees, e.signal_strength,
    e.note, e.occurred_at
  FROM founder_investor_reserve_events e
  JOIN founder_investor_reserve_fund f ON f.id = e.investor_id
  ORDER BY e.occurred_at DESC
  LIMIT COALESCE(p_limit,30);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_recent_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_recent_events(int) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_stale_check_ins()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  last_check_in_at timestamptz,
  days_stale int,
  reserve_available_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.investor_name, f.investor_firm, f.last_check_in_at,
    (date_part('day', now() - COALESCE(f.last_check_in_at, f.created_at)))::int,
    (f.reserve_set_aside_rupees - f.reserve_deployed_rupees)::bigint
  FROM founder_investor_reserve_fund f
  WHERE f.follow_on_appetite IN ('eager','warm')
    AND (f.last_check_in_at IS NULL OR f.last_check_in_at < now() - interval '45 days')
  ORDER BY COALESCE(f.last_check_in_at, f.created_at) ASC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_stale_check_ins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_stale_check_ins() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_reserve_top_available()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  reserve_available_rupees bigint,
  follow_on_appetite text,
  signal_avg numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.investor_name, f.investor_firm,
    (f.reserve_set_aside_rupees - f.reserve_deployed_rupees)::bigint,
    f.follow_on_appetite,
    (SELECT AVG(signal_strength)::numeric FROM founder_investor_reserve_events e
     WHERE e.investor_id = f.id AND e.signal_strength IS NOT NULL)
  FROM founder_investor_reserve_fund f
  WHERE (f.reserve_set_aside_rupees - f.reserve_deployed_rupees) > 0
  ORDER BY 4 DESC
  LIMIT 15;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_reserve_top_available() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_reserve_top_available() TO authenticated;

-- ============================================================
-- log_founder_* helpers (VOLATILE writes via founder_action_log)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_reserve_upsert_investor(
  p_id uuid,
  p_investor_name text,
  p_investor_firm text,
  p_fund_vintage_year int,
  p_total_commitment_rupees bigint,
  p_initial_check_rupees bigint,
  p_reserve_set_aside_rupees bigint,
  p_follow_on_appetite text,
  p_next_trigger_at timestamptz,
  p_trigger_thesis text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO founder_investor_reserve_fund(
      investor_name, investor_firm, fund_vintage_year,
      total_commitment_rupees, initial_check_rupees, reserve_set_aside_rupees,
      follow_on_appetite, next_trigger_at, trigger_thesis, notes
    ) VALUES (
      p_investor_name, p_investor_firm, p_fund_vintage_year,
      COALESCE(p_total_commitment_rupees,0), COALESCE(p_initial_check_rupees,0), COALESCE(p_reserve_set_aside_rupees,0),
      COALESCE(p_follow_on_appetite,'warm'), p_next_trigger_at, p_trigger_thesis, p_notes
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE founder_investor_reserve_fund SET
      investor_name = COALESCE(p_investor_name, investor_name),
      investor_firm = COALESCE(p_investor_firm, investor_firm),
      fund_vintage_year = COALESCE(p_fund_vintage_year, fund_vintage_year),
      total_commitment_rupees = COALESCE(p_total_commitment_rupees, total_commitment_rupees),
      initial_check_rupees = COALESCE(p_initial_check_rupees, initial_check_rupees),
      reserve_set_aside_rupees = COALESCE(p_reserve_set_aside_rupees, reserve_set_aside_rupees),
      follow_on_appetite = COALESCE(p_follow_on_appetite, follow_on_appetite),
      next_trigger_at = COALESCE(p_next_trigger_at, next_trigger_at),
      trigger_thesis = COALESCE(p_trigger_thesis, trigger_thesis),
      notes = COALESCE(p_notes, notes),
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'reserve_upsert_investor',
          jsonb_build_object('id', v_id, 'name', p_investor_name, 'appetite', p_follow_on_appetite,
                             'reserve_set_aside_rupees', p_reserve_set_aside_rupees), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_reserve_upsert_investor(uuid,text,text,int,bigint,bigint,bigint,text,timestamptz,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_reserve_upsert_investor(uuid,text,text,int,bigint,bigint,bigint,text,timestamptz,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_reserve_record_event(
  p_investor_id uuid,
  p_event_type text,
  p_amount_rupees bigint,
  p_signal_strength int,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_reserve_events(investor_id, event_type, amount_rupees, signal_strength, note)
  VALUES (p_investor_id, p_event_type, COALESCE(p_amount_rupees,0), p_signal_strength, p_note)
  RETURNING id INTO v_id;

  IF p_event_type = 'check_in' THEN
    UPDATE founder_investor_reserve_fund SET last_check_in_at = now(), updated_at = now() WHERE id = p_investor_id;
  ELSIF p_event_type = 'draw' THEN
    UPDATE founder_investor_reserve_fund SET reserve_deployed_rupees = reserve_deployed_rupees + COALESCE(p_amount_rupees,0), updated_at = now() WHERE id = p_investor_id;
  ELSIF p_event_type = 'release' THEN
    UPDATE founder_investor_reserve_fund SET reserve_set_aside_rupees = GREATEST(0, reserve_set_aside_rupees - COALESCE(p_amount_rupees,0)), updated_at = now() WHERE id = p_investor_id;
  END IF;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'reserve_record_event',
          jsonb_build_object('investor_id', p_investor_id, 'event_type', p_event_type,
                             'amount_rupees', p_amount_rupees, 'signal_strength', p_signal_strength), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_reserve_record_event(uuid,text,bigint,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_reserve_record_event(uuid,text,bigint,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_reserve_set_trigger(
  p_investor_id uuid,
  p_next_trigger_at timestamptz,
  p_trigger_thesis text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_reserve_fund SET
    next_trigger_at = p_next_trigger_at,
    trigger_thesis = COALESCE(p_trigger_thesis, trigger_thesis),
    updated_at = now()
  WHERE id = p_investor_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'reserve_set_trigger',
          jsonb_build_object('investor_id', p_investor_id, 'next_trigger_at', p_next_trigger_at,
                             'trigger_thesis', p_trigger_thesis), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_reserve_set_trigger(uuid,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_reserve_set_trigger(uuid,timestamptz,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_reserve_close_investor(
  p_investor_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_reserve_fund SET
    follow_on_appetite = 'done',
    next_trigger_at = NULL,
    notes = COALESCE(notes,'') || E'\n[closed] ' || COALESCE(p_reason,''),
    updated_at = now()
  WHERE id = p_investor_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'reserve_close_investor',
          jsonb_build_object('investor_id', p_investor_id, 'reason', p_reason), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_reserve_close_investor(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_reserve_close_investor(uuid,text) TO authenticated;

COMMIT;