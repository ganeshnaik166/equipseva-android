BEGIN;

-- ============================================================================
-- r1585 — Founder Fundraise Press Placement
-- Orchestrate fundraise-announcement press: TC/YourStory/ET/Inc42 placements,
-- exclusive vs broadcast, founder spokesperson + quotes, embargo coordination.
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_fundraise_press_placements_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet text NOT NULL CHECK (outlet IN ('techcrunch','yourstory','economic_times','inc42','moneycontrol','livemint','forbes_india','business_standard')),
  reporter_name text NOT NULL,
  reporter_email text,
  reporter_handle text,
  placement_kind text NOT NULL CHECK (placement_kind IN ('exclusive','broadcast','embargoed','follow_up','op_ed')),
  fundraise_round_label text NOT NULL,
  raise_amount_usd_millions numeric(8,2),
  lead_investor text,
  embargo_until timestamptz,
  scheduled_publish_at timestamptz,
  pitched_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pitched' CHECK (status IN ('pitched','accepted','passed','interviewing','draft_review','published','spiked','postponed')),
  spokesperson text NOT NULL DEFAULT 'founder' CHECK (spokesperson IN ('founder','cofounder','lead_investor','customer','none')),
  approved_quote text,
  outlet_url text,
  inbound_traffic_estimate int,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ffpp_v2_status ON founder_fundraise_press_placements_v2(status);
CREATE INDEX IF NOT EXISTS idx_ffpp_v2_outlet ON founder_fundraise_press_placements_v2(outlet);
CREATE INDEX IF NOT EXISTS idx_ffpp_v2_pitched ON founder_fundraise_press_placements_v2(pitched_at DESC);
CREATE INDEX IF NOT EXISTS idx_ffpp_v2_embargo ON founder_fundraise_press_placements_v2(embargo_until) WHERE embargo_until IS NOT NULL;

