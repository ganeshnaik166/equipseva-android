BEGIN;

-- =============================================================================
-- r1637 — Investor Portfolio Events Calendar
-- Calendar of portfolio investor events (annual meetings, conferences, demo
-- days), per-event RSVP + agenda, founder schedule view.
-- =============================================================================

CREATE TABLE IF NOT EXISTS founder_investor_portfolio_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  event_title text NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('annual_meeting','conference','demo_day','office_hours','portfolio_dinner','board_meeting','other')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  location text,
  is_virtual boolean NOT NULL DEFAULT false,
  meeting_link text,
  agenda_md text,
  rsvp_status text NOT NULL DEFAULT 'pending' CHECK (rsvp_status IN ('pending','accepted','declined','tentative','attended','no_show')),
  rsvp_notes text,
  importance text NOT NULL DEFAULT 'normal' CHECK (importance IN ('low','normal','high','critical')),
  prep_notes_md text,
  follow_up_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fipe_starts_at ON founder_investor_portfolio_events(starts_at DESC);
CREATE INDEX IF NOT EXISTS idx_fipe_investor ON founder_investor_portfolio_events(investor_name);
CREATE INDEX IF NOT EXISTS idx_fipe_rsvp ON founder_investor_portfolio_events(rsvp_status);

ALTER TABLE founder_investor_portfolio_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fipe_founder_only ON founder_investor_portfolio_events;
CREATE POLICY fipe_founder_only ON founder_investor_portfolio_events
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_investor_portfolio_event_agenda_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES founder_investor_portfolio_events(id) ON DELETE CASCADE,
  ord int NOT NULL DEFAULT 0,
  topic text NOT NULL,
  owner text,
  duration_minutes int,
  notes_md text,
  is_done boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fipeai_event ON founder_investor_portfolio_event_agenda_items(event_id, ord);

ALTER TABLE founder_investor_portfolio_event_agenda_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fipeai_founder_only ON founder_investor_portfolio_event_agenda_items;
CREATE POLICY fipeai_founder_only ON founder_investor_portfolio_event_agenda_items
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =============================================================================
-- log helper
-- =============================================================================

