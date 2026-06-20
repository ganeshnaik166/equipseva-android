BEGIN;

-- ============================================================================
-- Round 1527: Investor Signal Interpreter
-- Parses investor email/Slack replies; classifies sentiment + commit signals
-- + concerns; surfaces founder action queue.
-- ============================================================================

CREATE TABLE IF NOT EXISTS investor_signal_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_handle text NOT NULL,
  investor_name text,
  channel text NOT NULL CHECK (channel IN ('email','slack','telegram','whatsapp','call_note')),
  thread_ref text,
  subject text,
  body text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  sentiment text NOT NULL DEFAULT 'neutral' CHECK (sentiment IN ('strong_positive','positive','neutral','concerned','negative')),
  sentiment_score numeric(4,3) NOT NULL DEFAULT 0,
  commit_signal text NOT NULL DEFAULT 'none' CHECK (commit_signal IN ('lead','soft_commit','term_sheet','passing','exploring','none')),
  commit_amount_rupees bigint,
  concern_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  next_step text,
  parsed_at timestamptz NOT NULL DEFAULT now(),
  parser_version text NOT NULL DEFAULT 'v1',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isi_msgs_received ON investor_signal_messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_isi_msgs_sentiment ON investor_signal_messages(sentiment);
CREATE INDEX IF NOT EXISTS idx_isi_msgs_commit ON investor_signal_messages(commit_signal);
CREATE INDEX IF NOT EXISTS idx_isi_msgs_handle ON investor_signal_messages(investor_handle);

ALTER TABLE investor_signal_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isi_msgs_founder_all ON investor_signal_messages;
CREATE POLICY isi_msgs_founder_all ON investor_signal_messages
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS investor_signal_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES investor_signal_messages(id) ON DELETE SET NULL,
  investor_handle text NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('reply','send_deck','schedule_call','share_data_room','followup','escalate','close_lost','close_won','park')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('p0','p1','p2','p3','normal')),
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_isi_actions_status ON investor_signal_actions(status);
CREATE INDEX IF NOT EXISTS idx_isi_actions_due ON investor_signal_actions(due_at);
CREATE INDEX IF NOT EXISTS idx_isi_actions_priority ON investor_signal_actions(priority);

