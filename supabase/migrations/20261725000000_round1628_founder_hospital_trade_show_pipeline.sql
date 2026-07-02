BEGIN;

-- =========================================================================
-- r1628 — Founder Hospital Trade-Show Pipeline
-- Track leads captured at biomedical trade shows (CMEF, MEDICALL, India Med Expo, etc.),
-- their source/intent, follow-up cadence, and downstream AMC contract conversion.
-- =========================================================================

-- ---- Table 1: trade shows (events where leads were captured) -----------
CREATE TABLE IF NOT EXISTS founder_trade_shows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  show_name text NOT NULL,
  city text NOT NULL,
  state text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  booth_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (booth_cost_rupees >= 0),
  travel_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (travel_cost_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_founder_trade_shows_start ON founder_trade_shows(start_date DESC);

ALTER TABLE founder_trade_shows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_trade_shows_founder_only ON founder_trade_shows;
CREATE POLICY founder_trade_shows_founder_only ON founder_trade_shows
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---- Table 2: per-lead capture -----------------------------------------
CREATE TABLE IF NOT EXISTS founder_trade_show_leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_show_id uuid NOT NULL REFERENCES founder_trade_shows(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  contact_name text NOT NULL,
  contact_phone text,
  contact_email text,
  city text,
  state text,
  source text NOT NULL CHECK (source IN ('booth_walkup','referral','speaker_session','demo_request','partner_intro','cold_outreach')),
  intent text NOT NULL CHECK (intent IN ('hot','warm','cold','dead')),
  bed_count int CHECK (bed_count IS NULL OR bed_count >= 0),
  equipment_interest text[] NOT NULL DEFAULT '{}',
  estimated_amc_rupees bigint NOT NULL DEFAULT 0 CHECK (estimated_amc_rupees >= 0),
  next_follow_up_date date,
  last_contact_at timestamptz,
  stage text NOT NULL DEFAULT 'captured' CHECK (stage IN ('captured','contacted','demo_done','proposal_sent','negotiation','won','lost')),
  converted_amc_contract_id uuid REFERENCES amc_contracts(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ts_leads_show ON founder_trade_show_leads(trade_show_id);
CREATE INDEX IF NOT EXISTS idx_ts_leads_stage ON founder_trade_show_leads(stage);
CREATE INDEX IF NOT EXISTS idx_ts_leads_intent ON founder_trade_show_leads(intent);
CREATE INDEX IF NOT EXISTS idx_ts_leads_followup ON founder_trade_show_leads(next_follow_up_date) WHERE next_follow_up_date IS NOT NULL;

ALTER TABLE founder_trade_show_leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_ts_leads_founder_only ON founder_trade_show_leads;
CREATE POLICY founder_ts_leads_founder_only ON founder_trade_show_leads
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

-- 1. trade-show roster with lead counts + spend + pipeline value
CREATE OR REPLACE FUNCTION list_trade_shows()
RETURNS TABLE (
  show_id uuid,
  show_name text,
  city text,
  state text,
  start_date date,
  end_date date,
  total_spend_rupees bigint,
  lead_count bigint,
  hot_count bigint,
  won_count bigint,
  pipeline_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    ts.id,
    ts.show_name,
    ts.city,
    ts.state,
    ts.start_date,
    ts.end_date,
    (ts.booth_cost_rupees + ts.travel_cost_rupees)::bigint,
    COUNT(l.id)::bigint,
    COUNT(l.id) FILTER (WHERE l.intent = 'hot')::bigint,
    COUNT(l.id) FILTER (WHERE l.stage = 'won')::bigint,
    COALESCE(SUM(l.estimated_amc_rupees) FILTER (WHERE l.stage NOT IN ('won','lost')), 0)::bigint
  FROM founder_trade_shows ts
  LEFT JOIN founder_trade_show_leads l ON l.trade_show_id = ts.id
  GROUP BY ts.id
  ORDER BY ts.start_date DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_trade_shows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_trade_shows() TO authenticated;

-- 2. open leads needing follow-up (hot/warm, next_follow_up <= today+3, not won/lost)
CREATE OR REPLACE FUNCTION list_followup_due_leads()
RETURNS TABLE (
  lead_id uuid,
  show_name text,
  hospital_name text,
  contact_name text,
  contact_phone text,
  intent text,
  stage text,
  source text,
  estimated_amc_rupees bigint,
  next_follow_up_date date,
  days_until int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    l.id,
    ts.show_name,
    l.hospital_name,
    l.contact_name,
    l.contact_phone,
    l.intent,
    l.stage,
    l.source,
    l.estimated_amc_rupees,
    l.next_follow_up_date,
    (l.next_follow_up_date - CURRENT_DATE)::int
  FROM founder_trade_show_leads l
  JOIN founder_trade_shows ts ON ts.id = l.trade_show_id
  WHERE l.stage NOT IN ('won','lost')
    AND l.next_follow_up_date IS NOT NULL
    AND l.next_follow_up_date <= CURRENT_DATE + 3
  ORDER BY l.next_follow_up_date ASC NULLS LAST, l.intent
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_followup_due_leads() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_followup_due_leads() TO authenticated;

-- 3. pipeline stage breakdown
CREATE OR REPLACE FUNCTION trade_show_pipeline_by_stage()
RETURNS TABLE (
  stage text,
  lead_count bigint,
  pipeline_rupees bigint,
  avg_amc_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    l.stage,
    COUNT(*)::bigint,
    COALESCE(SUM(l.estimated_amc_rupees), 0)::bigint,
    COALESCE(AVG(l.estimated_amc_rupees)::bigint, 0)::bigint
  FROM founder_trade_show_leads l
  GROUP BY l.stage
  ORDER BY
    CASE l.stage
      WHEN 'captured' THEN 1
      WHEN 'contacted' THEN 2
      WHEN 'demo_done' THEN 3
      WHEN 'proposal_sent' THEN 4
      WHEN 'negotiation' THEN 5
      WHEN 'won' THEN 6
      WHEN 'lost' THEN 7
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION trade_show_pipeline_by_stage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION trade_show_pipeline_by_stage() TO authenticated;

-- 4. ROI per show — won AMC realized revenue + spend
CREATE OR REPLACE FUNCTION trade_show_roi()
RETURNS TABLE (
  show_id uuid,
  show_name text,
  start_date date,
  total_spend_rupees bigint,
  leads_captured bigint,
  amc_won_count bigint,
  realized_amc_rupees bigint,
  roi_multiple numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    ts.id,
    ts.show_name,
    ts.start_date,
    (ts.booth_cost_rupees + ts.travel_cost_rupees)::bigint,
    COUNT(l.id)::bigint,
    COUNT(ac.id)::bigint,
    COALESCE(SUM(ac.monthly_fee_rupees * 12) FILTER (WHERE ac.id IS NOT NULL), 0)::bigint,
    CASE
      WHEN (ts.booth_cost_rupees + ts.travel_cost_rupees) > 0
        THEN ROUND(COALESCE(SUM(ac.monthly_fee_rupees * 12) FILTER (WHERE ac.id IS NOT NULL), 0)::numeric
                   / (ts.booth_cost_rupees + ts.travel_cost_rupees)::numeric, 2)
      ELSE 0
    END
  FROM founder_trade_shows ts
  LEFT JOIN founder_trade_show_leads l ON l.trade_show_id = ts.id
  LEFT JOIN amc_contracts ac ON ac.id = l.converted_amc_contract_id
  GROUP BY ts.id
  ORDER BY ts.start_date DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION trade_show_roi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION trade_show_roi() TO authenticated;

-- 5. hot leads (intent=hot) detail list
CREATE OR REPLACE FUNCTION list_hot_leads()
RETURNS TABLE (
  lead_id uuid,
  show_name text,
  hospital_name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  city text,
  state text,
  bed_count int,
  equipment_interest text[],
  estimated_amc_rupees bigint,
  stage text,
  next_follow_up_date date,
  last_contact_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    l.id, ts.show_name, l.hospital_name, l.contact_name, l.contact_phone, l.contact_email,
    l.city, l.state, l.bed_count, l.equipment_interest, l.estimated_amc_rupees,
    l.stage, l.next_follow_up_date, l.last_contact_at
  FROM founder_trade_show_leads l
  JOIN founder_trade_shows ts ON ts.id = l.trade_show_id
  WHERE l.intent = 'hot' AND l.stage NOT IN ('won','lost')
  ORDER BY l.estimated_amc_rupees DESC, l.next_follow_up_date ASC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_hot_leads() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_hot_leads() TO authenticated;

-- =========================================================================
-- WRITE RPCs (VOLATILE)
-- =========================================================================

-- 6. log a new lead from a trade show
CREATE OR REPLACE FUNCTION log_founder_trade_show_lead(
  p_show_id uuid,
  p_hospital_name text,
  p_contact_name text,
  p_contact_phone text,
  p_source text,
  p_intent text,
  p_estimated_amc_rupees bigint,
  p_next_follow_up_date date
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO founder_trade_show_leads (
    trade_show_id, hospital_name, contact_name, contact_phone,
    source, intent, estimated_amc_rupees, next_follow_up_date
  )
  VALUES (
    p_show_id, p_hospital_name, p_contact_name, p_contact_phone,
    p_source, p_intent, COALESCE(p_estimated_amc_rupees, 0), p_next_follow_up_date
  )
  RETURNING id INTO v_lead_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_trade_show_lead',
    jsonb_build_object('lead_id', v_lead_id, 'show_id', p_show_id, 'hospital_name', p_hospital_name, 'intent', p_intent),
    now()
  );

  RETURN v_lead_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_trade_show_lead(uuid, text, text, text, text, text, bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_trade_show_lead(uuid, text, text, text, text, text, bigint, date) TO authenticated;

-- 7. advance a lead stage / mark contact
CREATE OR REPLACE FUNCTION log_founder_trade_show_lead_stage(
  p_lead_id uuid,
  p_new_stage text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE founder_trade_show_leads
  SET stage = p_new_stage,
      notes = COALESCE(p_notes, notes),
      last_contact_at = now(),
      updated_at = now()
  WHERE id = p_lead_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_trade_show_lead_stage',
    jsonb_build_object('lead_id', p_lead_id, 'new_stage', p_new_stage),
    now()
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_trade_show_lead_stage(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_trade_show_lead_stage(uuid, text, text) TO authenticated;

-- 8. register a new trade show event
CREATE OR REPLACE FUNCTION log_founder_trade_show_event(
  p_show_name text,
  p_city text,
  p_state text,
  p_start_date date,
  p_end_date date,
  p_booth_cost_rupees bigint,
  p_travel_cost_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_show_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO founder_trade_shows (
    show_name, city, state, start_date, end_date, booth_cost_rupees, travel_cost_rupees
  )
  VALUES (
    p_show_name, p_city, p_state, p_start_date, p_end_date,
    COALESCE(p_booth_cost_rupees, 0), COALESCE(p_travel_cost_rupees, 0)
  )
  RETURNING id INTO v_show_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_trade_show_event',
    jsonb_build_object('show_id', v_show_id, 'show_name', p_show_name, 'city', p_city, 'start_date', p_start_date),
    now()
  );

  RETURN v_show_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_trade_show_event(text, text, text, date, date, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_trade_show_event(text, text, text, date, date, bigint, bigint) TO authenticated;

COMMIT;