BEGIN;

-- ============================================================
-- r1531 — Founder Investor Warm-Up Campaign
-- Multi-touchpoint warm-up plans for cold investors:
-- twitter mention -> linkedin comment -> email -> intro ask
-- Track per-investor warm-temperature score (0-100).
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_investor_warm_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  investor_handle_twitter text,
  investor_handle_linkedin text,
  investor_email text,
  thesis_fit text,
  campaign_status text NOT NULL DEFAULT 'planned' CHECK (campaign_status IN ('planned','active','warm','intro_asked','meeting_booked','passed','closed_won')),
  warm_temperature_score int NOT NULL DEFAULT 0 CHECK (warm_temperature_score BETWEEN 0 AND 100),
  planned_touchpoints int NOT NULL DEFAULT 4,
  completed_touchpoints int NOT NULL DEFAULT 0,
  next_action_at timestamptz,
  last_touch_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_investor_warm_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES founder_investor_warm_campaigns(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('twitter_mention','twitter_dm','linkedin_comment','linkedin_dm','email','intro_request','meeting','other')),
  channel text,
  content_snippet text,
  outcome text CHECK (outcome IN ('queued','sent','responded','ignored','bounced','positive','negative')),
  temperature_delta int NOT NULL DEFAULT 0,
  scheduled_at timestamptz,
  executed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_warm_campaigns_status ON founder_investor_warm_campaigns(campaign_status);
CREATE INDEX IF NOT EXISTS idx_warm_campaigns_next_action ON founder_investor_warm_campaigns(next_action_at);
CREATE INDEX IF NOT EXISTS idx_warm_touchpoints_campaign ON founder_investor_warm_touchpoints(campaign_id);
CREATE INDEX IF NOT EXISTS idx_warm_touchpoints_executed ON founder_investor_warm_touchpoints(executed_at);