ALTER TABLE investor_signal_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isi_actions_founder_all ON investor_signal_actions;
CREATE POLICY isi_actions_founder_all ON investor_signal_actions
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE SECURITY DEFINER)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_isi_overview()
RETURNS TABLE(
  total_messages bigint,
  msgs_24h bigint,
  msgs_7d bigint,
  strong_positive bigint,
  positive bigint,
  neutral bigint,
  concerned bigint,
  negative bigint,
  leads bigint,
  soft_commits bigint,
  term_sheets bigint,
  passes bigint,
  exploring_count bigint,
  total_pipeline_rupees bigint,
  open_actions bigint,
  overdue_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM investor_signal_messages),
    (SELECT count(*) FROM investor_signal_messages WHERE received_at >= now() - interval '24 hours'),
    (SELECT count(*) FROM investor_signal_messages WHERE received_at >= now() - interval '7 days'),
    (SELECT count(*) FROM investor_signal_messages WHERE sentiment = 'strong_positive'),
    (SELECT count(*) FROM investor_signal_messages WHERE sentiment = 'positive'),
    (SELECT count(*) FROM investor_signal_messages WHERE sentiment = 'neutral'),
    (SELECT count(*) FROM investor_signal_messages WHERE sentiment = 'concerned'),
    (SELECT count(*) FROM investor_signal_messages WHERE sentiment = 'negative'),
    (SELECT count(*) FROM investor_signal_messages WHERE commit_signal = 'lead'),
    (SELECT count(*) FROM investor_signal_messages WHERE commit_signal = 'soft_commit'),
    (SELECT count(*) FROM investor_signal_messages WHERE commit_signal = 'term_sheet'),
    (SELECT count(*) FROM investor_signal_messages WHERE commit_signal = 'passing'),
    (SELECT count(*) FROM investor_signal_messages WHERE commit_signal = 'exploring'),
    (SELECT COALESCE(sum(commit_amount_rupees),0)::bigint FROM investor_signal_messages WHERE commit_signal IN ('lead','soft_commit','term_sheet')),
    (SELECT count(*) FROM investor_signal_actions WHERE status = 'open'),
    (SELECT count(*) FROM investor_signal_actions WHERE status = 'open' AND due_at < now());
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_overview() TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_recent_messages(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  investor_handle text,
  investor_name text,
  channel text,
  subject text,
  sentiment text,
  sentiment_score numeric,
  commit_signal text,
  commit_amount_rupees bigint,
  concern_tags text[],
  next_step text,
  received_at timestamptz,
  age_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.investor_handle, m.investor_name, m.channel, m.subject,
         m.sentiment, m.sentiment_score, m.commit_signal, m.commit_amount_rupees,
         m.concern_tags, m.next_step, m.received_at,
         ROUND((EXTRACT(EPOCH FROM (now() - m.received_at)) / 3600.0)::numeric, 2)
  FROM investor_signal_messages m
  ORDER BY m.received_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_recent_messages(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_recent_messages(int) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_open_actions()
RETURNS TABLE(
  id uuid,
  message_id uuid,
  investor_handle text,
  action_kind text,
  priority text,
  due_at timestamptz,
  status text,
  note text,
  overdue boolean,
  hours_to_due numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.message_id, a.investor_handle, a.action_kind, a.priority,
         a.due_at, a.status, a.note,
         (a.due_at IS NOT NULL AND a.due_at < now()),
         CASE WHEN a.due_at IS NOT NULL
              THEN ROUND((EXTRACT(EPOCH FROM (a.due_at - now())) / 3600.0)::numeric, 2)
              ELSE NULL END
  FROM investor_signal_actions a
  WHERE a.status IN ('open','in_progress')
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 WHEN 'p3' THEN 3 ELSE 4 END,
    a.due_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_open_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_open_actions() TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_top_concerns()
RETURNS TABLE(
  concern_tag text,
  mentions bigint,
  unique_investors bigint,
  last_seen timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tag,
         count(*)::bigint,
         count(DISTINCT m.investor_handle)::bigint,
         max(m.received_at)
  FROM investor_signal_messages m
  CROSS JOIN LATERAL unnest(m.concern_tags) AS t(tag)
  GROUP BY t.tag
  ORDER BY count(*) DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_top_concerns() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_top_concerns() TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_investor_leaderboard()
RETURNS TABLE(
  investor_handle text,
  investor_name text,
  message_count bigint,
  latest_sentiment text,
  latest_commit_signal text,
  total_indicated_rupees bigint,
  last_contact timestamptz,
  days_since_contact numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (investor_handle)
      investor_handle, investor_name, sentiment, commit_signal, received_at
    FROM investor_signal_messages
    ORDER BY investor_handle, received_at DESC
  )
  SELECT m.investor_handle,
         MAX(m.investor_name),
         count(*)::bigint,
         (SELECT sentiment FROM latest l WHERE l.investor_handle = m.investor_handle),
         (SELECT commit_signal FROM latest l WHERE l.investor_handle = m.investor_handle),
         COALESCE(sum(m.commit_amount_rupees),0)::bigint,
         max(m.received_at),
         ROUND((EXTRACT(EPOCH FROM (now() - max(m.received_at))) / 86400.0)::numeric, 2)
  FROM investor_signal_messages m
  GROUP BY m.investor_handle
  ORDER BY max(m.received_at) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_investor_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_investor_leaderboard() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE SECURITY DEFINER)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_isi_ingest_message(
  p_investor_handle text,
  p_investor_name text,
  p_channel text,
  p_subject text,
  p_body text,
  p_sentiment text,
  p_sentiment_score numeric,
  p_commit_signal text,
  p_commit_amount_rupees bigint,
  p_concern_tags text[],
  p_next_step text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_signal_messages(
    investor_handle, investor_name, channel, subject, body,
    sentiment, sentiment_score, commit_signal, commit_amount_rupees,
    concern_tags, next_step
  ) VALUES (
    p_investor_handle, p_investor_name, COALESCE(p_channel,'email'),
    p_subject, p_body,
    COALESCE(p_sentiment,'neutral'), COALESCE(p_sentiment_score,0),
    COALESCE(p_commit_signal,'none'), p_commit_amount_rupees,
    COALESCE(p_concern_tags, ARRAY[]::text[]), p_next_step
  ) RETURNING id INTO v_id;
  PERFORM log_founder_isi_ingest(v_id, p_investor_handle, p_sentiment, p_commit_signal);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_ingest_message(text,text,text,text,text,text,numeric,text,bigint,text[],text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_ingest_message(text,text,text,text,text,text,numeric,text,bigint,text[],text) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_queue_action(
  p_message_id uuid,
  p_investor_handle text,
  p_action_kind text,
  p_priority text,
  p_due_at timestamptz,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_signal_actions(
    message_id, investor_handle, action_kind, priority, due_at, note
  ) VALUES (
    p_message_id, p_investor_handle, p_action_kind,
    COALESCE(p_priority,'normal'), p_due_at, p_note
  ) RETURNING id INTO v_id;
  PERFORM log_founder_isi_queue(v_id, p_investor_handle, p_action_kind, p_priority);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_queue_action(uuid,text,text,text,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_queue_action(uuid,text,text,text,timestamptz,text) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION founder_isi_close_action(
  p_action_id uuid,
  p_new_status text,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('done','dropped','in_progress') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;
  UPDATE investor_signal_actions
     SET status = p_new_status,
         note = COALESCE(p_note, note),
         closed_at = CASE WHEN p_new_status IN ('done','dropped') THEN now() ELSE closed_at END
   WHERE id = p_action_id;
  PERFORM log_founder_isi_close(p_action_id, p_new_status);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_isi_close_action(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_isi_close_action(uuid,text,text) TO authenticated;

-- ============================================================================
-- log_founder_* helpers
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_isi_ingest(
  p_message_id uuid,
  p_handle text,
  p_sentiment text,
  p_commit_signal text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'isi_ingest_message',
    jsonb_build_object('message_id', p_message_id, 'investor_handle', p_handle, 'sentiment', p_sentiment, 'commit_signal', p_commit_signal)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isi_ingest(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isi_ingest(uuid,text,text,text) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_isi_queue(
  p_action_id uuid,
  p_handle text,
  p_action_kind text,
  p_priority text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'isi_queue_action',
    jsonb_build_object('action_id', p_action_id, 'investor_handle', p_handle, 'action_kind', p_action_kind, 'priority', p_priority)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isi_queue(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isi_queue(uuid,text,text,text) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_isi_close(
  p_action_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'isi_close_action',
    jsonb_build_object('action_id', p_action_id, 'new_status', p_new_status)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isi_close(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isi_close(uuid,text) TO authenticated;

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_isi_view(
  p_view_name text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'isi_view',
    jsonb_build_object('view', p_view_name)
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isi_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isi_view(text) TO authenticated;

COMMIT;