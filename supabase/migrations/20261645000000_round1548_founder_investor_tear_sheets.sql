BEGIN;

-- Investor tear sheets: one-page summary per investor with interactions, soft-commits, last-touch, narrative beats
CREATE TABLE IF NOT EXISTS founder_investor_tear_sheets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm_name text,
  investor_email text,
  stage text NOT NULL DEFAULT 'cold' CHECK (stage IN ('cold','warm','meeting','soft_commit','term_sheet','passed','closed')),
  check_size_rupees bigint DEFAULT 0,
  soft_commit_rupees bigint DEFAULT 0,
  last_touch_at timestamptz,
  next_touch_at timestamptz,
  last_touch_channel text,
  narrative_beats_covered text[] NOT NULL DEFAULT '{}',
  total_interactions int NOT NULL DEFAULT 0,
  conviction_score int NOT NULL DEFAULT 0 CHECK (conviction_score BETWEEN 0 AND 100),
  notes text,
  refreshed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_investor_tear_sheets_stage ON founder_investor_tear_sheets(stage);
CREATE INDEX IF NOT EXISTS idx_founder_investor_tear_sheets_last_touch ON founder_investor_tear_sheets(last_touch_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_investor_tear_sheets_conviction ON founder_investor_tear_sheets(conviction_score DESC);

ALTER TABLE founder_investor_tear_sheets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_tear_sheets ON founder_investor_tear_sheets;
CREATE POLICY founder_only_tear_sheets ON founder_investor_tear_sheets
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_investor_interactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tear_sheet_id uuid NOT NULL REFERENCES founder_investor_tear_sheets(id) ON DELETE CASCADE,
  interaction_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('email','call','meeting','whatsapp','linkedin','intro','memo')),
  direction text NOT NULL DEFAULT 'outbound' CHECK (direction IN ('inbound','outbound')),
  summary text,
  narrative_beats text[] NOT NULL DEFAULT '{}',
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_investor_interactions_sheet ON founder_investor_interactions(tear_sheet_id, interaction_at DESC);

ALTER TABLE founder_investor_interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_interactions ON founder_investor_interactions;
CREATE POLICY founder_only_investor_interactions ON founder_investor_interactions
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- READ RPC 1: pipeline summary KPIs
CREATE OR REPLACE FUNCTION rpc_founder_investor_tear_sheets_summary()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_investors', COUNT(*),
    'cold', COUNT(*) FILTER (WHERE stage='cold'),
    'warm', COUNT(*) FILTER (WHERE stage='warm'),
    'meeting', COUNT(*) FILTER (WHERE stage='meeting'),
    'soft_commit', COUNT(*) FILTER (WHERE stage='soft_commit'),
    'term_sheet', COUNT(*) FILTER (WHERE stage='term_sheet'),
    'passed', COUNT(*) FILTER (WHERE stage='passed'),
    'closed', COUNT(*) FILTER (WHERE stage='closed'),
    'total_soft_commit_rupees', COALESCE(SUM(soft_commit_rupees),0),
    'total_check_size_rupees', COALESCE(SUM(check_size_rupees),0),
    'avg_conviction', COALESCE(ROUND(AVG(conviction_score)::numeric,1),0),
    'stale_30d', COUNT(*) FILTER (WHERE last_touch_at < now() - interval '30 days'),
    'fresh_7d', COUNT(*) FILTER (WHERE last_touch_at >= now() - interval '7 days'),
    'next_touch_due', COUNT(*) FILTER (WHERE next_touch_at IS NOT NULL AND next_touch_at <= now()),
    'avg_beats_covered', COALESCE(ROUND(AVG(array_length(narrative_beats_covered,1))::numeric,1),0),
    'total_interactions', COALESCE(SUM(total_interactions),0)
  ) INTO result FROM founder_investor_tear_sheets;
  RETURN result;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_tear_sheets_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_tear_sheets_summary() TO authenticated;

-- READ RPC 2: tear sheet list
CREATE OR REPLACE FUNCTION rpc_founder_investor_tear_sheets_list()
RETURNS SETOF founder_investor_tear_sheets
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM founder_investor_tear_sheets ORDER BY conviction_score DESC, last_touch_at DESC NULLS LAST LIMIT 500;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_tear_sheets_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_tear_sheets_list() TO authenticated;

