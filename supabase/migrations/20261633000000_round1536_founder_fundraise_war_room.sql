BEGIN;

-- ============================================================
-- r1536 — Founder Fundraise War Room
-- Real-time dashboard during active fundraise rounds.
-- ============================================================

-- ---------- Table 1: fundraise rounds ----------
CREATE TABLE IF NOT EXISTS fundraise_rounds_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_name text NOT NULL,
  target_amount_rupees bigint NOT NULL CHECK (target_amount_rupees > 0),
  raised_committed_rupees bigint NOT NULL DEFAULT 0,
  raised_wired_rupees bigint NOT NULL DEFAULT 0,
  stage text NOT NULL DEFAULT 'open' CHECK (stage IN ('open','closing','closed','paused')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  target_close_at timestamptz,
  closed_at timestamptz,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fundraise_rounds_v2_stage_opened ON fundraise_rounds_v2 (stage, opened_at DESC);

ALTER TABLE fundraise_rounds_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fundraise_rounds_v2_founder_only ON fundraise_rounds_v2;
CREATE POLICY fundraise_rounds_v2_founder_only ON fundraise_rounds_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- Table 2: investor pipeline ----------
CREATE TABLE IF NOT EXISTS fundraise_investor_pipeline_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES fundraise_rounds_v2(id) ON DELETE CASCADE,
  investor_name text NOT NULL,
  investor_firm text,
  investor_email text,
  status text NOT NULL DEFAULT 'first_meeting' CHECK (status IN (
    'sourced','first_meeting','partner_meeting','dd','term_sheet','soft_commit','wired','passed'
  )),
  heat_score int NOT NULL DEFAULT 50 CHECK (heat_score BETWEEN 0 AND 100),
  soft_commit_rupees bigint NOT NULL DEFAULT 0 CHECK (soft_commit_rupees >= 0),
  wired_rupees bigint NOT NULL DEFAULT 0 CHECK (wired_rupees >= 0),
  next_meeting_at timestamptz,
  last_touch_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fundraise_pipeline_v2_round_heat ON fundraise_investor_pipeline_v2 (round_id, heat_score DESC);
CREATE INDEX IF NOT EXISTS idx_fundraise_pipeline_v2_next_meeting ON fundraise_investor_pipeline_v2 (next_meeting_at) WHERE next_meeting_at IS NOT NULL;

ALTER TABLE fundraise_investor_pipeline_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fundraise_pipeline_v2_founder_only ON fundraise_investor_pipeline_v2;
CREATE POLICY fundraise_pipeline_v2_founder_only ON fundraise_investor_pipeline_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- log helpers (4)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_fundraise_round_opened(
  p_round_id uuid, p_round_name text, p_target bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fundraise_round_opened',
    jsonb_build_object('round_id', p_round_id, 'round_name', p_round_name, 'target', p_target));
END $$;

CREATE OR REPLACE FUNCTION log_founder_fundraise_investor_added(
  p_round_id uuid, p_investor_name text, p_firm text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fundraise_investor_added',
    jsonb_build_object('round_id', p_round_id, 'investor', p_investor_name, 'firm', p_firm));
END $$;

CREATE OR REPLACE FUNCTION log_founder_fundraise_soft_commit(
  p_investor_id uuid, p_amount bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fundraise_soft_commit',
    jsonb_build_object('investor_id', p_investor_id, 'amount', p_amount));
END $$;

CREATE OR REPLACE FUNCTION log_founder_fundraise_status_changed(
  p_investor_id uuid, p_status text, p_heat int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fundraise_status_changed',
    jsonb_build_object('investor_id', p_investor_id, 'status', p_status, 'heat', p_heat));
END $$;

-- ============================================================
-- 7 SECDEF RPCs (5 read STABLE + 2 write VOLATILE)
-- ============================================================

-- 1) Active round summary
CREATE OR REPLACE FUNCTION founder_fundraise_active_round_summary()
RETURNS TABLE (
  round_id uuid,
  round_name text,
  stage text,
  target_rupees bigint,
  soft_commit_total bigint,
  wired_total bigint,
  pct_committed numeric,
  pct_wired numeric,
  days_open numeric,
  days_to_close numeric,
  investor_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.round_name,
    r.stage,
    r.target_amount_rupees,
    COALESCE(SUM(p.soft_commit_rupees),0)::bigint,
    COALESCE(SUM(p.wired_rupees),0)::bigint,
    ROUND( (COALESCE(SUM(p.soft_commit_rupees),0)::numeric / NULLIF(r.target_amount_rupees,0)) * 100, 1),
    ROUND( (COALESCE(SUM(p.wired_rupees),0)::numeric / NULLIF(r.target_amount_rupees,0)) * 100, 1),
    ROUND(EXTRACT(EPOCH FROM (now() - r.opened_at))/86400.0, 1),
    CASE WHEN r.target_close_at IS NULL THEN NULL
         ELSE ROUND(EXTRACT(EPOCH FROM (r.target_close_at - now()))/86400.0, 1) END,
    COUNT(p.id)::bigint
  FROM fundraise_rounds_v2 r
  LEFT JOIN fundraise_investor_pipeline_v2 p ON p.round_id = r.id
  WHERE r.stage IN ('open','closing')
  GROUP BY r.id
  ORDER BY r.opened_at DESC
  LIMIT 1;
END $$;

-- 2) Meetings this week
CREATE OR REPLACE FUNCTION founder_fundraise_meetings_this_week()
RETURNS TABLE (
  investor_id uuid,
  investor_name text,
  investor_firm text,
  status text,
  heat_score int,
  next_meeting_at timestamptz,
  hours_until numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.investor_name, p.investor_firm, p.status, p.heat_score,
    p.next_meeting_at,
    ROUND(EXTRACT(EPOCH FROM (p.next_meeting_at - now()))/3600.0, 1)
  FROM fundraise_investor_pipeline_v2 p
  WHERE p.next_meeting_at IS NOT NULL
    AND p.next_meeting_at >= now()
    AND p.next_meeting_at < now() + INTERVAL '7 days'
  ORDER BY p.next_meeting_at ASC;
END $$;

-- 3) Hottest investors
CREATE OR REPLACE FUNCTION founder_fundraise_hottest_investors(p_limit int DEFAULT 15)
RETURNS TABLE (
  investor_id uuid,
  investor_name text,
  investor_firm text,
  status text,
  heat_score int,
  soft_commit_rupees bigint,
  wired_rupees bigint,
  days_since_touch numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.investor_name, p.investor_firm, p.status, p.heat_score,
    p.soft_commit_rupees, p.wired_rupees,
    ROUND(EXTRACT(EPOCH FROM (now() - p.last_touch_at))/86400.0, 1)
  FROM fundraise_investor_pipeline_v2 p
  WHERE p.status NOT IN ('passed','wired')
  ORDER BY p.heat_score DESC, p.last_touch_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;

-- 4) Schedule heatmap (next 14 days by day-of-week × hour-bucket)
CREATE OR REPLACE FUNCTION founder_fundraise_schedule_heatmap()
RETURNS TABLE (
  bucket_date date,
  hour_bucket text,
  meeting_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.next_meeting_at::date,
    CASE
      WHEN EXTRACT(HOUR FROM p.next_meeting_at) < 12 THEN 'morning'
      WHEN EXTRACT(HOUR FROM p.next_meeting_at) < 17 THEN 'afternoon'
      ELSE 'evening'
    END,
    COUNT(*)::bigint
  FROM fundraise_investor_pipeline_v2 p
  WHERE p.next_meeting_at IS NOT NULL
    AND p.next_meeting_at >= now()
    AND p.next_meeting_at < now() + INTERVAL '14 days'
  GROUP BY 1, 2
  ORDER BY 1 ASC, 2 ASC;
END $$;

-- 5) Funnel breakdown by status
CREATE OR REPLACE FUNCTION founder_fundraise_funnel_by_status()
RETURNS TABLE (
  status text,
  investor_count bigint,
  soft_commit_total bigint,
  wired_total bigint,
  avg_heat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.status,
    COUNT(*)::bigint,
    COALESCE(SUM(p.soft_commit_rupees),0)::bigint,
    COALESCE(SUM(p.wired_rupees),0)::bigint,
    ROUND(AVG(p.heat_score)::numeric, 1)
  FROM fundraise_investor_pipeline_v2 p
  GROUP BY p.status
  ORDER BY COUNT(*) DESC;
END $$;

-- 6) WRITE — upsert investor
CREATE OR REPLACE FUNCTION founder_fundraise_upsert_investor(
  p_round_id uuid,
  p_investor_name text,
  p_firm text,
  p_email text,
  p_status text,
  p_heat int,
  p_soft_commit bigint,
  p_next_meeting timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO fundraise_investor_pipeline_v2(
    round_id, investor_name, investor_firm, investor_email,
    status, heat_score, soft_commit_rupees, next_meeting_at, last_touch_at
  ) VALUES (
    p_round_id, p_investor_name, p_firm, p_email,
    COALESCE(p_status,'first_meeting'),
    COALESCE(p_heat,50),
    COALESCE(p_soft_commit,0),
    p_next_meeting,
    now()
  )
  RETURNING id INTO v_id;

  PERFORM log_founder_fundraise_investor_added(p_round_id, p_investor_name, p_firm);
  RETURN v_id;
END $$;

-- 7) WRITE — record soft commit
CREATE OR REPLACE FUNCTION founder_fundraise_record_soft_commit(
  p_investor_id uuid,
  p_amount bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE fundraise_investor_pipeline_v2
     SET soft_commit_rupees = p_amount,
         status = CASE WHEN p_amount > 0 THEN 'soft_commit' ELSE status END,
         last_touch_at = now(),
         updated_at = now()
   WHERE id = p_investor_id;

  PERFORM log_founder_fundraise_soft_commit(p_investor_id, p_amount);
END $$;

-- ============================================================
-- GRANTS
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_fundraise_active_round_summary()          FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_meetings_this_week()            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_hottest_investors(int)          FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_schedule_heatmap()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_funnel_by_status()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_upsert_investor(uuid,text,text,text,text,int,bigint,timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_fundraise_record_soft_commit(uuid,bigint) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_fundraise_active_round_summary()           TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_meetings_this_week()             TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_hottest_investors(int)           TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_schedule_heatmap()               TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_funnel_by_status()               TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_upsert_investor(uuid,text,text,text,text,int,bigint,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_fundraise_record_soft_commit(uuid,bigint)  TO authenticated;

COMMIT;