ALTER TABLE founder_fundraise_press_placements_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ffpp_v2_founder_all ON founder_fundraise_press_placements_v2;
CREATE POLICY ffpp_v2_founder_all ON founder_fundraise_press_placements_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_fundraise_press_touchpoints_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  placement_id uuid NOT NULL REFERENCES founder_fundraise_press_placements_v2(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('email_pitch','call','interview','quote_draft','follow_up','embargo_brief','asset_send','correction_request')),
  channel text CHECK (channel IN ('email','phone','signal','whatsapp','in_person','zoom','linkedin')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  outcome text CHECK (outcome IN ('positive','neutral','negative','no_response')),
  summary text,
  next_action_due timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ffpt_v2_placement ON founder_fundraise_press_touchpoints_v2(placement_id);
CREATE INDEX IF NOT EXISTS idx_ffpt_v2_occurred ON founder_fundraise_press_touchpoints_v2(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_ffpt_v2_next_due ON founder_fundraise_press_touchpoints_v2(next_action_due) WHERE next_action_due IS NOT NULL;

ALTER TABLE founder_fundraise_press_touchpoints_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ffpt_v2_founder_all ON founder_fundraise_press_touchpoints_v2;
CREATE POLICY ffpt_v2_founder_all ON founder_fundraise_press_touchpoints_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_press_placements_overview()
RETURNS TABLE(
  total_placements bigint,
  exclusives bigint,
  broadcasts bigint,
  embargoed bigint,
  published bigint,
  pending bigint,
  spiked bigint,
  outlets_engaged bigint,
  active_embargoes bigint,
  avg_days_to_publish numeric,
  total_estimated_reach bigint,
  acceptance_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE placement_kind='exclusive')::bigint,
    COUNT(*) FILTER (WHERE placement_kind='broadcast')::bigint,
    COUNT(*) FILTER (WHERE placement_kind='embargoed')::bigint,
    COUNT(*) FILTER (WHERE status='published')::bigint,
    COUNT(*) FILTER (WHERE status IN ('pitched','interviewing','draft_review'))::bigint,
    COUNT(*) FILTER (WHERE status='spiked')::bigint,
    COUNT(DISTINCT outlet)::bigint,
    COUNT(*) FILTER (WHERE embargo_until IS NOT NULL AND embargo_until > now())::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (scheduled_publish_at - pitched_at))/86400.0) FILTER (WHERE status='published'), 1),
    COALESCE(SUM(inbound_traffic_estimate) FILTER (WHERE status='published'), 0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE status IN ('pitched','passed','accepted','published','spiked')) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE status IN ('accepted','published','interviewing','draft_review'))::numeric
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('pitched','passed','accepted','published','spiked')), 0), 1)
      ELSE 0 END
  FROM founder_fundraise_press_placements_v2;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_placements_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_placements_overview() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_placements_list(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  outlet text,
  reporter_name text,
  placement_kind text,
  fundraise_round_label text,
  status text,
  spokesperson text,
  embargo_until timestamptz,
  scheduled_publish_at timestamptz,
  pitched_at timestamptz,
  outlet_url text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.outlet, p.reporter_name, p.placement_kind, p.fundraise_round_label,
         p.status, p.spokesperson, p.embargo_until, p.scheduled_publish_at, p.pitched_at, p.outlet_url
  FROM founder_fundraise_press_placements_v2 p
  ORDER BY p.pitched_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_placements_list(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_placements_list(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_outlet_breakdown()
RETURNS TABLE(
  outlet text,
  pitches bigint,
  published bigint,
  spiked bigint,
  avg_response_days numeric,
  est_total_reach bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.outlet,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.status='published')::bigint,
         COUNT(*) FILTER (WHERE p.status='spiked')::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (p.scheduled_publish_at - p.pitched_at))/86400.0) FILTER (WHERE p.scheduled_publish_at IS NOT NULL), 1),
         COALESCE(SUM(p.inbound_traffic_estimate) FILTER (WHERE p.status='published'), 0)::bigint
  FROM founder_fundraise_press_placements_v2 p
  GROUP BY p.outlet
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_outlet_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_outlet_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_active_embargoes()
RETURNS TABLE(
  id uuid,
  outlet text,
  reporter_name text,
  fundraise_round_label text,
  embargo_until timestamptz,
  hours_until_lift numeric,
  approved_quote text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.outlet, p.reporter_name, p.fundraise_round_label, p.embargo_until,
         ROUND(EXTRACT(EPOCH FROM (p.embargo_until - now()))/3600.0, 1),
         p.approved_quote
  FROM founder_fundraise_press_placements_v2 p
  WHERE p.embargo_until IS NOT NULL AND p.embargo_until > now()
  ORDER BY p.embargo_until ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_active_embargoes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_active_embargoes() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_recent_touchpoints(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  placement_id uuid,
  outlet text,
  touchpoint_kind text,
  channel text,
  occurred_at timestamptz,
  outcome text,
  summary text,
  next_action_due timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.placement_id, p.outlet, t.touchpoint_kind, t.channel,
         t.occurred_at, t.outcome, t.summary, t.next_action_due
  FROM founder_fundraise_press_touchpoints_v2 t
  JOIN founder_fundraise_press_placements_v2 p ON p.id = t.placement_id
  ORDER BY t.occurred_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_recent_touchpoints(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_recent_touchpoints(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_followups_due()
RETURNS TABLE(
  placement_id uuid,
  outlet text,
  reporter_name text,
  status text,
  next_action_due timestamptz,
  hours_overdue numeric,
  last_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.outlet, p.reporter_name, p.status, t.next_action_due,
         ROUND(EXTRACT(EPOCH FROM (now() - t.next_action_due))/3600.0, 1),
         t.summary
  FROM founder_fundraise_press_touchpoints_v2 t
  JOIN founder_fundraise_press_placements_v2 p ON p.id = t.placement_id
  WHERE t.next_action_due IS NOT NULL
    AND t.next_action_due < now()
    AND p.status NOT IN ('published','spiked','passed')
  ORDER BY t.next_action_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_followups_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_followups_due() TO authenticated;

-- ============================================================================
-- WRITE RPC (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_press_record_placement(
  p_outlet text,
  p_reporter_name text,
  p_placement_kind text,
  p_fundraise_round_label text,
  p_raise_amount_usd_millions numeric DEFAULT NULL,
  p_lead_investor text DEFAULT NULL,
  p_embargo_until timestamptz DEFAULT NULL,
  p_approved_quote text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_fundraise_press_placements_v2(
    outlet, reporter_name, placement_kind, fundraise_round_label,
    raise_amount_usd_millions, lead_investor, embargo_until, approved_quote
  ) VALUES (
    p_outlet, p_reporter_name, p_placement_kind, p_fundraise_round_label,
    p_raise_amount_usd_millions, p_lead_investor, p_embargo_until, p_approved_quote
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_press_record_placement',
    jsonb_build_object('id', v_id, 'outlet', p_outlet, 'kind', p_placement_kind, 'round', p_fundraise_round_label));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_press_record_placement(text,text,text,text,numeric,text,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_press_record_placement(text,text,text,text,numeric,text,timestamptz,text) TO authenticated;

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_press_pitch_sent(p_placement_id uuid, p_outlet text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_press_pitch_sent',
    jsonb_build_object('placement_id', p_placement_id, 'outlet', p_outlet));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_press_pitch_sent(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_press_pitch_sent(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_embargo_set(p_placement_id uuid, p_embargo_until timestamptz)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_press_embargo_set',
    jsonb_build_object('placement_id', p_placement_id, 'embargo_until', p_embargo_until));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_press_embargo_set(uuid,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_press_embargo_set(uuid,timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_quote_approved(p_placement_id uuid, p_quote text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_press_quote_approved',
    jsonb_build_object('placement_id', p_placement_id, 'quote_len', length(coalesce(p_quote,''))));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_press_quote_approved(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_press_quote_approved(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_published(p_placement_id uuid, p_outlet_url text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_press_published',
    jsonb_build_object('placement_id', p_placement_id, 'url', p_outlet_url));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_press_published(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_press_published(uuid,text) TO authenticated;

COMMIT;