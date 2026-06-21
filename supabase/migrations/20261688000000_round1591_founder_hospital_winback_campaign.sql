BEGIN;

-- ============================================================================
-- r1591 — Founder Hospital Winback Campaign
-- Churned hospitals → multi-touch winback (founder call + special offer + new
-- feature pitch); per-hospital touchpoint log; conversion rate.
-- ============================================================================

-- ---------- Tables -----------------------------------------------------------

CREATE TABLE IF NOT EXISTS founder_winback_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  campaign_status text NOT NULL DEFAULT 'open'
    CHECK (campaign_status IN ('open','in_progress','won','lost','paused')),
  churn_reason text,
  last_contract_ended_at timestamptz,
  last_contract_arr_rupees integer NOT NULL DEFAULT 0,
  special_offer_pct integer NOT NULL DEFAULT 0
    CHECK (special_offer_pct BETWEEN 0 AND 90),
  pitch_feature text,
  owner_email text,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  won_arr_rupees integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id, opened_at)
);

CREATE INDEX IF NOT EXISTS idx_fwc_status ON founder_winback_campaigns(campaign_status);
CREATE INDEX IF NOT EXISTS idx_fwc_hospital ON founder_winback_campaigns(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fwc_opened ON founder_winback_campaigns(opened_at DESC);

CREATE TABLE IF NOT EXISTS founder_winback_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES founder_winback_campaigns(id) ON DELETE CASCADE,
  touch_kind text NOT NULL
    CHECK (touch_kind IN ('founder_call','email','whatsapp','site_visit','offer_sent','feature_pitch','contract_signed')),
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('pending','positive','neutral','negative','no_response','converted')),
  summary text,
  performed_by_email text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  next_step_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwt_campaign ON founder_winback_touchpoints(campaign_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_fwt_kind ON founder_winback_touchpoints(touch_kind);
CREATE INDEX IF NOT EXISTS idx_fwt_occurred ON founder_winback_touchpoints(occurred_at DESC);

-- ---------- RLS --------------------------------------------------------------

ALTER TABLE founder_winback_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_winback_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwc_founder_only ON founder_winback_campaigns;
CREATE POLICY fwc_founder_only ON founder_winback_campaigns
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS fwt_founder_only ON founder_winback_touchpoints;
CREATE POLICY fwt_founder_only ON founder_winback_touchpoints
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_winback_open(
  p_campaign_id uuid,
  p_hospital_org_id uuid,
  p_churn_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'winback_open',
    jsonb_build_object('campaign_id', p_campaign_id, 'hospital_org_id', p_hospital_org_id, 'churn_reason', p_churn_reason)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_winback_open(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_winback_open(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_winback_touch(
  p_campaign_id uuid,
  p_touch_kind text,
  p_outcome text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'winback_touch',
    jsonb_build_object('campaign_id', p_campaign_id, 'touch_kind', p_touch_kind, 'outcome', p_outcome)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_winback_touch(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_winback_touch(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_winback_close(
  p_campaign_id uuid,
  p_status text,
  p_won_arr integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'winback_close',
    jsonb_build_object('campaign_id', p_campaign_id, 'status', p_status, 'won_arr_rupees', p_won_arr)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_winback_close(uuid, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_winback_close(uuid, text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_winback_offer(
  p_campaign_id uuid,
  p_offer_pct integer,
  p_feature text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'winback_offer',
    jsonb_build_object('campaign_id', p_campaign_id, 'offer_pct', p_offer_pct, 'feature', p_feature)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_winback_offer(uuid, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_winback_offer(uuid, integer, text) TO authenticated;

-- ============================================================================
-- Read RPCs (STABLE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION rpc_founder_winback_overview()
RETURNS TABLE (
  total_campaigns integer,
  open_campaigns integer,
  in_progress_campaigns integer,
  won_campaigns integer,
  lost_campaigns integer,
  paused_campaigns integer,
  total_touches integer,
  positive_touches integer,
  conversion_rate_pct numeric,
  pipeline_arr_rupees bigint,
  recovered_arr_rupees bigint,
  avg_touches_per_win numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH c AS (SELECT * FROM founder_winback_campaigns),
       t AS (SELECT * FROM founder_winback_touchpoints),
       wins AS (
         SELECT c.id, COUNT(t.*)::numeric AS n
         FROM c LEFT JOIN t ON t.campaign_id = c.id
         WHERE c.campaign_status = 'won'
         GROUP BY c.id
       )
  SELECT
    (SELECT COUNT(*)::int FROM c),
    (SELECT COUNT(*)::int FROM c WHERE campaign_status='open'),
    (SELECT COUNT(*)::int FROM c WHERE campaign_status='in_progress'),
    (SELECT COUNT(*)::int FROM c WHERE campaign_status='won'),
    (SELECT COUNT(*)::int FROM c WHERE campaign_status='lost'),
    (SELECT COUNT(*)::int FROM c WHERE campaign_status='paused'),
    (SELECT COUNT(*)::int FROM t),
    (SELECT COUNT(*)::int FROM t WHERE outcome IN ('positive','converted')),
    CASE WHEN (SELECT COUNT(*) FROM c WHERE campaign_status IN ('won','lost')) = 0 THEN 0
         ELSE ROUND(100.0 * (SELECT COUNT(*) FROM c WHERE campaign_status='won')::numeric /
                    NULLIF((SELECT COUNT(*) FROM c WHERE campaign_status IN ('won','lost')),0), 2)
    END,
    COALESCE((SELECT SUM(last_contract_arr_rupees) FROM c WHERE campaign_status IN ('open','in_progress')),0)::bigint,
    COALESCE((SELECT SUM(won_arr_rupees) FROM c WHERE campaign_status='won'),0)::bigint,
    COALESCE((SELECT AVG(n) FROM wins), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_overview() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_campaigns_list()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  campaign_status text,
  churn_reason text,
  last_contract_arr_rupees integer,
  special_offer_pct integer,
  pitch_feature text,
  opened_at timestamptz,
  closed_at timestamptz,
  touches_count bigint,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_org_id, o.name, c.campaign_status, c.churn_reason,
         c.last_contract_arr_rupees, c.special_offer_pct, c.pitch_feature,
         c.opened_at, c.closed_at,
         (SELECT COUNT(*) FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id),
         (SELECT MAX(occurred_at) FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id)
  FROM founder_winback_campaigns c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  ORDER BY c.opened_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_campaigns_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_campaigns_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_touchpoints_recent()
RETURNS TABLE (
  id uuid,
  campaign_id uuid,
  hospital_name text,
  touch_kind text,
  outcome text,
  summary text,
  performed_by_email text,
  occurred_at timestamptz,
  next_step_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.campaign_id, o.name, t.touch_kind, t.outcome, t.summary,
         t.performed_by_email, t.occurred_at, t.next_step_at
  FROM founder_winback_touchpoints t
  JOIN founder_winback_campaigns c ON c.id = t.campaign_id
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  ORDER BY t.occurred_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_touchpoints_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_touchpoints_recent() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_by_touch_kind()
RETURNS TABLE (
  touch_kind text,
  total_touches bigint,
  positive_touches bigint,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.touch_kind,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE t.outcome IN ('positive','converted'))::bigint,
         CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE t.outcome IN ('positive','converted'))::numeric / COUNT(*), 2)
         END
  FROM founder_winback_touchpoints t
  GROUP BY t.touch_kind
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_by_touch_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_by_touch_kind() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_churn_reasons()
RETURNS TABLE (
  churn_reason text,
  campaigns_count bigint,
  won_count bigint,
  lost_count bigint,
  conversion_pct numeric,
  total_arr_at_risk bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(c.churn_reason,'unknown'),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE c.campaign_status='won')::bigint,
         COUNT(*) FILTER (WHERE c.campaign_status='lost')::bigint,
         CASE WHEN COUNT(*) FILTER (WHERE c.campaign_status IN ('won','lost')) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE c.campaign_status='won')::numeric /
                         NULLIF(COUNT(*) FILTER (WHERE c.campaign_status IN ('won','lost')),0), 2)
         END,
         COALESCE(SUM(c.last_contract_arr_rupees),0)::bigint
  FROM founder_winback_campaigns c
  GROUP BY COALESCE(c.churn_reason,'unknown')
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_churn_reasons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_churn_reasons() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_funnel()
RETURNS TABLE (
  stage text,
  hospitals_count bigint,
  arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT '1_identified'::text, COUNT(*)::bigint, COALESCE(SUM(last_contract_arr_rupees),0)::bigint
  FROM founder_winback_campaigns
  UNION ALL
  SELECT '2_contacted', COUNT(DISTINCT c.id)::bigint, COALESCE(SUM(c.last_contract_arr_rupees),0)::bigint
  FROM founder_winback_campaigns c
  WHERE EXISTS (SELECT 1 FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id)
  UNION ALL
  SELECT '3_offer_sent', COUNT(DISTINCT c.id)::bigint, COALESCE(SUM(c.last_contract_arr_rupees),0)::bigint
  FROM founder_winback_campaigns c
  WHERE EXISTS (SELECT 1 FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id AND t.touch_kind = 'offer_sent')
  UNION ALL
  SELECT '4_won', COUNT(*)::bigint, COALESCE(SUM(won_arr_rupees),0)::bigint
  FROM founder_winback_campaigns WHERE campaign_status='won'
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_funnel() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_winback_stale_campaigns()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  campaign_status text,
  opened_at timestamptz,
  last_touch_at timestamptz,
  days_since_touch numeric,
  last_contract_arr_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, o.name, c.campaign_status, c.opened_at,
         (SELECT MAX(occurred_at) FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id),
         EXTRACT(EPOCH FROM (now() - COALESCE(
           (SELECT MAX(occurred_at) FROM founder_winback_touchpoints t WHERE t.campaign_id = c.id),
           c.opened_at)))/86400.0,
         c.last_contract_arr_rupees
  FROM founder_winback_campaigns c
  LEFT JOIN organizations o ON o.id = c.hospital_org_id
  WHERE c.campaign_status IN ('open','in_progress')
  ORDER BY 6 DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_winback_stale_campaigns() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_winback_stale_campaigns() TO authenticated;

COMMIT;