ALTER TABLE founder_investor_warm_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_warm_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS warm_campaigns_founder_only ON founder_investor_warm_campaigns;
CREATE POLICY warm_campaigns_founder_only ON founder_investor_warm_campaigns
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS warm_touchpoints_founder_only ON founder_investor_warm_touchpoints;
CREATE POLICY warm_touchpoints_founder_only ON founder_investor_warm_touchpoints
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_warm_campaign_overview()
RETURNS TABLE (
  total_campaigns bigint,
  active_campaigns bigint,
  warm_campaigns bigint,
  intro_asked bigint,
  meeting_booked bigint,
  avg_temperature numeric,
  hottest_score int,
  total_touchpoints bigint,
  touchpoints_last_7d bigint,
  responded_touchpoints bigint,
  positive_touchpoints bigint,
  due_next_24h bigint,
  overdue_actions bigint,
  campaigns_planned bigint,
  campaigns_closed_won bigint,
  campaigns_passed bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_investor_warm_campaigns),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'active'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'warm'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'intro_asked'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'meeting_booked'),
    COALESCE((SELECT round(avg(warm_temperature_score)::numeric, 1) FROM founder_investor_warm_campaigns), 0),
    COALESCE((SELECT max(warm_temperature_score) FROM founder_investor_warm_campaigns), 0),
    (SELECT count(*) FROM founder_investor_warm_touchpoints),
    (SELECT count(*) FROM founder_investor_warm_touchpoints WHERE executed_at >= now() - interval '7 days'),
    (SELECT count(*) FROM founder_investor_warm_touchpoints WHERE outcome = 'responded'),
    (SELECT count(*) FROM founder_investor_warm_touchpoints WHERE outcome = 'positive'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE next_action_at IS NOT NULL AND next_action_at BETWEEN now() AND now() + interval '24 hours'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE next_action_at IS NOT NULL AND next_action_at < now() AND campaign_status NOT IN ('closed_won','passed')),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'planned'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'closed_won'),
    (SELECT count(*) FROM founder_investor_warm_campaigns WHERE campaign_status = 'passed');
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_campaign_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_firm text,
  campaign_status text,
  warm_temperature_score int,
  completed_touchpoints int,
  planned_touchpoints int,
  next_action_at timestamptz,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_name, c.investor_firm, c.campaign_status,
         c.warm_temperature_score, c.completed_touchpoints, c.planned_touchpoints,
         c.next_action_at, c.last_touch_at
  FROM founder_investor_warm_campaigns c
  ORDER BY c.warm_temperature_score DESC, c.next_action_at NULLS LAST
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_touchpoint_recent()
RETURNS TABLE (
  id uuid,
  investor_name text,
  touchpoint_kind text,
  outcome text,
  temperature_delta int,
  executed_at timestamptz,
  content_snippet text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, c.investor_name, t.touchpoint_kind, t.outcome,
         t.temperature_delta, t.executed_at, t.content_snippet
  FROM founder_investor_warm_touchpoints t
  JOIN founder_investor_warm_campaigns c ON c.id = t.campaign_id
  WHERE t.executed_at IS NOT NULL
  ORDER BY t.executed_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_due_actions()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_firm text,
  campaign_status text,
  warm_temperature_score int,
  next_action_at timestamptz,
  hours_until numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_name, c.investor_firm, c.campaign_status,
         c.warm_temperature_score, c.next_action_at,
         EXTRACT(EPOCH FROM (c.next_action_at - now()))/3600.0
  FROM founder_investor_warm_campaigns c
  WHERE c.next_action_at IS NOT NULL
    AND c.campaign_status NOT IN ('closed_won','passed')
  ORDER BY c.next_action_at ASC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_hottest_leads()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_firm text,
  warm_temperature_score int,
  campaign_status text,
  touchpoint_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_name, c.investor_firm, c.warm_temperature_score, c.campaign_status,
         (SELECT count(*) FROM founder_investor_warm_touchpoints t WHERE t.campaign_id = c.id)
  FROM founder_investor_warm_campaigns c
  WHERE c.warm_temperature_score > 0
  ORDER BY c.warm_temperature_score DESC
  LIMIT 25;
END;
$$;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_warm_campaign_create(
  p_investor_name text,
  p_investor_firm text,
  p_thesis_fit text,
  p_planned_touchpoints int DEFAULT 4
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_warm_campaigns (investor_name, investor_firm, thesis_fit, planned_touchpoints, campaign_status, next_action_at)
  VALUES (p_investor_name, p_investor_firm, p_thesis_fit, COALESCE(p_planned_touchpoints, 4), 'planned', now() + interval '1 day')
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_warm_campaign_create',
          jsonb_build_object('campaign_id', v_id, 'investor', p_investor_name, 'firm', p_investor_firm));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_touchpoint_log(
  p_campaign_id uuid,
  p_touchpoint_kind text,
  p_outcome text,
  p_temperature_delta int,
  p_content_snippet text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_warm_touchpoints (campaign_id, touchpoint_kind, outcome, temperature_delta, content_snippet, executed_at)
  VALUES (p_campaign_id, p_touchpoint_kind, p_outcome, COALESCE(p_temperature_delta, 0), p_content_snippet, now())
  RETURNING id INTO v_id;

  UPDATE founder_investor_warm_campaigns
  SET completed_touchpoints = completed_touchpoints + 1,
      warm_temperature_score = LEAST(100, GREATEST(0, warm_temperature_score + COALESCE(p_temperature_delta, 0))),
      last_touch_at = now(),
      next_action_at = now() + interval '3 days',
      campaign_status = CASE WHEN campaign_status = 'planned' THEN 'active' ELSE campaign_status END,
      updated_at = now()
  WHERE id = p_campaign_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_warm_touchpoint_log',
          jsonb_build_object('touchpoint_id', v_id, 'campaign_id', p_campaign_id, 'kind', p_touchpoint_kind, 'outcome', p_outcome));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_warm_campaign_advance_status(
  p_campaign_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_warm_campaigns
  SET campaign_status = p_new_status,
      updated_at = now()
  WHERE id = p_campaign_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_warm_campaign_advance_status',
          jsonb_build_object('campaign_id', p_campaign_id, 'new_status', p_new_status));
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_warm_campaign_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_campaign_overview() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_campaign_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_campaign_list() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_touchpoint_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_touchpoint_recent() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_due_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_due_actions() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_hottest_leads() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_hottest_leads() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_campaign_create(text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_campaign_create(text, text, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_touchpoint_log(uuid, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_touchpoint_log(uuid, text, text, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_warm_campaign_advance_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_warm_campaign_advance_status(uuid, text) TO authenticated;

COMMIT;