CREATE OR REPLACE FUNCTION log_founder_investor_portfolio_event(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_investor_portfolio_event(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_portfolio_event(text, jsonb) TO authenticated;

-- =============================================================================
-- RPC 1 — list upcoming events (read)
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_list_investor_portfolio_events(p_days_ahead int DEFAULT 90)
RETURNS TABLE(
  id uuid,
  investor_name text,
  event_title text,
  event_kind text,
  starts_at timestamptz,
  ends_at timestamptz,
  location text,
  is_virtual boolean,
  rsvp_status text,
  importance text,
  agenda_item_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.investor_name, e.event_title, e.event_kind, e.starts_at, e.ends_at,
         e.location, e.is_virtual, e.rsvp_status, e.importance,
         (SELECT count(*) FROM founder_investor_portfolio_event_agenda_items a WHERE a.event_id = e.id)
  FROM founder_investor_portfolio_events e
  WHERE e.starts_at >= now() - interval '7 days'
    AND e.starts_at <= now() + (p_days_ahead || ' days')::interval
  ORDER BY e.starts_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_list_investor_portfolio_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_investor_portfolio_events(int) TO authenticated;

-- =============================================================================
-- RPC 2 — schedule grouped by week
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_investor_portfolio_events_schedule()
RETURNS TABLE(
  week_start date,
  event_count bigint,
  accepted_count bigint,
  pending_count bigint,
  high_importance_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', e.starts_at)::date AS week_start,
         count(*)::bigint,
         count(*) FILTER (WHERE e.rsvp_status = 'accepted')::bigint,
         count(*) FILTER (WHERE e.rsvp_status = 'pending')::bigint,
         count(*) FILTER (WHERE e.importance IN ('high','critical'))::bigint
  FROM founder_investor_portfolio_events e
  WHERE e.starts_at >= now() - interval '30 days'
    AND e.starts_at <= now() + interval '180 days'
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_portfolio_events_schedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_portfolio_events_schedule() TO authenticated;

-- =============================================================================
-- RPC 3 — RSVP summary
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_investor_portfolio_events_rsvp_summary()
RETURNS TABLE(
  rsvp_status text,
  event_count bigint,
  next_starts_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.rsvp_status, count(*)::bigint, min(e.starts_at)
  FROM founder_investor_portfolio_events e
  WHERE e.starts_at >= now()
  GROUP BY e.rsvp_status
  ORDER BY 2 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_portfolio_events_rsvp_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_portfolio_events_rsvp_summary() TO authenticated;

-- =============================================================================
-- RPC 4 — investor breakdown
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_investor_portfolio_events_by_investor()
RETURNS TABLE(
  investor_name text,
  total_events bigint,
  upcoming_events bigint,
  attended_events bigint,
  last_event_at timestamptz,
  next_event_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.investor_name,
         count(*)::bigint,
         count(*) FILTER (WHERE e.starts_at >= now())::bigint,
         count(*) FILTER (WHERE e.rsvp_status = 'attended')::bigint,
         max(e.starts_at) FILTER (WHERE e.starts_at < now()),
         min(e.starts_at) FILTER (WHERE e.starts_at >= now())
  FROM founder_investor_portfolio_events e
  GROUP BY e.investor_name
  ORDER BY 2 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_portfolio_events_by_investor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_portfolio_events_by_investor() TO authenticated;

-- =============================================================================
-- RPC 5 — agenda items for an event
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_investor_portfolio_event_agenda(p_event_id uuid)
RETURNS TABLE(
  id uuid,
  ord int,
  topic text,
  owner text,
  duration_minutes int,
  is_done boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.ord, a.topic, a.owner, a.duration_minutes, a.is_done
  FROM founder_investor_portfolio_event_agenda_items a
  WHERE a.event_id = p_event_id
  ORDER BY a.ord ASC, a.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_portfolio_event_agenda(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_portfolio_event_agenda(uuid) TO authenticated;

-- =============================================================================
-- RPC 6 — record RSVP (write, VOLATILE)
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_record_investor_portfolio_event_rsvp(
  p_event_id uuid,
  p_rsvp_status text,
  p_rsvp_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_rsvp_status NOT IN ('pending','accepted','declined','tentative','attended','no_show') THEN
    RAISE EXCEPTION 'invalid rsvp_status';
  END IF;
  UPDATE founder_investor_portfolio_events
  SET rsvp_status = p_rsvp_status,
      rsvp_notes = COALESCE(p_rsvp_notes, rsvp_notes),
      updated_at = now()
  WHERE id = p_event_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'event not found'; END IF;
  PERFORM log_founder_investor_portfolio_event('rsvp_update',
    jsonb_build_object('event_id', v_id, 'rsvp_status', p_rsvp_status));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_record_investor_portfolio_event_rsvp(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_record_investor_portfolio_event_rsvp(uuid, text, text) TO authenticated;

-- =============================================================================
-- RPC 7 — create event (write, VOLATILE)
-- =============================================================================

CREATE OR REPLACE FUNCTION founder_create_investor_portfolio_event(
  p_investor_name text,
  p_event_title text,
  p_event_kind text,
  p_starts_at timestamptz,
  p_ends_at timestamptz DEFAULT NULL,
  p_location text DEFAULT NULL,
  p_is_virtual boolean DEFAULT false,
  p_importance text DEFAULT 'normal'
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_event_kind NOT IN ('annual_meeting','conference','demo_day','office_hours','portfolio_dinner','board_meeting','other') THEN
    RAISE EXCEPTION 'invalid event_kind';
  END IF;
  IF p_importance NOT IN ('low','normal','high','critical') THEN
    RAISE EXCEPTION 'invalid importance';
  END IF;
  INSERT INTO founder_investor_portfolio_events(
    investor_name, event_title, event_kind, starts_at, ends_at, location, is_virtual, importance
  ) VALUES (
    p_investor_name, p_event_title, p_event_kind, p_starts_at, p_ends_at, p_location, p_is_virtual, p_importance
  ) RETURNING id INTO v_id;
  PERFORM log_founder_investor_portfolio_event('event_create',
    jsonb_build_object('event_id', v_id, 'investor', p_investor_name, 'title', p_event_title));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_create_investor_portfolio_event(text, text, text, timestamptz, timestamptz, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_create_investor_portfolio_event(text, text, text, timestamptz, timestamptz, text, boolean, text) TO authenticated;

COMMIT;