-- READ RPC 3: stale investors (last touch > 14d)
CREATE OR REPLACE FUNCTION rpc_founder_investor_stale_touches()
RETURNS TABLE(id uuid, investor_name text, firm_name text, stage text, last_touch_at timestamptz, days_since_touch int, conviction_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_name, t.firm_name, t.stage, t.last_touch_at,
           (CURRENT_DATE - t.last_touch_at::date)::int AS days_since_touch,
           t.conviction_score
    FROM founder_investor_tear_sheets t
    WHERE t.last_touch_at IS NOT NULL
      AND t.last_touch_at < now() - interval '14 days'
      AND t.stage NOT IN ('passed','closed')
    ORDER BY t.last_touch_at ASC NULLS LAST LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_stale_touches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_stale_touches() TO authenticated;

-- READ RPC 4: narrative beats coverage gaps
CREATE OR REPLACE FUNCTION rpc_founder_investor_narrative_gaps()
RETURNS TABLE(id uuid, investor_name text, stage text, beats_covered int, missing_beats text[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE canonical_beats text[] := ARRAY['problem','market','traction','unit_economics','moat','team','ask','use_of_funds'];
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_name, t.stage,
           COALESCE(array_length(t.narrative_beats_covered,1),0) AS beats_covered,
           ARRAY(SELECT unnest(canonical_beats) EXCEPT SELECT unnest(t.narrative_beats_covered)) AS missing_beats
    FROM founder_investor_tear_sheets t
    WHERE t.stage NOT IN ('passed','closed')
    ORDER BY beats_covered ASC, t.conviction_score DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_narrative_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_narrative_gaps() TO authenticated;

-- READ RPC 5: recent interactions stream
CREATE OR REPLACE FUNCTION rpc_founder_investor_recent_interactions()
RETURNS TABLE(id uuid, tear_sheet_id uuid, investor_name text, interaction_at timestamptz, channel text, direction text, summary text, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.tear_sheet_id, t.investor_name, i.interaction_at, i.channel, i.direction, i.summary, i.outcome
    FROM founder_investor_interactions i
    JOIN founder_investor_tear_sheets t ON t.id = i.tear_sheet_id
    ORDER BY i.interaction_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_recent_interactions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_recent_interactions() TO authenticated;

-- WRITE RPC 6: refresh all tear sheets (recompute totals/last_touch)
CREATE OR REPLACE FUNCTION rpc_founder_investor_refresh_all()
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE updated_count int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH agg AS (
    SELECT tear_sheet_id,
           COUNT(*) AS total_interactions,
           MAX(interaction_at) AS last_touch,
           (array_agg(channel ORDER BY interaction_at DESC))[1] AS last_channel
    FROM founder_investor_interactions GROUP BY tear_sheet_id
  )
  UPDATE founder_investor_tear_sheets t
  SET total_interactions = COALESCE(a.total_interactions,0),
      last_touch_at = a.last_touch,
      last_touch_channel = a.last_channel,
      refreshed_at = now(),
      updated_at = now()
  FROM agg a WHERE a.tear_sheet_id = t.id;
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN jsonb_build_object('updated', updated_count, 'refreshed_at', now());
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_refresh_all() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_refresh_all() TO authenticated;

-- WRITE RPC 7: upsert tear sheet
CREATE OR REPLACE FUNCTION rpc_founder_investor_upsert_sheet(
  p_investor_name text, p_firm_name text, p_stage text, p_check_size_rupees bigint,
  p_soft_commit_rupees bigint, p_conviction_score int, p_narrative_beats text[]
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_tear_sheets(investor_name, firm_name, stage, check_size_rupees, soft_commit_rupees, conviction_score, narrative_beats_covered)
  VALUES (p_investor_name, p_firm_name, COALESCE(p_stage,'cold'), COALESCE(p_check_size_rupees,0), COALESCE(p_soft_commit_rupees,0), COALESCE(p_conviction_score,0), COALESCE(p_narrative_beats,'{}'))
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_upsert_sheet(text,text,text,bigint,bigint,int,text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_upsert_sheet(text,text,text,bigint,bigint,int,text[]) TO authenticated;

-- LOG helper 1: open
CREATE OR REPLACE FUNCTION log_founder_investor_sheet_open(p_sheet_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_sheet_open', jsonb_build_object('sheet_id', p_sheet_id, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_sheet_open(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_sheet_open(uuid) TO authenticated;

-- LOG helper 2: refresh
CREATE OR REPLACE FUNCTION log_founder_investor_refresh(p_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_tear_sheets_refresh', jsonb_build_object('updated', p_count, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_refresh(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_refresh(int) TO authenticated;

-- LOG helper 3: stage change
CREATE OR REPLACE FUNCTION log_founder_investor_stage_change(p_sheet_id uuid, p_new_stage text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_stage_change', jsonb_build_object('sheet_id', p_sheet_id, 'new_stage', p_new_stage));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_stage_change(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_stage_change(uuid, text) TO authenticated;

-- LOG helper 4: export
CREATE OR REPLACE FUNCTION log_founder_investor_export(p_format text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_tear_sheet_export', jsonb_build_object('format', p_format, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_investor_export(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_export(text) TO authenticated;

COMMIT;